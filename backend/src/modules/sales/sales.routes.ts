import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requireAnyPermission, requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const salesRouter = Router();

// ── Shared schemas ────────────────────────────────────────────────────────────

const lineItemSchema = z.object({
  itemId: z.string().uuid(),
  qty: z.coerce.number().positive(),
  unitPrice: z.coerce.number().finite().min(0),
});

const orderCreateSchema = z.object({
  customerId: z.string().uuid(),
  date: z.coerce.date(),
  address: z.string().optional().nullable(),
  description: z.string().optional().nullable(),
  items: z.array(lineItemSchema).min(1),
});

const orderUpdateSchema = z
  .object({
    customerId: z.string().uuid().optional(),
    date: z.coerce.date().optional(),
    address: z.string().optional().nullable(),
    description: z.string().optional().nullable(),
    items: z.array(lineItemSchema).min(1).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: "empty" });

const invoiceCreateSchema = z.object({
  customerId: z.string().uuid(),
  date: z.coerce.date(),
  description: z.string().optional().nullable(),
  items: z.array(lineItemSchema).min(1),
});

const invoiceUpdateSchema = z
  .object({
    customerId: z.string().uuid().optional(),
    date: z.coerce.date().optional(),
    description: z.string().optional().nullable(),
    items: z.array(lineItemSchema).min(1).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: "empty" });

function computeTotal(items: { qty: number; unitPrice: number }[]) {
  return items.reduce((s, i) => s + i.qty * i.unitPrice, 0);
}

const orderInclude = {
  customer: { select: { name: true } },
  items: { include: { item: { select: { itemName: true, unitName: true } } } },
};

const invoiceInclude = {
  customer: { select: { name: true } },
  items: { include: { item: { select: { itemName: true, unitName: true } } } },
};

// ── Sales Orders ──────────────────────────────────────────────────────────────

salesRouter.get("/orders", ...requireAnyPermission("sales:view", "sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.salesOrder.findMany({
    where: { businessId: ctx.businessId, deletedAt: null },
    include: orderInclude,
    orderBy: { date: "desc" },
  });
  return res.json({ items });
});

salesRouter.post("/orders", ...requirePermission("sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = orderCreateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const customer = await prisma.customer.findFirst({
    where: { id: parsed.data.customerId, businessId: ctx.businessId, deletedAt: null },
  });
  if (!customer) return res.status(400).json({ error: "customer_not_found" });

  const total = computeTotal(parsed.data.items);
  const created = await prisma.salesOrder.create({
    data: {
      businessId: ctx.businessId,
      customerId: parsed.data.customerId,
      date: parsed.data.date,
      address: parsed.data.address ?? null,
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

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "create", entity: "SalesOrder", entityId: created.id });
  return res.status(201).json({ item: created });
});

salesRouter.patch("/orders/:id", ...requirePermission("sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = orderUpdateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.salesOrder.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null, cancelledAt: null },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const newTotal = parsed.data.items ? computeTotal(parsed.data.items) : undefined;

  const updated = await prisma.$transaction(async (tx) => {
    if (parsed.data.items) {
      await tx.salesOrderItem.deleteMany({ where: { orderId: id } });
    }
    return tx.salesOrder.update({
      where: { id },
      data: {
        customerId: parsed.data.customerId ?? undefined,
        date: parsed.data.date ?? undefined,
        address: parsed.data.address === undefined ? undefined : parsed.data.address,
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

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "edit", entity: "SalesOrder", entityId: id });
  return res.json({ item: updated });
});

salesRouter.delete("/orders/:id", ...requirePermission("sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.salesOrder.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.salesOrder.update({ where: { id }, data: { deletedAt: new Date(), cancelledAt: new Date() } });
  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "cancel", entity: "SalesOrder", entityId: id });
  return res.status(204).send();
});

// ── Sales Invoices ────────────────────────────────────────────────────────────

salesRouter.get("/invoices", ...requireAnyPermission("sales:view", "sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.salesInvoice.findMany({
    where: { businessId: ctx.businessId, deletedAt: null },
    include: invoiceInclude,
    orderBy: { date: "desc" },
  });
  return res.json({ items });
});

