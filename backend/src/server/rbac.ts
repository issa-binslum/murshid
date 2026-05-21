import type { NextFunction, Request, Response } from "express";
import { prisma } from "./prisma";
import { getBusinessContext, requireBusinessContext } from "./businessAuth";

export function requirePermission(permissionKey: string) {
  return [
    requireBusinessContext,
    async (req: Request, res: Response, next: NextFunction) => {
      const ctx = getBusinessContext(req);
      if (!ctx) return res.status(401).json({ error: "missing_business_context" });

      const ok = await prisma.rolePermission.findFirst({
        where: {
          roleId: ctx.roleId,
          permission: { key: permissionKey },
        },
        select: { id: true },
      });

      if (!ok) return res.status(403).json({ error: "forbidden" });
      return next();
    },
  ];
}

/** Grants access if the user holds ANY of the listed permission keys. */
export function requireAnyPermission(...permissionKeys: string[]) {
  return [
    requireBusinessContext,
    async (req: Request, res: Response, next: NextFunction) => {
      const ctx = getBusinessContext(req);
      if (!ctx) return res.status(401).json({ error: "missing_business_context" });

      const count = await prisma.rolePermission.count({
        where: {
          roleId: ctx.roleId,
          permission: { key: { in: permissionKeys } },
        },
      });

      if (count === 0) return res.status(403).json({ error: "forbidden" });
      return next();
    },
  ];
}

