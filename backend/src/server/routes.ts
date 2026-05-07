import { Router } from "express";
import { authRouter } from "../modules/auth/auth.routes";
import { dashboardRouter } from "../modules/dashboard/dashboard.routes";
import { accountsRouter } from "../modules/accounts/accounts.routes";
import { customersRouter } from "../modules/customers/customers.routes";
import { suppliersRouter } from "../modules/suppliers/suppliers.routes";
import { inventoryRouter } from "../modules/inventory/inventory.routes";
import { receiptsRouter } from "../modules/receipts/receipts.routes";
import { paymentsRouter } from "../modules/payments/payments.routes";

export const apiRouter = Router();

apiRouter.use("/auth", authRouter);
apiRouter.use("/dashboard", dashboardRouter);
apiRouter.use("/accounts", accountsRouter);
apiRouter.use("/customers", customersRouter);
apiRouter.use("/suppliers", suppliersRouter);
apiRouter.use("/inventory", inventoryRouter);
apiRouter.use("/receipts", receiptsRouter);
apiRouter.use("/payments", paymentsRouter);

