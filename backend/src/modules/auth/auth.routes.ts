import { Router } from "express";
import { z } from "zod";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { prisma } from "../../server/prisma";
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
    { sub: payload.userId, businessId: payload.businessId, roleId: payload.roleId },
    secret,
    { expiresIn: ttl }
  );
}

function signPreAuthToken(payload: { userId: string }) {
  const secret = process.env.JWT_ACCESS_SECRET;
  if (!secret) throw new Error("JWT_ACCESS_SECRET not set");
  const ttl = 10 * 60; // 10 minutes to pick/switch business
  return jwt.sign({ sub: payload.userId, preAuth: true }, secret, { expiresIn: ttl });
}

export const authRouter = Router();

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

  return res.json({
    accessToken,
    business: { id: membership.businessId, name: membership.business.name, currency: membership.business.currency },
    role: { id: membership.roleId, name: membership.role.name },
  });
});

