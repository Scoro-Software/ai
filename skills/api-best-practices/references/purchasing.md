# Purchasing — Expenses, Bills, and Purchase Orders

## Table of contents
- Bills
- Expenses
- Purchase orders
- Traps to avoid

## Bills

Bills are the supplier-side equivalent of invoices — money owed to a vendor.

Required fields: `supplierId` (a company ID) and `date`. Optional links: `purchaseOrderId` and `quoteId` on the bill, `quoteLineId` and `invoiceLineId` on a bill line.

Bill statuses are fixed — `"paid"`, `"unpaid"`, `"voided"` — not site-defined.

```http
POST /bills
Content-Type: application/json

{
  "supplierId": 15,
  "date": "2026-10-01",
  "status": "unpaid",
  "lines": [
    {"description": "Consulting services", "quantity": 8, "price": 150.00}
  ]
}
```

Lines can be embedded on create, as above. To add or change lines later use the upsert — the body is an object with a `lines` array, and lines with an `id` are updated rather than duplicated:

```http
POST /bills/{id}/lines
Content-Type: application/json

{"lines": [{"description": "Travel", "quantity": 1, "price": 80.00}]}
```

See "Document lines" in `references/conventions.md`.

Record a payment with `POST /bill-payments` (`amount`, `billId` and `paymentAccountId` required; `date`, `paymentType` and `currency` optional), or settle the whole balance with `POST /bills/{id}/mark-paid`.

For incremental sync, filter by `modifiedDateTime`:

```http
GET /bills?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z&includeLines=true
```

## Expenses

Expenses track operational costs — travel, software subscriptions, office supplies.

Required fields: `supplierId` (a company ID) and `date`. Statuses are the same fixed `"paid"`, `"unpaid"`, `"voided"`.

```http
POST /expenses
Content-Type: application/json

{
  "supplierId": 15,
  "date": "2026-10-05",
  "projectId": 42,
  "lines": [
    {"description": "Flight to Tallinn", "price": 320.00, "quantity": 1}
  ]
}
```

Key fields:

| Field | Meaning |
|---|---|
| `projectId` | Links the expense to a project. Pass `-1` to assign the project per line instead (this also works on invoices, quotes, orders and bills). |
| `isChargeable` | `true` to mark the expense as billable to the client |
| `isReimbursable` | `true` to flag for employee reimbursement. Only send it when the site has reimbursable expenses enabled — otherwise the request fails with `400`. |

Expense lines use `price` and `quantity`; there is no `sum` field, the line total is calculated. Add or change lines later with the upsert `POST /expenses/{id}/lines` and a `{"lines": [...]}` body.

## Purchase orders

Purchase orders track planned purchases from suppliers before the bill arrives.

Required fields: `supplierId` and `date`. Status is a site-defined code from `GET /statuses?filters[modules][]=purchaseOrders`.

Lines are embedded on create and in `GET /purchase-orders/{id}`. On the list endpoint, pass `includeLines=true`:

```http
GET /purchase-orders?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z&includeLines=true
GET /purchase-orders/{id}/lines
```

## Traps to avoid

- **Expenses and bills require `supplierId`.** A supplier company record must exist first. Look it up with `GET /companies/search?keyword=...` or `GET /companies?filters[companyName]=...&filters[isSupplier]=true` before creating a new one — name filters are partial matches, so compare the exact value.
- **`isReimbursable` on a site without the feature is a `400`**, not a silent no-op. Only send the field when reimbursable expenses are enabled.
- **Bill and expense statuses are fixed.** Do not call `GET /statuses` for them — use `"paid"`, `"unpaid"`, or `"voided"` directly. Purchase order statuses *are* site-defined.
- **`POST /{document}/{id}/lines` is an upsert with an object body.** Send `{"lines": [...]}`; a bare array is rejected. Lines without an `id` are created, so a blind retry duplicates them.
- **`projectId: -1` means "assign project per line"** — it is not an error. When you pass `-1`, include `projectId` on each line instead of on the document.
