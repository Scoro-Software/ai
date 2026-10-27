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

```http
POST /invoices
Content-Type: application/json

{
  "clientId": 42,
  "date": "2026-10-01",
  "status": "unpaid"
}
```

**Outstanding balance:** `sum - paidSum` = amount still owed. Both fields are returned on every invoice response.

## Invoice line items

Line items are not included in invoice list or detail responses by default. To retrieve them in one call, use the `includeLines` query parameter:

```http
GET /invoices?includeLines=true
GET /invoices/123?includeLines=true
```

To create or update line items separately:

```http
POST /invoices/{id}/lines
```

## Payments and allocations

Payments do not link directly to invoices — they go through allocations. This allows one payment to cover multiple invoices.

**Flow:**
1. Create a payment: `POST /invoice-payments` with `sum` and `paymentAccountId`
2. Allocate it: `POST /invoice-payment-allocations` with `paymentId`, `invoiceId`, and `sum`

```http
# Step 1: record the payment
POST /invoice-payments
{
  "sum": 1500.00,
  "paymentAccountId": 3,
  "date": "2026-10-15"
}
# Returns: {"id": 88}

# Step 2: allocate to invoice
POST /invoice-payment-allocations
{
  "paymentId": 88,
  "invoiceId": 123,
  "sum": 1500.00
}
```

## Incremental export

For accounting integrations that sync Scoro invoices to an external system, use `modifiedDateTime` filtering to fetch only changed records:

```http
GET /invoices?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z&includeLines=true
```

Store the timestamp of your last successful sync and use it as the next `from` value.

**Read-only export pattern:** Request only `invoices:r`, `invoice-payments:r`, and `invoice-payment-allocations:r` scopes. Never write to Scoro during an export run.

## Reference data

Fetch these once at the start of an export run and cache for the session:

| Data | Endpoint |
|---|---|
| Tax rates | `GET /tax-rates` |
| Currencies | `GET /currencies` |
| Finance accounts | `GET /finance-accounts` |
| Accounting objects | `GET /accounting-objects` |
| Payment accounts | `GET /payment-accounts` |

## Quotes

Required fields: `clientId` and `date`. See `references/crm.md` for quote pipeline usage.

For financial reporting, retrieve quote line items via:

```http
GET /quotes/{id}/lines
```

## Traps to avoid

- **Line items are not returned by default.** Always pass `includeLines=true` when fetching invoices for financial export — without it, line-level tax, quantity, and price data are missing.
- **Payments are not directly linked to invoices.** There is no `invoiceId` field on a payment — the link is created by an allocation record. A payment with no allocation has no effect on any invoice's `paidSum`.
- **`sum - paidSum` is the outstanding balance** — not a separate field. Calculate it after fetching the invoice.
- **Invoice statuses are fixed.** Do not call `GET /statuses` to find invoice status codes — use `"paid"`, `"unpaid"`, or `"voided"` directly.
- **A payment can be split across invoices.** Create one `InvoicePayment` and multiple `InvoicePaymentAllocation` records — one per invoice the payment covers.
