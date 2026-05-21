#  —business mangement system Implementation Guide

This guide explains the correct setup order for Murshid.  
Every feature depends on a **Business** existing first, so always start there.

---

## Step 1 — Business

**Why first:** Everything in the system (accounts, users, inventory, sales…) belongs to a business. Nothing else can be created without one.

**What to set up:**
- Business name, type, address, phone, email
- Currency (e.g. TZS, USD)
- Tax settings (optional)

> A super admin can manage multiple businesses and switch between them from the top of the sidebar.

---

## Step 2 — user permission





**Available permission keys:**
| Key | What it controls |
|-----|-----------------|
| `dashboard:view` | View the dashboard |
| `accounts:view` / `accounts:manage` | View or manage accounts |
| `receipts:manage` | Record receipts |
| `payments:manage` | Record payments |
| `sales:manage` | Create sales orders & invoices |
| `purchases:manage` | Create purchase orders & invoices |
| `customers:manage` | Manage customers |
| `suppliers:manage` | Manage suppliers |
| `inventory:manage` | Manage inventory items |
| `users:manage` | Add / edit users |
| `roles:manage` | Create / edit roles |
| `business:create` | Create businesses (super admin only) |
| `reports:view` | View reports |

---

## Step 3 — Users

**Why third:** Users need a role assigned to them. Without roles from Step 2, you cannot add users.

**What to set up:**
- Full name, email, phone, username, password
- Assign the user to the current business
- Assign a role (from Step 2)

---

## Step 4 — Accounts

**Why fourth:** Accounts (bank, cash, mobile wallet) are required before you can record any receipts or payments.

**What to set up:**
- Account type: `BANK`, `CASH`, or `MOBILE_WALLET`
- Account name and number
- Bank name (if applicable)
- Opening balance

---

## Step 5 — Inventory

**Why fifth:** Inventory items are required as line items when creating sales orders, sales invoices, purchase orders, and purchase invoices.

**What to set up:**
- Item code, name, unit
- Purchase price and sales price
- Low stock threshold
- Opening quantity

---

## Step 6 — Customers

**Why sixth:** Customers must exist before you can create a sales order or sales invoice.

**What to set up:**
- Name, phone, email
- Billing and delivery address
- Credit limit

---

## Step 7 — Suppliers

**Why seventh:** Suppliers must exist before you can create a purchase order or purchase invoice.

**What to set up:**
- Name, phone, email, address
- Credit limit

---

## Step 8 — Sales

**Flow:** Sales Order → Sales Invoice → Receipt (payment collected)

**Sales Order** — the customer's request before delivery.  
**Sales Invoice** — issued after delivery; status moves from `UNPAID` → `PARTIAL` → `PAID`.

Requires: Customers (Step 6) + Inventory items (Step 5).

---

## Step 9 — Purchases

**Flow:** Purchase Order → Purchase Invoice → Payment (money sent to supplier)

**Purchase Order** — your order to the supplier.  
**Purchase Invoice** — the bill you receive; status moves from `UNPAID` → `PARTIAL` → `PAID`.

Requires: Suppliers (Step 7) + Inventory items (Step 5).

---

## Step 10 — Receipts

Money **coming in** to the business — linked to a bank/cash account.

**What to record:**
- Date, amount, description
- Who paid (`paidBy`)
- Which account received the money

Requires: Accounts (Step 4).

---

## Step 11 — Payments

Money **going out** from the business — linked to a bank/cash account.

**What to record:**
- Date, amount, description
- Payee (who was paid)
- Which account the money came from

Requires: Accounts (Step 4).

---

## Step 12 — Reports

Overview of all business activity — sales, purchases, cash flow, inventory levels.

Available after data exists in the system.

---

## Quick Summary

```
Business → Roles → Users → Accounts → Inventory
    → Customers → Suppliers → Sales → Purchases
    → Receipts → Payments → Reports
```
