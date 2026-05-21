import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../server/prisma";
import { requireUser, getUserId } from "../../server/auth";

export const businessesRouter = Router();

const createSchema = z.object({
  name: z.string().min(1),
  type: z.string().optional().nullable(),
  address: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  email: z.string().optional().nullable(),
  currency: z.string().min(1).default("USD"),
});

const updateSchema = createSchema
  .partial()
  .refine((v) => Object.keys(v).length > 0, { message: "empty" });

function formatItem(b: {
  id: string;
  name: string;
  type: string | null;
  address: string | null;
  phone: string | null;
  email: string | null;
  currency: string;
  createdAt: Date;
}, isOwner: boolean, roleName: string) {
  return {
    id: b.id,
    name: b.name,
    type: b.type,
    address: b.address,
    phone: b.phone,
    email: b.email,
    currency: b.currency,
    isOwner,
    role: roleName,
    createdAt: b.createdAt,
  };
}

// GET /api/businesses — all businesses this user belongs to
businessesRouter.get("/", requireUser, async (req, res) => {
  const userId = getUserId(req)!;

  const memberships = await prisma.userBusiness.findMany({
    where: { userId, business: { deletedAt: null }, role: { deletedAt: null } },
    include: { business: true, role: true },
    orderBy: { createdAt: "desc" },
  });

  return res.json({
    items: memberships.map((m) =>
      formatItem(m.business, m.isOwner, m.role.name)
    ),
  });
});

// POST /api/businesses — create a business; creator gets an Owner role with all permissions
businessesRouter.post("/", requireUser, async (req, res) => {
  const userId = getUserId(req)!;

  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success)
    return res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });

  const data = parsed.data;

  const business = await prisma.business.create({
    data: {
      name: data.name,
      type: data.type ?? null,
      address: data.address ?? null,
      phone: data.phone ?? null,
      email: data.email || null,
      currency: data.currency,
    },
  });

  // Create an Owner role and assign every existing permission to it
  const ownerRole = await prisma.role.create({
    data: { businessId: business.id, name: "Owner" },
  });

  const allPermissions = await prisma.permission.findMany();
  if (allPermissions.length > 0) {
    await prisma.rolePermission.createMany({
      data: allPermissions.map((p) => ({
        roleId: ownerRole.id,
        permissionId: p.id,
      })),
      skipDuplicates: true,
    });
  }

  // Assign the creating user as the owner
  await prisma.userBusiness.create({
    data: {
      userId,
      businessId: business.id,
      roleId: ownerRole.id,
      isOwner: true,
    },
  });

  await prisma.auditLog.create({
    data: {
      businessId: business.id,
      userId,
      action: "create",
      entity: "Business",
      entityId: business.id,
    },
  });

  return res
    .status(201)
    .json({ item: formatItem(business, true, ownerRole.name) });
});

// PATCH /api/businesses/:id — update details (owner only)
businessesRouter.patch("/:id", requireUser, async (req, res) => {
  const userId = getUserId(req)!;
  const id = String(req.params.id);

  const membership = await prisma.userBusiness.findFirst({
    where: { userId, businessId: id, isOwner: true },
  });
  if (!membership) return res.status(403).json({ error: "forbidden" });

  const existing = await prisma.business.findFirst({
    where: { id, deletedAt: null },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success)
    return res.status(400).json({ error: "invalid_body" });

  const d = parsed.data;
  const updated = await prisma.business.update({
    where: { id },
    data: {
      name: d.name ?? undefined,
      type: d.type === undefined ? undefined : d.type,
      address: d.address === undefined ? undefined : d.address,
      phone: d.phone === undefined ? undefined : d.phone,
      email: d.email === undefined ? undefined : d.email || null,
      currency: d.currency ?? undefined,
    },
  });

  await prisma.auditLog.create({
    data: { businessId: id, userId, action: "edit", entity: "Business", entityId: id },
  });

  const role = await prisma.userBusiness.findFirst({
    where: { userId, businessId: id },
    include: { role: true },
  });

  return res.json({ item: formatItem(updated, true, role?.role.name ?? "Owner") });
});

// DELETE /api/businesses/:id — soft delete (owner only)
businessesRouter.delete("/:id", requireUser, async (req, res) => {
  const userId = getUserId(req)!;
  const id = String(req.params.id);

  const membership = await prisma.userBusiness.findFirst({
    where: { userId, businessId: id, isOwner: true },
  });
  if (!membership) return res.status(403).json({ error: "forbidden" });

  const existing = await prisma.business.findFirst({
    where: { id, deletedAt: null },
  });
  if (!existing) return res.status(404).json({ error: "not_found" });

  await prisma.business.update({ where: { id }, data: { deletedAt: new Date() } });

  await prisma.auditLog.create({
    data: { businessId: id, userId, action: "delete", entity: "Business", entityId: id },
  });

  return res.status(204).send();
});
