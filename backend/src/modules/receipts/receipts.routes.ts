import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requireAnyPermission, requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const receiptsRouter = Router();

// Recalculates every non-cancelled sales invoice for a customer (FIFO).
// Runs OUTSIDE the main transaction to avoid long-held connections on Neon.
async function recalcCustomerInvoices(customerId: string) {
  const [invoices, receipts] = await Promise.all([
    prisma.salesInvoice.findMany({
      where: { customerId, deletedAt: null, cancelledAt: null },
      orderBy: { date: "asc" },
      select: { id: true, total: true },
    }),
    prisma.receipt.findMany({
      where: { customerId, deletedAt: null },
      select: { amount: true },
    }),
  ]);

  let remaining = receipts.reduce((s, r) => s + Number(r.amount), 0);

  const updates = invoices.map((inv) => {
    const total = Number(inv.total);
    let status: string;
    let paidAmount: number;

    if (remaining <= 0) {
      status = "UNPAID";
      paidAmount = 0;
    } else if (remaining >= total) {
      status = "PAID";
      paidAmount = total;
      remaining -= total;
    } else {
      status = "PARTIAL";
      paidAmount = remaining;
      remaining = 0;
    }

    return prisma.salesInvoice.update({
      where: { id: inv.id },
      data: { status, paidAmount },
    });
  });

  if (updates.length > 0) {
    await prisma.$transaction(updates);
  }
}

const itemSchema = z.object({
  itemId: z.string().uuid(),
  qty: z.coerce.number().finite().positive(),
  unitPrice: z.coerce.number().finite().min(0),
});

const createSchema = z.object({
  date: z.coerce.date(),
  paidBy: z.string().optional().nullable(),
  customerId: z.string().uuid().optional().nullable(),
  accountId: z.string().uuid(),
  amount: z.coerce.number().finite().positive(),
  description: z.string().optional().nullable(),
  items: z.array(itemSchema).optional().default([]),
});

const includeItems = {
  items: {
    include: { item: { select: { id: true, itemName: true, salesPrice: true } } },
  },
};

receiptsRouter.get("/", ...requireAnyPermission("receipts:view", "receipts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const q = typeof req.query.q === "string" ? req.query.q.trim() : "";
  const page = Math.max(1, parseInt(String(req.query.page ?? "1")) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(String(req.query.limit ?? "25")) || 25));
  const skip = (page - 1) * limit;

  const where = {
    businessId: ctx.businessId,
    deletedAt: null,
    ...(q
      ? {
          OR: [
            { paidBy: { contains: q, mode: "insensitive" } },
            { description: { contains: q, mode: "insensitive" } },
          ],
        }
      : {}),
  };

  const [items, total] = await Promise.all([
    prisma.receipt.findMany({ where, orderBy: { date: "desc" }, skip, take: limit, include: includeItems }),
    prisma.receipt.count({ where }),
  ]);

  return res.json({ items, total, page, limit });
});

receiptsRouter.post("/", ...requirePermission("receipts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const account = await prisma.account.findFirst({
    where: { id: parsed.data.accountId, businessId: ctx.businessId, deletedAt: null },
  });
  if (!account) return res.status(400).json({ error: "invalid_account" });

  // Main transaction: create receipt + update balances (kept small/fast)
  const receipt = await prisma.$transaction(async (tx) => {
    const r = await tx.receipt.create({
      data: {
        businessId: ctx.businessId,
        date: parsed.data.date,
        paidBy: parsed.data.paidBy ?? null,
        customerId: parsed.data.customerId ?? null,
        accountId: parsed.data.accountId,
        amount: parsed.data.amount,
        description: parsed.data.description ?? null,
        items: parsed.data.items.length > 0
          ? {
              create: parsed.data.items.map((it) => ({
                itemId: it.itemId,
                qty: it.qty,
                unitPrice: it.unitPrice,
                total: it.qty * it.unitPrice,
              })),
            }
          : undefined,
      },
      include: includeItems,
    });
    await tx.account.update({
      where: { id: parsed.data.accountId },
      data: { currentBalance: { increment: parsed.data.amount } },
    });
    if (parsed.data.customerId) {
      await tx.customer.update({
        where: { id: parsed.data.customerId },
        data: { balance: { decrement: parsed.data.amount } },
      });
    }
    return r;
  });

  // Recalc invoice statuses after the transaction commits
  if (parsed.data.customerId) {
    await recalcCustomerInvoices(parsed.data.customerId);
  }

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "create",
    entity: "Receipt",
    entityId: receipt.id,
    metadata: { accountId: parsed.data.accountId, amount: parsed.data.amount },
  });

  return res.status(201).json({ item: receipt });
});

