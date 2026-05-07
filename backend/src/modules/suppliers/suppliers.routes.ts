import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const suppliersRouter = Router();

const createSchema = z.object({
  name: z.string().min(1),
  creditLimit: z.coerce.number().finite().optional().default(0),
  address: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  email: z.string().email().optional().nullable(),
});

const updateSchema = createSchema.partial().refine((v) => Object.keys(v).length > 0, { message: "empty" });

suppliersRouter.get("/", ...requirePermission("suppliers:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const q = typeof req.query.q === "string" ? req.query.q.trim() : "";

  const items = await prisma.supplier.findMany({
    where: {
      businessId: ctx.businessId,
      deletedAt: null,
      ...(q
        ? {
            OR: [
              { name: { contains: q, mode: "insensitive" } },
              { phone: { contains: q, mode: "insensitive" } },
              { email: { contains: q, mode: "insensitive" } },
            ],
          }
        : {}),
    },
    orderBy: { createdAt: "desc" },
  });

  return res.json({ items });
});

suppliersRouter.post("/", ...requirePermission("suppliers:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const created = await prisma.supplier.create({
    data: {
      businessId: ctx.businessId,
      name: parsed.data.name,
      creditLimit: parsed.data.creditLimit,
      address: parsed.data.address ?? null,
      phone: parsed.data.phone ?? null,
      email: parsed.data.email ?? null,
    },
  });

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "create",
    entity: "Supplier",
    entityId: created.id,
  });

  return res.status(201).json({ item: created });
});

suppliersRouter.patch("/:id", ...requirePermission("suppliers:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.supplier.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const updated = await prisma.supplier.update({
    where: { id },
    data: {
      name: parsed.data.name ?? undefined,
      creditLimit: parsed.data.creditLimit ?? undefined,
      address: parsed.data.address === undefined ? undefined : parsed.data.address,
      phone: parsed.data.phone === undefined ? undefined : parsed.data.phone,
      email: parsed.data.email === undefined ? undefined : parsed.data.email,
    },
  });

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "edit",
    entity: "Supplier",
    entityId: id,
  });

  return res.json({ item: updated });
});

suppliersRouter.delete("/:id", ...requirePermission("suppliers:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.supplier.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.supplier.update({ where: { id }, data: { deletedAt: new Date() } });
  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "delete",
    entity: "Supplier",
    entityId: id,
  });
  return res.status(204).send();
});

