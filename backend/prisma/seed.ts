import "dotenv/config";
import bcrypt from "bcrypt";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error("DATABASE_URL not set");
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString }) });

async function main() {
  const adminPassword = process.env.DEFAULT_ADMIN_PASSWORD ?? "Admin12345!";

  const permissionKeys = [
    "dashboard:view",
    "business:create",
    "business:switch",
    "users:manage",
    "roles:manage",
    "accounts:view",
    "accounts:manage",
    "customers:view",
    "customers:manage",
    "suppliers:view",
    "suppliers:manage",
    "inventory:view",
    "inventory:manage",
    "sales:view",
    "sales:manage",
    "purchases:view",
    "purchases:manage",
    "receipts:view",
    "receipts:manage",
    "payments:view",
    "payments:manage",
    "reports:view",
    "audit:view",
  ];

  await Promise.all(
    permissionKeys.map((key) =>
      prisma.permission.upsert({
        where: { key },
        update: {},
        create: { key, name: key },
      })
    )
  );

  const existingBusiness = await prisma.business.findFirst({
    where: { name: "Demo Business", deletedAt: null },
  });
  if (existingBusiness?.id == "00000000-0000-0000-0000-000000000001") {
    await prisma.business.update({
      where: { id: existingBusiness.id },
      data: { deletedAt: new Date() },
    });
  }

  const business =
    (await prisma.business.findFirst({ where: { name: "Demo Business", deletedAt: null } })) ??
    (await prisma.business.create({ data: { name: "Demo Business", currency: "USD" } }));

  const adminRole = await prisma.role.upsert({
    where: { businessId_name: { businessId: business.id, name: "Admin" } },
    update: {},
    create: { businessId: business.id, name: "Admin" },
  });

  const permissions = await prisma.permission.findMany({ where: { key: { in: permissionKeys } } });

  // Assign all permissions to every Admin/Owner role across all businesses
  const allPrivilegedRoles = await prisma.role.findMany({ where: { name: { in: ["Admin", "Owner"] } } });
  await Promise.all(
    allPrivilegedRoles.flatMap((role) =>
      permissions.map((p) =>
        prisma.rolePermission.upsert({
          where: { roleId_permissionId: { roleId: role.id, permissionId: p.id } },
          update: {},
          create: { roleId: role.id, permissionId: p.id },
        })
      )
    )
  );

  const passwordHash = await bcrypt.hash(adminPassword, 12);
  const admin = await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: { passwordHash },
    create: {
      fullName: "System Admin",
      email: "admin@example.com",
      username: "admin",
      passwordHash,
    },
  });

  await prisma.userBusiness.upsert({
    where: { userId_businessId: { userId: admin.id, businessId: business.id } },
    update: { roleId: adminRole.id, isOwner: true },
    create: { userId: admin.id, businessId: business.id, roleId: adminRole.id, isOwner: true },
  });

  // eslint-disable-next-line no-console
  console.log("Seeded:", { business: business.name, adminUser: admin.email });
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
