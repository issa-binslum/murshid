import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requireAnyPermission, requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const purchasesRouter = Router();

// ── Shared schemas ────────────────────────────────────────────────────────────

const lineItemSchema = z.object({
  itemId: z.string().uuid(),
  qty: z.coerce.number().positive(),
  unitPrice: z.coerce.number().finite().min(0),
});

const orderCreateSchema = z.object({
  supplierId: z.string().uuid(),
  date: z.coerce.date(),
  description: z.string().optional().nullable(),
  items: z.array(lineItemSchema).min(1),
});

const orderUpdateSchema = z
  .object({
    supplierId: z.string().uuid().optional(),
    date: z.coerce.date().optional(),
    description: z.string().optional().nullable(),
    items: z.array(lineItemSchema).min(1).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: "empty" });

const invoiceCreateSchema = z.object({
  supplierId: z.string().uuid(),
  date: z.coerce.date(),
  description: z.string().optional().nullable(),
  items: z.array(lineItemSchema).min(1),
});

const invoiceUpdateSchema = z
  .object({
    supplierId: z.string().uuid().optional(),
    date: z.coerce.date().optional(),
    description: z.string().optional().nullable(),
    items: z.array(lineItemSchema).min(1).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: "empty" });

function computeTotal(items: { qty: number; unitPrice: number }[]) {
  return items.reduce((s, i) => s + i.qty * i.unitPrice, 0);
}

const orderInclude = {
  supplier: { select: { name: true } },
  items: { include: { item: { select: { itemName: true, unitName: true } } } },
};

const invoiceInclude = {
  supplier: { select: { name: true } },
  items: { include: { item: { select: { itemName: true, unitName: true } } } },
};

// ── Purchase Orders ───────────────────────────────────────────────────────────

purchasesRouter.get("/orders", ...requireAnyPermission("purchases:view", "purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.purchaseOrder.findMany({
    where: { businessId: ctx.businessId, deletedAt: null },
    include: orderInclude,
    orderBy: { date: "desc" },
  });
  return res.json({ items });
});

purchasesRouter.post("/orders", ...requirePermission("purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = orderCreateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const supplier = await prisma.supplier.findFirst({
    where: { id: parsed.data.supplierId, businessId: ctx.businessId, deletedAt: null },
  });
  if (!supplier) return res.status(400).json({ error: "supplier_not_found" });

  const total = computeTotal(parsed.data.items);
  const created = await prisma.purchaseOrder.create({
    data: {
      businessId: ctx.businessId,
      supplierId: parsed.data.supplierId,
      date: parsed.data.date,
      description: parsed.data.description ?? null,
      total,
      items: {
        create: parsed.data.items.map((i) => ({
          itemId: i.itemId,
          qty: i.qty,
          unitPrice: i.unitPrice,
          total: i.qty * i.unitPrice,
        })),
      },
    },
    include: orderInclude,
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "create", entity: "PurchaseOrder", entityId: created.id });
  return res.status(201).json({ item: created });
});

purchasesRouter.patch("/orders/:id", ...requirePermission("purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = orderUpdateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.purchaseOrder.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null, cancelledAt: null },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const newTotal = parsed.data.items ? computeTotal(parsed.data.items) : undefined;

  const updated = await prisma.$transaction(async (tx) => {
    if (parsed.data.items) {
      await tx.purchaseOrderItem.deleteMany({ where: { orderId: id } });
    }
    return tx.purchaseOrder.update({
      where: { id },
      data: {
        supplierId: parsed.data.supplierId ?? undefined,
        date: parsed.data.date ?? undefined,
        description: parsed.data.description === undefined ? undefined : parsed.data.description,
        total: newTotal,
        ...(parsed.data.items
          ? {
              items: {
                create: parsed.data.items.map((i) => ({
                  itemId: i.itemId,
                  qty: i.qty,
                  unitPrice: i.unitPrice,
                  total: i.qty * i.unitPrice,
                })),
              },
            }
          : {}),
      },
      include: orderInclude,
    });
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "edit", entity: "PurchaseOrder", entityId: id });
  return res.json({ item: updated });
});

purchasesRouter.delete("/orders/:id", ...requirePermission("purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.purchaseOrder.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.purchaseOrder.update({ where: { id }, data: { deletedAt: new Date(), cancelledAt: new Date() } });
  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "cancel", entity: "PurchaseOrder", entityId: id });
  return res.status(204).send();
});

// ── Purchase Invoices ─────────────────────────────────────────────────────────

purchasesRouter.get("/invoices", ...requireAnyPermission("purchases:view", "purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.purchaseInvoice.findMany({
    where: { businessId: ctx.businessId, deletedAt: null },
    include: invoiceInclude,
    orderBy: { date: "desc" },
  });
  return res.json({ items });
});

