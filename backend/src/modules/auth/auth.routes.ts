import { randomUUID } from "crypto";
import { Router } from "express";
import { z } from "zod";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { prisma } from "../../server/prisma";
import { getBusinessContext, requireBusinessContext } from "../../server/businessAuth";
import { getUserId, requireUser } from "../../server/auth";

const loginSchema = z.object({
  identifier: z.string().min(1), // email or username
  password: z.string().min(1),
});

const switchBusinessSchema = z.object({
  businessId: z.string().uuid(),
});

function signAccessToken(payload: { userId: string; businessId: string; roleId: string }) {
  const secret = process.env.JWT_ACCESS_SECRET;
  if (!secret) throw new Error("JWT_ACCESS_SECRET not set");
  const ttl = Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 3600);
  return jwt.sign(
    { sub: payload.userId, businessId: payload.businessId, roleId: payload.roleId, jti: randomUUID() },
    secret,
    { expiresIn: ttl }
  );
}

function signPreAuthToken(payload: { userId: string }) {
  const secret = process.env.JWT_ACCESS_SECRET;
  if (!secret) throw new Error("JWT_ACCESS_SECRET not set");
  return jwt.sign({ sub: payload.userId, preAuth: true }, secret, { expiresIn: 10 * 60 });
}

async function getRolePermissions(roleId: string): Promise<string[]> {
  const rps = await prisma.rolePermission.findMany({
    where: { roleId },
    include: { permission: true },
  });
  return rps.map((rp) => rp.permission.key);
}

export const authRouter = Router();

// Step 1 — validate credentials, return preAuthToken + business list
authRouter.post("/login", async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const { identifier, password } = parsed.data;

  const user = await prisma.user.findFirst({
    where: {
      deletedAt: null,
      status: "ACTIVE",
      OR: [{ email: identifier }, { username: identifier }],
    },
    include: {
      businesses: {
        include: { business: true, role: true },
      },
    },
  });

  if (!user) return res.status(401).json({ error: "invalid_credentials" });
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.status(401).json({ error: "invalid_credentials" });

  const businesses = user.businesses
    .filter((ub) => ub.business.deletedAt === null && ub.role.deletedAt === null)
    .map((ub) => ({
      businessId: ub.businessId,
      businessName: ub.business.name,
      roleId: ub.roleId,
      roleName: ub.role.name,
      isOwner: ub.isOwner,
      currency: ub.business.currency,
    }));

  return res.json({
    user: { id: user.id, fullName: user.fullName, email: user.email, username: user.username },
    preAuthToken: signPreAuthToken({ userId: user.id }),
    businesses,
  });
});

// Step 2 — exchange preAuthToken + businessId for a full accessToken + permissions
authRouter.post("/switch-business", requireUser, async (req, res) => {
  const parsed = switchBusinessSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_body" });

  const userId = getUserId(req);
  if (!userId) return res.status(401).json({ error: "missing_user" });

  const membership = await prisma.userBusiness.findFirst({
    where: { userId, businessId: parsed.data.businessId },
    include: { role: true, business: true },
  });
  if (!membership || membership.business.deletedAt !== null || membership.role.deletedAt !== null) {
    return res.status(403).json({ error: "not_allowed" });
  }

  const accessToken = signAccessToken({
    userId,
    businessId: membership.businessId,
    roleId: membership.roleId,
  });

  const permissions = await getRolePermissions(membership.roleId);

  return res.json({
    accessToken,
    business: {
      id: membership.businessId,
      name: membership.business.name,
      currency: membership.business.currency,
    },
    role: { id: membership.roleId, name: membership.role.name },
    permissions,
  });
});

// POST /logout — revoke the current access token by adding its jti to the blocklist
authRouter.post("/logout", requireUser, async (req, res) => {
  const authHeader = req.header("authorization") ?? "";
  const [, token] = authHeader.split(" ");

  try {
    const payload = jwt.decode(token) as { jti?: string; sub?: string; exp?: number } | null;
    if (payload?.jti && payload?.exp) {
      const expiresAt = new Date(payload.exp * 1000);
      await prisma.tokenBlocklist.upsert({
        where: { jti: payload.jti },
        create: { jti: payload.jti, userId: payload.sub ?? "", expiresAt },
        update: {},
      });
      // Clean up expired entries opportunistically
      await prisma.tokenBlocklist.deleteMany({ where: { expiresAt: { lt: new Date() } } });
    }
  } catch {
    // Best-effort: local logout still succeeds even if DB insert fails
  }

  return res.json({ ok: true });
});

// GET /me — return current user info + business + permissions from accessToken
authRouter.get("/me", requireBusinessContext, async (req, res) => {
  const ctx = getBusinessContext(req);
  if (!ctx) return res.status(401).json({ error: "missing_context" });

  const [user, membership] = await Promise.all([
    prisma.user.findUnique({
      where: { id: ctx.userId },
      select: { id: true, fullName: true, email: true, username: true },
    }),
    prisma.userBusiness.findFirst({
      where: { userId: ctx.userId, businessId: ctx.businessId },
      include: { business: true },
    }),
  ]);

  if (!user || !membership) return res.status(404).json({ error: "not_found" });

  const [permissions, allBusinesses] = await Promise.all([
    getRolePermissions(ctx.roleId),
    prisma.userBusiness.findMany({
      where: { userId: ctx.userId, business: { deletedAt: null }, role: { deletedAt: null } },
      include: { business: true, role: true },
    }),
  ]);

  return res.json({
    user,
    currentBusiness: {
      id: membership.businessId,
      name: membership.business.name,
      currency: membership.business.currency,
    },
    permissions,
    businesses: allBusinesses.map((ub) => ({
      businessId: ub.businessId,
      businessName: ub.business.name,
      roleId: ub.roleId,
      roleName: ub.role.name,
      isOwner: ub.isOwner,
      currency: ub.business.currency,
    })),
  });
});
