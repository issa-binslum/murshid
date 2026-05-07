import { Router } from "express";
import { prisma } from "../../server/prisma";
import { getBusinessContext } from "../../server/businessAuth";
import { requirePermission } from "../../server/rbac";

export const dashboardRouter = Router();

dashboardRouter.get("/summary", ...requirePermission("dashboard:view"), async (req, res) => {
  const ctx = getBusinessContext(req);
  if (!ctx) return res.status(401).json({ error: "missing_business_context" });

  const businessId = ctx.businessId;

  const [
    totalCustomers,
    totalSuppliers,
    totalReceipts,
    totalPayments,
    totalSalesInvoices,
    totalPurchaseInvoices,
    lowStockCount,
  ] = await Promise.all([
    prisma.customer.count({ where: { businessId, deletedAt: null } }),
    prisma.supplier.count({ where: { businessId, deletedAt: null } }),
    prisma.receipt.count({ where: { businessId, deletedAt: null } }),
    prisma.payment.count({ where: { businessId, deletedAt: null } }),
    prisma.salesInvoice.count({ where: { businessId, deletedAt: null } }),
    prisma.purchaseInvoice.count({ where: { businessId, deletedAt: null } }),
    prisma
      .$queryRaw<Array<{ count: bigint }>>`SELECT COUNT(*)::bigint AS count
        FROM "InventoryItem"
        WHERE "businessId" = ${businessId}
          AND "deletedAt" IS NULL
          AND "quantity" <= "lowStockLevel"`
      .then((rows) => Number(rows[0]?.count ?? 0)),
  ]);

  const [salesAgg, purchaseAgg, receiptsAgg, paymentsAgg, stockValueAgg] = await Promise.all([
    prisma.salesInvoice.aggregate({
      where: { businessId, deletedAt: null, cancelledAt: null },
      _sum: { total: true },
    }),
    prisma.purchaseInvoice.aggregate({
      where: { businessId, deletedAt: null, cancelledAt: null },
      _sum: { total: true },
    }),
    prisma.receipt.aggregate({
      where: { businessId, deletedAt: null },
      _sum: { amount: true },
    }),
    prisma.payment.aggregate({
      where: { businessId, deletedAt: null },
      _sum: { amount: true },
    }),
    prisma.inventoryItem.aggregate({
      where: { businessId, deletedAt: null },
      _sum: { quantity: true },
    }),
  ]);

  return res.json({
    totals: {
      sales: salesAgg._sum.total ?? 0,
      purchases: purchaseAgg._sum.total ?? 0,
      receipts: receiptsAgg._sum.amount ?? 0,
      payments: paymentsAgg._sum.amount ?? 0,
    },
    counts: {
      customers: totalCustomers,
      suppliers: totalSuppliers,
      receipts: totalReceipts,
      payments: totalPayments,
      salesInvoices: totalSalesInvoices,
      purchaseInvoices: totalPurchaseInvoices,
      lowStockItems: lowStockCount,
    },
    stock: {
      totalQuantity: stockValueAgg._sum.quantity ?? 0,
    },
  });
});

