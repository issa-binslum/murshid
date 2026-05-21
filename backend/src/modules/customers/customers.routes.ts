import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext, requireBusinessContext } from "../../server/businessAuth";
import { requireAnyPermission, requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const customersRouter = Router();

const createSchema = z.object({
  name: z.string().min(1),
  creditLimit: z.coerce.number().finite().optional().default(0),
  billingAddress: z.string().optional().nullable(),
  deliveryAddress: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  email: z.string().email().optional().nullable(),
});

const updateSchema = createSchema.partial().refine((v) => Object.keys(v).length > 0, { message: "empty" });

customersRouter.get("/", ...requireAnyPermission("customers:view", "customers:manage"), async (req, res) => {
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
            { name: { contains: q, mode: "insensitive" } },
            { phone: { contains: q, mode: "insensitive" } },
            { email: { contains: q, mode: "insensitive" } },
          ],
        }
      : {}),
  };

  const [items, total] = await Promise.all([
    prisma.customer.findMany({ where, orderBy: { createdAt: "desc" }, skip, take: limit }),
    prisma.customer.count({ where }),
  ]);

  return res.json({ items, total, page, limit });
});

customersRouter.post("/", ...requirePermission("customers:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const created = await prisma.customer.create({
    data: {
      businessId: ctx.businessId,
      name: parsed.data.name,
      creditLimit: parsed.data.creditLimit,
      billingAddress: parsed.data.billingAddress ?? null,
      deliveryAddress: parsed.data.deliveryAddress ?? null,
      phone: parsed.data.phone ?? null,
      email: parsed.data.email ?? null,
    },
  });

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "create",
    entity: "Customer",
    entityId: created.id,
  });

  return res.status(201).json({ item: created });
});

customersRouter.patch("/:id", ...requirePermission("customers:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.customer.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const updated = await prisma.customer.update({
    where: { id },
    data: {
      name: parsed.data.name ?? undefined,
      creditLimit: parsed.data.creditLimit ?? undefined,
      billingAddress: parsed.data.billingAddress === undefined ? undefined : parsed.data.billingAddress,
      deliveryAddress: parsed.data.deliveryAddress === undefined ? undefined : parsed.data.deliveryAddress,
      phone: parsed.data.phone === undefined ? undefined : parsed.data.phone,
      email: parsed.data.email === undefined ? undefined : parsed.data.email,
    },
  });

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "edit",
    entity: "Customer",
    entityId: id,
  });

  return res.json({ item: updated });
});

customersRouter.delete("/:id", ...requirePermission("customers:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.customer.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.customer.update({ where: { id }, data: { deletedAt: new Date() } });
  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "delete",
    entity: "Customer",
    entityId: id,
  });
  return res.status(204).send();
});

