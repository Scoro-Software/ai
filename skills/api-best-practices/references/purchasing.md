# Purchasing — Expenses, Bills, and Purchase Orders

## Table of contents
- Bills
- Expenses
- Purchase orders
- Traps to avoid

## Bills

Bills are the supplier-side equivalent of invoices — money owed to a vendor.

Required fields: `supplierId` (a company ID) and `date`.

Bill statuses are fixed — not site-defined:
- `"paid"` — payment sent
- `"unpaid"` — outstanding
- `"voided"` — cancelled

```http
POST /bills
Content-Type: application/json

{
  "supplierId": 15,
  "date": "2026-10-01",
  "status": "unpaid"
}
```

Add line items after creation:

```http
POST /bills/{id}/lines
Content-Type: application/json

[
  {"description": "Consulting services", "quantity": 8, "price": 150.00}
]
```

For incremental sync, filter by `modifiedDateTime`:

```http
GET /bills?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z
```

## Expenses

Expenses track operational costs — travel, software subscriptions, office supplies.

Required fields: `supplierId` (a company ID) and `date`.

```http
POST /expenses
Content-Type: application/json

{
  "supplierId": 15,
  "date": "2026-10-05",
  "projectId": 42
}
```

Key fields:

| Field | Meaning |
|---|---|
| `projectId` | Links the expense to a project. Pass `-1` to assign project at the line level instead. |
| `isChargeable` | `true` to mark the expense as billable to the client |
| `isReimbursable` | `true` to flag for employee reimbursement — only effective if the Scoro site has reimbursable expenses enabled |

Add expense lines after creation:

```http
POST /expenses/{id}/lines
Content-Type: application/json

[
  {"description": "Flight to Tallinn", "sum": 320.00}
]
```

## Purchase orders

Purchase orders track planned purchases from suppliers before the bill arrives.

Required fields: `supplierId` and `date`.

Line items are not included in list responses by default — fetch them separately:

```http
GET /purchase-orders/{id}/lines
```

For incremental sync:

```http
GET /purchase-orders?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z
```

## Traps to avoid

- **Expenses require `supplierId`.** A supplier company record must exist before creating an expense. Check for an existing supplier company first (`GET /companies?filters[companyName]=...`) before creating a new one.
- **`isReimbursable` has no effect on sites without the feature enabled.** Setting it to `true` will not cause any error, but the field is silently ignored unless the Scoro site administrator has enabled reimbursable expenses.
- **Bill statuses are fixed.** Do not call `GET /statuses` for bill status codes — use `"paid"`, `"unpaid"`, or `"voided"` directly.
- **Expense line items require the expense ID.** Create the expense first, then add lines — you cannot create an expense with embedded lines in one call.
- **`projectId: -1` on an expense means "assign project per line"** — it is not an error. When you pass `-1`, include `projectId` on each expense line instead of on the expense itself.
