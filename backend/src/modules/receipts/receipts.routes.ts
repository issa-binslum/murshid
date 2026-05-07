import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const receiptsRouter = Router();

const createSchema = z.object({
  date: z.coerce.date(),
  paidBy: z.string().optional().nullable(),
  accountId: z.string().uuid(),
  amount: z.coerce.number().finite().positive(),
  description: z.string().optional().nullable(),
});

receiptsRouter.get("/", ...requirePermission("receipts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.receipt.findMany({
    where: { businessId: ctx.businessId, deletedAt: null },
    orderBy: { date: "desc" },
    take: 200,
  });
  return res.json({ items });
});

receiptsRouter.post("/", ...requirePermission("receipts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const account = await prisma.account.findFirst({
    where: { id: parsed.data.accountId, businessId: ctx.businessId, deletedAt: null },
  });
  if (!account) return res.status(400).json({ error: "invalid_account" });

  const [receipt] = await prisma.$transaction([
    prisma.receipt.create({
      data: {
        businessId: ctx.businessId,
        date: parsed.data.date,
        paidBy: parsed.data.paidBy ?? null,
        accountId: parsed.data.accountId,
        amount: parsed.data.amount,
        description: parsed.data.description ?? null,
      },
    }),
    prisma.account.update({
      where: { id: parsed.data.accountId },
      data: { currentBalance: Number(account.currentBalance) + parsed.data.amount },
    }),
  ]);

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

receiptsRouter.delete("/:id", ...requirePermission("receipts:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);

  const receipt = await prisma.receipt.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!receipt) return res.status(404).json({ error: "not_found" });

  const account = await prisma.account.findFirst({ where: { id: receipt.accountId, businessId: ctx.businessId, deletedAt: null } });
  if (!account) return res.status(400).json({ error: "invalid_account" });

  await prisma.$transaction([
    prisma.receipt.update({ where: { id }, data: { deletedAt: new Date() } }),
    prisma.account.update({
      where: { id: receipt.accountId },
      data: { currentBalance: Number(account.currentBalance) - Number(receipt.amount) },
    }),
  ]);

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "delete",
    entity: "Receipt",
    entityId: id,
  });

  return res.status(204).send();
});

