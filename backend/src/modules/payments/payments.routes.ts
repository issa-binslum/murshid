import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requirePermission } from "../../server/rbac";
import { auditLog } from "../../server/audit";

export const paymentsRouter = Router();

const createSchema = z.object({
  date: z.coerce.date(),
  payee: z.string().optional().nullable(),
  accountId: z.string().uuid(),
  amount: z.coerce.number().finite().positive(),
  description: z.string().optional().nullable(),
});

paymentsRouter.get("/", ...requirePermission("payments:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const items = await prisma.payment.findMany({
    where: { businessId: ctx.businessId, deletedAt: null },
    orderBy: { date: "desc" },
    take: 200,
  });
  return res.json({ items });
});

paymentsRouter.post("/", ...requirePermission("payments:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const account = await prisma.account.findFirst({
    where: { id: parsed.data.accountId, businessId: ctx.businessId, deletedAt: null },
  });
  if (!account) return res.status(400).json({ error: "invalid_account" });

  const nextBalance = Number(account.currentBalance) - parsed.data.amount;
  if (nextBalance < 0) return res.status(400).json({ error: "insufficient_funds" });

  const [payment] = await prisma.$transaction([
    prisma.payment.create({
      data: {
        businessId: ctx.businessId,
        date: parsed.data.date,
        payee: parsed.data.payee ?? null,
        accountId: parsed.data.accountId,
        amount: parsed.data.amount,
        description: parsed.data.description ?? null,
      },
    }),
    prisma.account.update({
      where: { id: parsed.data.accountId },
      data: { currentBalance: nextBalance },
    }),
  ]);

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "create",
    entity: "Payment",
    entityId: payment.id,
    metadata: { accountId: parsed.data.accountId, amount: parsed.data.amount },
  });

  return res.status(201).json({ item: payment });
});

paymentsRouter.delete("/:id", ...requirePermission("payments:manage"), async (req, res) => {
  const ctx = getBusinessContext(req)!;
  const id = String(req.params.id);

  const payment = await prisma.payment.findFirst({ where: { id, businessId: ctx.businessId, deletedAt: null } });
  if (!payment) return res.status(404).json({ error: "not_found" });

  const account = await prisma.account.findFirst({ where: { id: payment.accountId, businessId: ctx.businessId, deletedAt: null } });
  if (!account) return res.status(400).json({ error: "invalid_account" });

  await prisma.$transaction([
    prisma.payment.update({ where: { id }, data: { deletedAt: new Date() } }),
    prisma.account.update({
      where: { id: payment.accountId },
      data: { currentBalance: Number(account.currentBalance) + Number(payment.amount) },
    }),
  ]);

  await auditLog({
    businessId: ctx.businessId,
    userId: ctx.userId,
    action: "delete",
    entity: "Payment",
    entityId: id,
  });

  return res.status(204).send();
});