salesRouter.post("/invoices", ...requirePermission("sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = invoiceCreateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const customer = await prisma.customer.findFirst({
    where: { id: parsed.data.customerId, businessId: ctx.businessId, deletedAt: null },
  });
  if (!customer) return res.status(400).json({ error: "customer_not_found" });

  const total = computeTotal(parsed.data.items);
  const created = await prisma.$transaction(async (tx) => {
    const invoice = await tx.salesInvoice.create({
      data: {
        businessId: ctx.businessId,
        customerId: parsed.data.customerId,
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
    // Customer owes more
    await tx.customer.update({
      where: { id: parsed.data.customerId },
      data: { balance: { increment: total } },
    });
    for (const item of parsed.data.items) {
      await tx.inventoryItem.update({
        where: { id: item.itemId },
        data: { quantity: { decrement: item.qty } },
      });
      await tx.inventoryMovement.create({
        data: {
          businessId: ctx.businessId,
          itemId: item.itemId,
          delta: -item.qty,
          reason: "sales_invoice",
          refType: "SalesInvoice",
          refId: invoice.id,
        },
      });
    }
    return invoice;
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "create", entity: "SalesInvoice", entityId: created.id });
  return res.status(201).json({ item: created });
});

salesRouter.patch("/invoices/:id", ...requirePermission("sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = invoiceUpdateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.salesInvoice.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null, cancelledAt: null, status: { not: "PAID" } },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const oldTotal = Number(existing.total);
  const newTotal = parsed.data.items ? computeTotal(parsed.data.items) : undefined;
  const oldCustomerId = existing.customerId;
  const newCustomerId = parsed.data.customerId ?? oldCustomerId;

  const updated = await prisma.$transaction(async (tx) => {
    if (parsed.data.items) {
      // Restore inventory for old items before replacing
      const oldItems = await tx.salesInvoiceItem.findMany({
        where: { invoiceId: id },
        select: { itemId: true, qty: true },
      });
      for (const old of oldItems) {
        await tx.inventoryItem.update({
          where: { id: old.itemId },
          data: { quantity: { increment: Number(old.qty) } },
        });
      }
      await tx.salesInvoiceItem.deleteMany({ where: { invoiceId: id } });
    }
    const invoice = await tx.salesInvoice.update({
      where: { id },
      data: {
        customerId: parsed.data.customerId ?? undefined,
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
    // Adjust customer balance
    const resolvedTotal = newTotal ?? oldTotal;
    if (oldCustomerId === newCustomerId) {
      const diff = resolvedTotal - oldTotal;
      if (diff !== 0) {
        await tx.customer.update({ where: { id: oldCustomerId }, data: { balance: { increment: diff } } });
      }
    } else {
      await tx.customer.update({ where: { id: oldCustomerId }, data: { balance: { decrement: oldTotal } } });
      await tx.customer.update({ where: { id: newCustomerId }, data: { balance: { increment: resolvedTotal } } });
    }
    // Deduct inventory for new items
    if (parsed.data.items) {
      for (const item of parsed.data.items) {
        await tx.inventoryItem.update({
          where: { id: item.itemId },
          data: { quantity: { decrement: item.qty } },
        });
        await tx.inventoryMovement.create({
          data: {
            businessId: ctx.businessId,
            itemId: item.itemId,
            delta: -item.qty,
            reason: "sales_invoice_update",
            refType: "SalesInvoice",
            refId: id,
          },
        });
      }
    }
    return invoice;
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "edit", entity: "SalesInvoice", entityId: id });
  return res.json({ item: updated });
});

salesRouter.post("/invoices/:id/mark-paid", ...requirePermission("sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.salesInvoice.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });
  if (existing.cancelledAt) return res.status(400).json({ error: "cancelled" });
  if (existing.status === "PAID") return res.status(400).json({ error: "already_paid" });

  const updated = await prisma.salesInvoice.update({
    where: { id },
    data: { status: "PAID", paidAmount: existing.total },
    include: invoiceInclude,
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "mark_paid", entity: "SalesInvoice", entityId: id });
  return res.json({ item: updated });
});

salesRouter.delete("/invoices/:id", ...requirePermission("sales:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.salesInvoice.findFirst({
    where: { id, businessId: ctx.businessId, deletedAt: null },
    include: { items: { select: { itemId: true, qty: true } } },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.$transaction(async (tx) => {
    // Restore inventory and reverse customer balance only if not already cancelled
    if (!existing.cancelledAt) {
      await tx.customer.update({
        where: { id: existing.customerId },
        data: { balance: { decrement: Number(existing.total) } },
      });
      for (const item of existing.items) {
        await tx.inventoryItem.update({
          where: { id: item.itemId },
          data: { quantity: { increment: Number(item.qty) } },
        });
        await tx.inventoryMovement.create({
          data: {
            businessId: ctx.businessId,
            itemId: item.itemId,
            delta: Number(item.qty),
            reason: "sales_invoice_cancel",
            refType: "SalesInvoice",
            refId: id,
          },
        });
      }
    }
    await tx.salesInvoice.update({
      where: { id },
      data: { deletedAt: new Date(), cancelledAt: new Date(), status: "CANCELLED" },
    });
  });

  await auditLog({ businessId: ctx.businessId, userId: ctx.userId, action: "cancel", entity: "SalesInvoice", entityId: id });
  return res.status(204).send();
});
