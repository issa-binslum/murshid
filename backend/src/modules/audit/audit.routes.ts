import { Router } from "express";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requirePermission } from "../../server/rbac";

export const auditRouter = Router();

auditRouter.get("/", ...requirePermission("audit:view"), async (req, res) => {
  const ctx = getBusinessContext(req)!;

  const page  = Math.max(1, parseInt(String(req.query.page  ?? "1")));
  const limit = Math.min(100, Math.max(1, parseInt(String(req.query.limit ?? "25"))));
  const skip  = (page - 1) * limit;

  const entity = req.query.entity ? String(req.query.entity) : undefined;
  const action = req.query.action ? String(req.query.action) : undefined;
  const search = req.query.search ? String(req.query.search).trim() : undefined;
  const from   = req.query.from   ? new Date(String(req.query.from))  : undefined;
  const to     = req.query.to     ? new Date(String(req.query.to))    : undefined;

  const where: Record<string, unknown> = {
    businessId: ctx.businessId,
    ...(entity ? { entity } : {}),
    ...(action ? { action } : {}),
    ...(from || to
      ? { createdAt: { ...(from ? { gte: from } : {}), ...(to ? { lte: to } : {}) } }
      : {}),
    ...(search
      ? {
          OR: [
            { entity:   { contains: search, mode: "insensitive" } },
            { entityId: { contains: search, mode: "insensitive" } },
            { user: { fullName: { contains: search, mode: "insensitive" } } },
            { user: { username: { contains: search, mode: "insensitive" } } },
          ],
        }
      : {}),
  };

  const [total, items] = await Promise.all([
    prisma.auditLog.count({ where: where as any }),
    prisma.auditLog.findMany({
      where: where as any,
      include: { user: { select: { fullName: true, username: true } } },
      orderBy: { createdAt: "desc" },
      skip,
      take: limit,
    }),
  ]);

  return res.json({ items, total, page, limit });
});
