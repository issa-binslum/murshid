import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext, requireBusinessContext } from "../../server/businessAuth";
import { requireAnyPermission, requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const inventoryRouter = Router();

const createSchema = z.object({
  itemCode: z.string().min(1),
  itemName: z.string().min(1),
  unitName: z.string().min(1),
  quantity: z.coerce.number().finite().optional().default(0),
  lowStockLevel: z.coerce.number().finite().optional().default(0),
  purchasePrice: z.coerce.number().finite().optional().default(0),
  salesPrice: z.coerce.number().finite().optional().default(0),
  description: z.string().optional().nullable(),
});

const updateSchema = createSchema.partial().refine((v) => Object.keys(v).length > 0, { message: "empty" });

inventoryRouter.get("/", ...requireAnyPermission("inventory:view", "inventory:manage"), async (req, res) => {
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
            { itemCode: { contains: q, mode: "insensitive" } },
            { itemName: { contains: q, mode: "insensitive" } },
          ],
        }
      : {}),
  };

  const [items, total] = await Promise.all([
    prisma.inventoryItem.findMany({ where, orderBy: { createdAt: "desc" }, skip, take: limit }),
    prisma.inventoryItem.count({ where }),
  ]);

  return res.json({ items, total, page, limit });
});

inventoryRouter.get("/low-stock", ...requirePermission("inventory:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.$queryRaw<
    Array<{
      id: string;
      businessId: string;
      itemCode: string;
      itemName: string;
      unitName: string;
      quantity: any;
      lowStockLevel: any;
      purchasePrice: any;
      salesPrice: any;
      description: string | null;
      createdAt: Date;
      updatedAt: Date;
      deletedAt: Date | null;
    }>
  >`SELECT * FROM "InventoryItem"
    WHERE "businessId" = ${ctx.businessId}
      AND "deletedAt" IS NULL
      AND "quantity" <= "lowStockLevel"
    ORDER BY "updatedAt" DESC
    LIMIT 200`;
  return res.json({ items });
});

inventoryRouter.get("/:id/movements", ...requirePermission("inventory:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);

  const item = await prisma.inventoryItem.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!item) return res.status(404).json({ error: "not_found" });

  const items = await prisma.inventoryMovement.findMany({
    where: { businessId: ctx.businessId, itemId: id },
    orderBy: { createdAt: "desc" },
    take: 200,
  });
  return res.json({ items });
});

inventoryRouter.post("/", ...requirePermission("inventory:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const created = await prisma.inventoryItem.create({
    data: {
      businessId: ctx.businessId,
      itemCode: parsed.data.itemCode,
      itemName: parsed.data.itemName,
      unitName: parsed.data.unitName,
      quantity: parsed.data.quantity,
      lowStockLevel: parsed.data.lowStockLevel,
      purchasePrice: parsed.data.purchasePrice,
      salesPrice: parsed.data.salesPrice,
      description: parsed.data.description ?? null,
    },
  });

  if (parsed.data.quantity !== 0) {
    await prisma.inventoryMovement.create({
      data: {
        businessId: ctx.businessId,
        itemId: created.id,
        delta: parsed.data.quantity,
        reason: "opening_balance",
      },
    });
  }

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "create",
    entity: "InventoryItem",
    entityId: created.id,
  });

  return res.status(201).json({ item: created });
});

inventoryRouter.patch("/:id", ...requirePermission("inventory:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.inventoryItem.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const updated = await prisma.inventoryItem.update({
    where: { id },
    data: {
      itemCode: parsed.data.itemCode ?? undefined,
      itemName: parsed.data.itemName ?? undefined,
      unitName: parsed.data.unitName ?? undefined,
      lowStockLevel: parsed.data.lowStockLevel ?? undefined,
      purchasePrice: parsed.data.purchasePrice ?? undefined,
      salesPrice: parsed.data.salesPrice ?? undefined,
      description: parsed.data.description === undefined ? undefined : parsed.data.description,
    },
  });

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "edit",
    entity: "InventoryItem",
    entityId: id,
  });

  return res.json({ item: updated });
});

inventoryRouter.post("/:id/adjust", ...requirePermission("inventory:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = z
    .object({
      delta: z.coerce.number().finite(),
      reason: z.string().min(1).optional().default("adjustment"),
    })
    .safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const item = await prisma.inventoryItem.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!item) return res.status(404).json({ error: "not_found" });

  // BR-001: do not go below zero by default
  const newQty = Number(item.quantity) + parsed.data.delta;
  if (newQty < 0) return res.status(400).json({ error: "negative_stock_not_allowed" });

  const [updated] = await prisma.$transaction([
    prisma.inventoryItem.update({
      where: { id },
      data: { quantity: newQty },
    }),
    prisma.inventoryMovement.create({
      data: {
        businessId: ctx.businessId,
        itemId: id,
        delta: parsed.data.delta,
        reason: parsed.data.reason,
      },
    }),
  ]);

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "adjust",
    entity: "InventoryItem",
    entityId: id,
    metadata: { delta: parsed.data.delta, reason: parsed.data.reason },
  });

  return res.json({ item: updated });
});

inventoryRouter.delete("/:id", ...requirePermission("inventory:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.inventoryItem.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.inventoryItem.update({ where: { id }, data: { deletedAt: new Date() } });
  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "delete",
    entity: "InventoryItem",
    entityId: id,
  });
  return res.status(204).send();
});

