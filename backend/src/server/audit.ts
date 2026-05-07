import { prisma } from "./prisma";

export async function auditLog(params: {
  businessId: string;
  userId?: string | null;
  action: string;
  entity: string;
  entityId?: string | null;
  metadata?: unknown;
}) {
  await prisma.auditLog.create({
    data: {
      businessId: params.businessId,
      userId: params.userId ?? null,
      action: params.action,
      entity: params.entity,
      entityId: params.entityId ?? null,
      metadata: params.metadata as any,
    },
  });
}

