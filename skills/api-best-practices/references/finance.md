# Finance — Invoices, Payments, and Quotes

## Table of contents
- Invoices
- Invoice line items
- Payments and allocations
- Incremental export
- Reference data
- Quotes
- Traps to avoid

## Invoices

Required fields: `clientId` (a company ID) and `date`.

Invoice statuses are fixed — not site-defined:
- `"paid"` — payment received in full
- `"unpaid"` — outstanding balance
- `"voided"` — cancelled

Prepayments use the same three values. Orders and purchase orders use site-defined status codes.

```http
POST /invoices
Content-Type: application/json

{
  "clientId": 42,
  "date": "2026-10-01",
  "status": "unpaid",
  "lines": [
    {"productId": 7, "quantity": 2, "price": 500.00}
  ]
}
```

**Money fields:** `sum` is the total after discounts **without tax**, `taxSum` is the tax, and `paidSum` is the amount paid so far. Outstanding balance = `sum + taxSum - paidSum` — there is no separate field for it.

Do not set `status: "paid"` to record a payment — it flips the flag without creating a payment record. Use the payment endpoints below.

A PDF is available from `GET /invoices/{id}/pdf`.

## Invoice line items

Lines can be embedded in the create request (above), are always included in `GET /invoices/{id}`, and are omitted from `GET /invoices` unless you pass `includeLines=true`:

```http
GET /invoices?includeLines=true
GET /invoices/{id}/lines
```

To add or change lines later, use the upsert `POST /invoices/{id}/lines` with a `{"lines": [...]}` body, or `DELETE /invoices/{id}/lines/{lineId}`. See "Document lines" in `references/conventions.md`.

## Payments and allocations

Three ways to record money against invoices, from simplest to most flexible:

**1. Pay one invoice in one call** — creates the payment and allocates it to this invoice:

```http
POST /invoices/{invoiceId}/payments
Content-Type: application/json

{"amount": 1500.00, "date": "2026-10-15", "paymentAccountId": 3}
```

`paymentAccountId` defaults to the site's default payment account. Returns `201 {"id": <paymentId>}`.

**2. Settle the whole outstanding balance** — `POST /invoices/{invoiceId}/mark-paid`, no body needed. `POST /bills/{id}/mark-paid` does the same for bills.

**3. One payment across several invoices** — create an unallocated payment, then allocate it. The payment ID goes in the URL:

```http
# Step 1: record the payment
POST /invoice-payments
Content-Type: application/json

{"amount": 1500.00, "clientId": 42, "paymentAccountId": 3, "date": "2026-10-15"}

# Returns: 201 {"id": 88}

# Step 2: allocate to each invoice
POST /invoice-payments/88/allocations
Content-Type: application/json

{"invoiceId": 123, "amount": 1000.00}
```

`amount`, `clientId` and `paymentAccountId` are required on the payment; `date` and `currency` are optional. An allocation needs `amount` and either `invoiceId` or `prepaymentId`. `GET /invoice-payments/{id}` returns `allocations[]` and `unallocatedAmount`. Refunds go through `POST /invoices/{invoiceId}/refunds`.

Scopes: every payment endpoint, including `mark-paid`, is under `invoice-payments:*`, not `invoices:*`.

## Incremental export

For accounting integrations that sync Scoro invoices to an external system, use `modifiedDateTime` filtering to fetch only changed records:

```http
GET /invoices?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z&includeLines=true&sort=modifiedDateTime,id
```

Store the timestamp of your last successful sync and use it as the next `from` value. Deleted invoices disappear from the list — poll `filters[isDeleted]=true&filters[deletedDateTime][from]=...` separately, or subscribe to a `delete` webhook.

**Read-only export pattern:** Request only `invoices:r` and `invoice-payments:r` (allocations are part of `invoice-payments`). Reference data such as tax rates and currencies is covered by the automatically granted `base:r`. Never write to Scoro during an export run.

## Reference data

Fetch these once at the start of an export run and cache for the session:

| Data | Endpoint |
|---|---|
| Tax rates | `GET /tax-rates` |
| Currencies | `GET /currencies` |
| Finance accounts | `GET /finance-accounts` |
| Accounting objects | `GET /accounting-objects` |
| Payment accounts | `GET /payment-accounts` |

Tax rates are scoped to the company account in the `Scoro-Company-Account` header.

## Quotes

Required fields: `clientId` and `date`. See `references/crm.md` for quote pipeline usage.

For financial reporting, retrieve quote line items via:

```http
GET /quotes/{id}/lines
```

## Traps to avoid

- **Line items are not in list responses by default.** Always pass `includeLines=true` on `GET /invoices` for financial export — without it, line-level tax, quantity, and price data are missing. Detail responses always include lines.
- **Payments are not directly linked to invoices.** There is no `invoiceId` field on a payment — the link is an allocation. A payment with no allocation has no effect on any invoice's `paidSum`. `POST /invoices/{invoiceId}/payments` does both steps for you.
- **`sum` excludes tax.** Outstanding balance is `sum + taxSum - paidSum`, not `sum - paidSum`.
- **Invoice statuses are fixed.** Do not call `GET /statuses` to find invoice status codes — use `"paid"`, `"unpaid"`, or `"voided"` directly. Do not write `"paid"` to record a payment; use the payment endpoints.
- **A payment can be split across invoices.** Create one payment with `POST /invoice-payments`, then one allocation per invoice with `POST /invoice-payments/{id}/allocations`.
- **Links to quotes and orders are read-only on invoices.** Responses carry `quoteIds` and `orderIds`, but the create and update requests have no link fields and there is no "convert quote to invoice" endpoint.
