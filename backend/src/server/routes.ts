import { Router } from "express";
import { authRouter } from "../modules/auth/auth.routes";
import { businessesRouter } from "../modules/businesses/businesses.routes";
import { dashboardRouter } from "../modules/dashboard/dashboard.routes";
import { accountsRouter } from "../modules/accounts/accounts.routes";
import { customersRouter } from "../modules/customers/customers.routes";
import { suppliersRouter } from "../modules/suppliers/suppliers.routes";
import { inventoryRouter } from "../modules/inventory/inventory.routes";
import { receiptsRouter } from "../modules/receipts/receipts.routes";
import { paymentsRouter } from "../modules/payments/payments.routes";
import { usersRouter } from "../modules/users/users.routes";
import { salesRouter } from "../modules/sales/sales.routes";
import { purchasesRouter } from "../modules/purchases/purchases.routes";
import { auditRouter } from "../modules/audit/audit.routes";

export const apiRouter = Router();

apiRouter.use("/auth", authRouter);
apiRouter.use("/businesses", businessesRouter);
apiRouter.use("/users", usersRouter);
apiRouter.use("/dashboard", dashboardRouter);
apiRouter.use("/accounts", accountsRouter);
apiRouter.use("/customers", customersRouter);
apiRouter.use("/suppliers", suppliersRouter);
apiRouter.use("/inventory", inventoryRouter);
apiRouter.use("/receipts", receiptsRouter);
apiRouter.use("/payments", paymentsRouter);
apiRouter.use("/sales", salesRouter);
apiRouter.use("/purchases", purchasesRouter);
apiRouter.use("/audit", auditRouter);