purchasesRouter.post("/invoices", ...requirePermission("purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = invoiceCreateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const supplier = await prisma.supplier.findFirst({
    where: { id: parsed.data.supplierId, businessId: ctx.businessId, deletedAt: null },
  });
  if (!supplier) return res.status(400).json({ error: "supplier_not_found" });

  const total = computeTotal(parsed.data.items);
  const created = await prisma.$transaction(async (tx) => {
    const invoice = await tx.purchaseInvoice.create({
      data: {
        businessId: ctx.businessId,
        supplierId: parsed.data.supplierId,
        date: parsed.data.date,
        description: parsed.data.description ?? null,
        total,
        items: {
          create: parsed.data.items.map((i) => ({
            itemId: i.itemId,
            qty: i.qty,
            unitPrice: i.unitPrice,
            total: i.qty * i.unitPrice,
          })),
        },
      },
      include: invoiceInclude,
    });
    for (const item of parsed.data.items) {
      await tx.inventoryItem.update({
        where: { id: item.itemId },
        data: { quantity: { increment: item.qty } },
      });
      await tx.inventoryMovement.create({
        data: {
          businessId: ctx.businessId,
          itemId: item.itemId,
          delta: item.qty,
          reason: "purchase_invoice",
          refType: "PurchaseInvoice",
          refId: invoice.id,
        },
      });
    }
    // We owe the supplier more
    await tx.supplier.update({
      where: { id: parsed.data.supplierId },
      data: { balance: { increment: total } },
    });
    return invoice;
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "create", entity: "PurchaseInvoice", entityId: created.id });
  return res.status(201).json({ item: created });
});

purchasesRouter.patch("/invoices/:id", ...requirePermission("purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = invoiceUpdateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.purchaseInvoice.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null, cancelledAt: null, status: { not: "PAID" } },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const newTotal = parsed.data.items ? computeTotal(parsed.data.items) : undefined;

  const updated = await prisma.$transaction(async (tx) => {
    if (parsed.data.items) {
      // Reverse inventory for old items before replacing
      const oldItems = await tx.purchaseInvoiceItem.findMany({
        where: { invoiceId: id },
        select: { itemId: true, qty: true },
      });
      for (const old of oldItems) {
        await tx.inventoryItem.update({
          where: { id: old.itemId },
          data: { quantity: { decrement: Number(old.qty) } },
        });
      }
      await tx.purchaseInvoiceItem.deleteMany({ where: { invoiceId: id } });
    }
    const invoice = await tx.purchaseInvoice.update({
      where: { id },
      data: {
        supplierId: parsed.data.supplierId ?? undefined,
        date: parsed.data.date ?? undefined,
        description: parsed.data.description === undefined ? undefined : parsed.data.description,
        total: newTotal,
        ...(parsed.data.items
          ? {
              items: {
                create: parsed.data.items.map((i) => ({
                  itemId: i.itemId,
                  qty: i.qty,
                  unitPrice: i.unitPrice,
                  total: i.qty * i.unitPrice,
                })),
              },
            }
          : {}),
      },
      include: invoiceInclude,
    });
    // Increase inventory for new items
    if (parsed.data.items) {
      for (const item of parsed.data.items) {
        await tx.inventoryItem.update({
          where: { id: item.itemId },
          data: { quantity: { increment: item.qty } },
        });
        await tx.inventoryMovement.create({
          data: {
            businessId: ctx.businessId,
            itemId: item.itemId,
            delta: item.qty,
            reason: "purchase_invoice_update",
            refType: "PurchaseInvoice",
            refId: id,
          },
        });
      }
    }
    // Adjust supplier balance
    const oldSupplierId = existing.supplierId;
    const newSupplierId = parsed.data.supplierId ?? oldSupplierId;
    const resolvedTotal = newTotal ?? Number(existing.total);
    const oldTotalNum = Number(existing.total);
    if (oldSupplierId === newSupplierId) {
      const diff = resolvedTotal - oldTotalNum;
      if (diff !== 0) {
        await tx.supplier.update({ where: { id: oldSupplierId }, data: { balance: { increment: diff } } });
      }
    } else {
      await tx.supplier.update({ where: { id: oldSupplierId }, data: { balance: { decrement: oldTotalNum } } });
      await tx.supplier.update({ where: { id: newSupplierId }, data: { balance: { increment: resolvedTotal } } });
    }
    return invoice;
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "edit", entity: "PurchaseInvoice", entityId: id });
  return res.json({ item: updated });
});

purchasesRouter.post("/invoices/:id/mark-paid", ...requirePermission("purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.purchaseInvoice.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });
  if (existing.cancelledAt) return res.status(400).json({ error: "cancelled" });
  if (existing.status === "PAID") return res.status(400).json({ error: "already_paid" });

  const updated = await prisma.purchaseInvoice.update({
    where: { id },
    data: { status: "PAID", paidAmount: existing.total },
    include: invoiceInclude,
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "mark_paid", entity: "PurchaseInvoice", entityId: id });
  return res.json({ item: updated });
});

purchasesRouter.delete("/invoices/:id", ...requirePermission("purchases:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.purchaseInvoice.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null },
    include: { items: { select: { itemId: true, qty: true } } },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.$transaction(async (tx) => {
    // Reverse inventory only if not already cancelled
    if (!existing.cancelledAt) {
      for (const item of existing.items) {
        await tx.inventoryItem.update({
          where: { id: item.itemId },
          data: { quantity: { decrement: Number(item.qty) } },
        });
        await tx.inventoryMovement.create({
          data: {
            businessId: ctx.businessId,
            itemId: item.itemId,
            delta: -Number(item.qty),
            reason: "purchase_invoice_cancel",
            refType: "PurchaseInvoice",
            refId: id,
          },
        });
      }
      // Reverse supplier balance
      await tx.supplier.update({
        where: { id: existing.supplierId },
        data: { balance: { decrement: Number(existing.total) } },
      });
    }
    await tx.purchaseInvoice.update({
      where: { id },
      data: { deletedAt: new Date(), cancelledAt: new Date(), status: "CANCELLED" },
    });
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "cancel", entity: "PurchaseInvoice", entityId: id });
  return res.status(204).send();
});
