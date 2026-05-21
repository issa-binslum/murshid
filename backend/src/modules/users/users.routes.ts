import { Router } from "express";
import { z } from "zod";
import bcrypt from "bcrypt";
import { prisma } from "../../server/prisma";
import { requireBusinessContext, getBusinessContext } from "../../server/businessAuth";

export const usersRouter = Router();

async function canDo(roleId: string, permKey: string): Promise<boolean> {
  const rp = await prisma.rolePermission.findFirst({
    where: { roleId, permission: { key: permKey } },
  });
  return rp !== null;
}

function fmt(
  u: { id: string; fullName: string; email: string; phone: string | null; username: string; status: string },
  isOwner: boolean,
  permissions: string[]
) {
  return {
    id: u.id,
    fullName: u.fullName,
    email: u.email,
    phone: u.phone,
    username: u.username,
    status: u.status,
    isOwner,
    permissions,
  };
}

// GET /api/users/permissions
usersRouter.get("/permissions", requireBusinessContext, async (_req, res) => {
  try {
    const perms = await prisma.permission.findMany({ orderBy: { key: "asc" } });
    return res.json({ items: perms.map((p) => ({ key: p.key, name: p.name })) });
  } catch (err) {
    console.error("[GET /api/users/permissions]", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

// GET /api/users
usersRouter.get("/", requireBusinessContext, async (req, res) => {
  try {
    const ctx = getBusinessContext(req)!;
    const memberships = await prisma.userBusiness.findMany({
      where: { businessId: ctx.businessId, user: { deletedAt: null } },
      select: {
        isOwner: true,
        roleId: true,
        user: {
          select: {
            id: true, fullName: true, email: true,
            phone: true, username: true, status: true,
          },
        },
        role: {
          select: {
            permissions: { select: { permission: { select: { key: true } } } },
          },
        },
      },
      orderBy: { createdAt: "asc" },
    });

    const items = memberships.map((m) =>
      fmt(m.user, m.isOwner, m.role.permissions.map((rp) => rp.permission.key))
    );
    return res.json({ items });
  } catch (err) {
    console.error("[GET /api/users]", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

// POST /api/users
usersRouter.post("/", requireBusinessContext, async (req, res) => {
  try {
    const ctx = getBusinessContext(req)!;

    const parsed = z.object({
      fullName: z.string().min(1),
      email: z.string().email(),
      username: z.string().min(1),
      password: z.string().min(6),
      phone: z.string().optional().nullable(),
      permissions: z.array(z.string()).default([]),
      status: z.enum(["ACTIVE", "INACTIVE"]).default("ACTIVE"),
    }).safeParse(req.body);

    if (!parsed.success)
      return res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });

    const d = parsed.data;

    // Parallel: permission check + duplicate check + permission key lookup
    const [permitted, clash, validPerms] = await Promise.all([
      canDo(ctx.roleId, "users:manage"),
      prisma.user.findFirst({
        where: { OR: [{ email: d.email }, { username: d.username }] },
        select: { email: true, username: true },
      }),
      prisma.permission.findMany({
        where: { key: { in: d.permissions } },
        select: { id: true, key: true },
      }),
    ]);

    if (!permitted) return res.status(403).json({ error: "forbidden" });
    if (clash) {
      const field = clash.email === d.email ? "email" : "username";
      return res.status(409).json({ error: "conflict", field });
    }

    const passwordHash = await bcrypt.hash(d.password, 10);

    const user = await prisma.user.create({
      data: {
        fullName: d.fullName,
        email: d.email,
        username: d.username,
        phone: d.phone ?? null,
        passwordHash,
      },
    });

    const autoRole = await prisma.role.create({
      data: { businessId: ctx.businessId, name: `_user_${user.id}` },
    });

    // Parallel: assign permissions + create membership + audit log
    const [ub] = await Promise.all([
      prisma.userBusiness.create({
        data: { userId: user.id, businessId: ctx.businessId, roleId: autoRole.id },
        select: { isOwner: true },
      }),
      validPerms.length > 0
        ? prisma.rolePermission.createMany({
            data: validPerms.map((p) => ({ roleId: autoRole.id, permissionId: p.id })),
            skipDuplicates: true,
          })
        : Promise.resolve(),
      prisma.auditLog.create({
        data: { businessId: ctx.businessId, userId: ctx.userId, action: "create", entity: "User", entityId: user.id },
      }),
    ]);

    return res.status(201).json({
      item: fmt(user, ub.isOwner, validPerms.map((p) => p.key)),
    });
  } catch (err) {
    console.error("[POST /api/users]", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

// PATCH /api/users/:id
usersRouter.patch("/:id", requireBusinessContext, async (req, res) => {
  try {
    const ctx = getBusinessContext(req)!;
    const id = String(req.params.id);

    if (id === ctx.userId)
      return res.status(403).json({ error: "cannot_edit_self" });

    const parsed = z.object({
      fullName: z.string().min(1).optional(),
      email: z.string().email().optional(),
      username: z.string().min(1).optional(),
      phone: z.string().optional().nullable(),
      password: z.string().min(6).optional(),
      status: z.enum(["ACTIVE", "INACTIVE"]).optional(),
      permissions: z.array(z.string()).optional(),
    }).safeParse(req.body);

    if (!parsed.success)
      return res.status(400).json({ error: "invalid_body" });

    const d = parsed.data;

    // Parallel: permission check + fetch membership (flat, no deep nesting)
    const [permitted, ub] = await Promise.all([
      canDo(ctx.roleId, "users:manage"),
      prisma.userBusiness.findFirst({
        where: { userId: id, businessId: ctx.businessId },
        select: {
          id: true, isOwner: true, roleId: true,
          user: {
            select: {
              id: true, fullName: true, email: true,
              phone: true, username: true, status: true, deletedAt: true,
            },
          },
        },
      }),
    ]);

    if (!permitted) return res.status(403).json({ error: "forbidden" });
    if (!ub || ub.user.deletedAt !== null)
      return res.status(404).json({ error: "not_found" });

    // Parallel: duplicate check + permission key lookup + bcrypt (all independent)
    const [clash, validPerms, passwordHash] = await Promise.all([
      d.email || d.username
        ? prisma.user.findFirst({
            where: {
              id: { not: id },
              OR: [
                ...(d.email ? [{ email: d.email }] : []),
                ...(d.username ? [{ username: d.username }] : []),
              ],
            },
            select: { email: true, username: true },
          })
        : Promise.resolve(null),
      d.permissions !== undefined
        ? prisma.permission.findMany({
            where: { key: { in: d.permissions } },
            select: { id: true, key: true },
          })
        : Promise.resolve(null),
      d.password ? bcrypt.hash(d.password, 10) : Promise.resolve(undefined),
    ]);

    if (clash) {
      const field = clash.email === d.email ? "email" : "username";
      return res.status(409).json({ error: "conflict", field });
    }

    const finalUser = await prisma.user.update({
      where: { id },
      data: {
        ...(d.fullName !== undefined && { fullName: d.fullName }),
        ...(d.email !== undefined && { email: d.email }),
        ...(d.username !== undefined && { username: d.username }),
        ...(d.phone !== undefined && { phone: d.phone }),
        ...(d.status !== undefined && { status: d.status }),
        ...(passwordHash !== undefined && { passwordHash }),
      },
    });

    // Parallel: update permissions (if changed) + fetch current (if not) + audit log
    let finalPermissions: string[];
    if (validPerms !== null) {
      const [currentPerms] = await Promise.all([
        (async () => {
          await prisma.rolePermission.deleteMany({ where: { roleId: ub.roleId } });
          if (validPerms.length > 0) {
            await prisma.rolePermission.createMany({
              data: validPerms.map((p) => ({ roleId: ub.roleId, permissionId: p.id })),
              skipDuplicates: true,
            });
          }
          return validPerms.map((p) => p.key);
        })(),
        prisma.auditLog.create({
          data: { businessId: ctx.businessId, userId: ctx.userId, action: "edit", entity: "User", entityId: id },
        }),
      ]);
      finalPermissions = currentPerms;
    } else {
      const [rolePerms] = await Promise.all([
        prisma.rolePermission.findMany({
          where: { roleId: ub.roleId },
          select: { permission: { select: { key: true } } },
        }),
        prisma.auditLog.create({
          data: { businessId: ctx.businessId, userId: ctx.userId, action: "edit", entity: "User", entityId: id },
        }),
      ]);
      finalPermissions = rolePerms.map((rp) => rp.permission.key);
    }

    return res.json({ item: fmt(finalUser, ub.isOwner, finalPermissions) });
  } catch (err) {
    console.error("[PATCH /api/users/:id]", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

// DELETE /api/users/:id
usersRouter.delete("/:id", requireBusinessContext, async (req, res) => {
  try {
    const ctx = getBusinessContext(req)!;
    const id = String(req.params.id);

    if (id === ctx.userId)
      return res.status(403).json({ error: "cannot_remove_self" });

    // Parallel: permission check + fetch membership
    const [permitted, ub] = await Promise.all([
      canDo(ctx.roleId, "users:manage"),
      prisma.userBusiness.findFirst({
        where: { userId: id, businessId: ctx.businessId },
        select: { id: true, isOwner: true, roleId: true },
      }),
    ]);

    if (!permitted) return res.status(403).json({ error: "forbidden" });
    if (!ub) return res.status(404).json({ error: "not_found" });
    if (ub.isOwner) return res.status(403).json({ error: "cannot_remove_owner" });

    await prisma.userBusiness.delete({ where: { id: ub.id } });

    // Parallel: delete auto-role + count remaining memberships
    const [, remaining] = await Promise.all([
      prisma.role.deleteMany({ where: { id: ub.roleId, name: { startsWith: "_user_" } } }),
      prisma.userBusiness.count({ where: { userId: id } }),
    ]);

    // Parallel: soft-delete user (if no memberships left) + audit log
    await Promise.all([
      remaining === 0
        ? prisma.user.update({ where: { id }, data: { deletedAt: new Date() } })
        : Promise.resolve(),
      prisma.auditLog.create({
        data: { businessId: ctx.businessId, userId: ctx.userId, action: "delete", entity: "User", entityId: id },
      }),
    ]);

    return res.status(204).send();
  } catch (err) {
    console.error("[DELETE /api/users/:id]", err);
    return res.status(500).json({ error: "internal_error" });
  }
});
