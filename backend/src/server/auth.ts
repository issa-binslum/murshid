import jwt from "jsonwebtoken";
import type { Request, Response, NextFunction } from "express";
import { prisma } from "./prisma";

export type JwtUser = { userId: string };

export async function requireUser(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.header("authorization") ?? "";
  const [, token] = authHeader.split(" ");
  if (!token) return res.status(401).json({ error: "missing_token" });

  const secret = process.env.JWT_ACCESS_SECRET;
  if (!secret) return res.status(500).json({ error: "server_misconfigured" });

  try {
    const payload = jwt.verify(token, secret) as { sub?: string; jti?: string };
    if (!payload.sub) return res.status(401).json({ error: "invalid_token" });

    if (payload.jti) {
      try {
        const blocked = await prisma.tokenBlocklist.findUnique({ where: { jti: payload.jti } });
        if (blocked) return res.status(401).json({ error: "token_revoked" });
      } catch {
        // Table may not exist yet (migration pending) — fail open so auth still works.
      }
    }

    (req as Request & { user?: JwtUser }).user = { userId: payload.sub };
    return next();
  } catch {
    return res.status(401).json({ error: "invalid_token" });
  }
}

export function getUserId(req: Request) {
  return (req as Request & { user?: JwtUser }).user?.userId ?? null;
}