receiptsRouter.patch("/:id", ...requirePermission("receipts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);

  const updateSchema = z.object({
    date: z.coerce.date().optional(),
    paidBy: z.string().optional().nullable(),
    customerId: z.string().uuid().optional().nullable(),
    accountId: z.string().uuid().optional(),
    amount: z.coerce.number().finite().positive().optional(),
    description: z.string().optional().nullable(),
    items: z.array(itemSchema).optional(),
  });

  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const receipt = await prisma.receipt.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!receipt) return res.status(404).json({ error: "not_found" });

  const newAccountId = parsed.data.accountId ?? receipt.accountId;
  const newAmount = parsed.data.amount ?? Number(receipt.amount);
  const oldAccountId = String(receipt.accountId);
  const oldAmount = Number(receipt.amount);
  const oldCustomerId = receipt.customerId;
  const newCustomerId = parsed.data.customerId !== undefined ? parsed.data.customerId : oldCustomerId;

  if (newAccountId !== oldAccountId) {
    const [oldAcc, newAcc] = await Promise.all([
      prisma.account.findFirst({ where: { id: oldAccountId, businessId: ctx.businessId, deletedAt: null } }),
      prisma.account.findFirst({ where: { id: newAccountId, businessId: ctx.businessId, deletedAt: null } }),
    ]);
    if (!oldAcc || !newAcc) return res.status(400).json({ error: "invalid_account" });
  }

  await prisma.$transaction(async (tx) => {
    await tx.receipt.update({
      where: { id },
      data: {
        ...(parsed.data.date !== undefined && { date: parsed.data.date }),
        ...(parsed.data.paidBy !== undefined && { paidBy: parsed.data.paidBy ?? null }),
        ...(parsed.data.customerId !== undefined && { customerId: parsed.data.customerId ?? null }),
        accountId: newAccountId,
        amount: newAmount,
        ...(parsed.data.description !== undefined && { description: parsed.data.description ?? null }),
      },
    });

    if (parsed.data.items !== undefined) {
      await tx.receiptItem.deleteMany({ where: { receiptId: id } });
      if (parsed.data.items.length > 0) {
        await tx.receiptItem.createMany({
          data: parsed.data.items.map((it) => ({
            receiptId: id,
            itemId: it.itemId,
            qty: it.qty,
            unitPrice: it.unitPrice,
            total: it.qty * it.unitPrice,
          })),
        });
      }
    }

    // Account balance
    if (oldAccountId === newAccountId) {
      const diff = newAmount - oldAmount;
      if (diff !== 0) {
        await tx.account.update({ where: { id: oldAccountId }, data: { currentBalance: { increment: diff } } });
      }
    } else {
      await tx.account.update({ where: { id: oldAccountId }, data: { currentBalance: { decrement: oldAmount } } });
      await tx.account.update({ where: { id: newAccountId }, data: { currentBalance: { increment: newAmount } } });
    }

    // Customer balance
    if (oldCustomerId === null && newCustomerId !== null) {
      await tx.customer.update({ where: { id: newCustomerId }, data: { balance: { decrement: newAmount } } });
    } else if (oldCustomerId !== null && newCustomerId === null) {
      await tx.customer.update({ where: { id: oldCustomerId }, data: { balance: { increment: oldAmount } } });
    } else if (oldCustomerId !== null && newCustomerId !== null) {
      if (oldCustomerId === newCustomerId) {
        const diff = newAmount - oldAmount;
        if (diff !== 0) {
          await tx.customer.update({ where: { id: oldCustomerId }, data: { balance: { decrement: diff } } });
        }
      } else {
        await tx.customer.update({ where: { id: oldCustomerId }, data: { balance: { increment: oldAmount } } });
        await tx.customer.update({ where: { id: newCustomerId }, data: { balance: { decrement: newAmount } } });
      }
    }
  });

  // Recalc invoice statuses after transaction commits
  const toRecalc = new Set<string>();
  if (oldCustomerId) toRecalc.add(oldCustomerId);
  if (newCustomerId) toRecalc.add(newCustomerId);
  for (const cid of toRecalc) {
    await recalcCustomerInvoices(cid);
  }

  const updated = await prisma.receipt.findUnique({ where: { id }, include: includeItems });

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "update",
    entity: "Receipt",
    entityId: id,
    metadata: { accountId: newAccountId, amount: newAmount },
  });

  return res.json({ item: updated });
});

receiptsRouter.delete("/:id", ...requirePermission("receipts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);

  const receipt = await prisma.receipt.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!receipt) return res.status(404).json({ error: "not_found" });

  await prisma.$transaction(async (tx) => {
    await tx.receiptItem.deleteMany({ where: { receiptId: id } });
    await tx.receipt.update({ where: { id }, data: { deletedAt: new Date() } });
    await tx.account.update({
      where: { id: receipt.accountId },
      data: { currentBalance: { decrement: Number(receipt.amount) } },
    });
    if (receipt.customerId) {
      await tx.customer.update({
        where: { id: receipt.customerId },
        data: { balance: { increment: Number(receipt.amount) } },
      });
    }
  });

  // Recalc AFTER the receipt is soft-deleted (so it's excluded from the sum)
  if (receipt.customerId) {
    await recalcCustomerInvoices(receipt.customerId);
  }

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "delete",
    entity: "Receipt",
    entityId: id,
  });

  return res.status(204).send();
});
