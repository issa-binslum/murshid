import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const accountsRouter = Router();

const createSchema = z.object({
  type: z.enum(["BANK", "CASH", "MOBILE_WALLET"]),
  accountName: z.string().min(1),
  bankName: z.string().optional().nullable(),
  accountNumber: z.string().optional().nullable(),
  openingBalance: z.coerce.number().finite().optional().default(0),
});

const updateSchema = createSchema.partial().refine((v) => Object.keys(v).length > 0, { message: "empty" });

accountsRouter.get("/", ...requirePermission("accounts:view"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.account.findMany({
    where: { businessId: ctx.businessId, deletedAt: null },
    orderBy: { createdAt: "desc" },
  });
  return res.json({ items });
});

accountsRouter.post("/", ...requirePermission("accounts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const data = parsed.data;
  const created = await prisma.account.create({
    data: {
      businessId: ctx.businessId,
      type: data.type,
      accountName: data.accountName,
      bankName: data.bankName ?? null,
      accountNumber: data.accountNumber ?? null,
      openingBalance: data.openingBalance,
      currentBalance: data.openingBalance,
    },
  });
  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "create",
    entity: "Account",
    entityId: created.id,
  });
  return res.status(201).json({ item: created });
});

accountsRouter.patch("/:id", ...requirePermission("accounts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const existing = await prisma.account.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const updated = await prisma.account.update({
    where: { id },
    data: {
      type: parsed.data.type ?? undefined,
      accountName: parsed.data.accountName ?? undefined,
      bankName: parsed.data.bankName === undefined ? undefined : parsed.data.bankName,
      accountNumber: parsed.data.accountNumber === undefined ? undefined : parsed.data.accountNumber,
    },
  });

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "edit",
    entity: "Account",
    entityId: id,
  });

  return res.json({ item: updated });
});

accountsRouter.delete("/:id", ...requirePermission("accounts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);
  const existing = await prisma.account.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.account.update({ where: { id }, data: { deletedAt: new Date() } });
  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "delete",
    entity: "Account",
    entityId: id,
  });
  return res.status(204).send();
});

