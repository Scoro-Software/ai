# CRM — Contacts, Companies, and Quotes

## Table of contents
- Companies
- Persons
- Avoiding duplicates
- Quotes and pipeline
- Traps to avoid

## Companies

Required field: `companyName`.

A company record serves as both client and supplier — the same record, used in different document contexts. There is no separate supplier object. When you create a company that will appear on expenses or bills, it is the same `POST /companies` endpoint.

```http
POST /companies
Content-Type: application/json

{
  "companyName": "Acme Corp",
  "registrationCode": "12345678",
  "taxCode": "EE100012345"
}
```

Key identifier fields for duplicate detection: `registrationCode` and `taxCode`. Note: filtering by these fields returns **partial matches** — always compare the exact value in the response before treating two records as the same company.

## Persons

Required field: `firstName`.

Link persons to companies via `relatedCompanyIds`. This field controls which company the person appears under in the Scoro UI.

```http
POST /persons
Content-Type: application/json

{
  "firstName": "Anna",
  "lastName": "Smith",
  "email": "anna@acme.com",
  "relatedCompanyIds": [42]
}
```

## Avoiding duplicates

Search before every create. Scoro does not enforce uniqueness on company name or email.

**Recommended deduplication flow:**
1. Search by `registrationCode` or `taxCode` using `GET /companies?filters[registrationCode]=12345678`.
2. Compare the returned `registrationCode` or `taxCode` value **exactly** — filter results are partial matches.
3. If an exact match is found, use that company's `id` — do not create a new record.
4. If no match, create the company and store the returned `id` alongside the source system's ID.

On subsequent sync runs, use the stored Scoro ID directly — skip the search for records you've already mapped.

```http
# Search by registration code
GET /companies?filters[registrationCode]=12345678

# Verify exact match before using
if (company.registrationCode === "12345678") {
  use(company.id)
} else {
  createNewCompany()
}
```

## Quotes and pipeline

Quotes represent the sales pipeline in Scoro — there is no separate deals or opportunities resource.

Required fields: `clientId` (a company ID) and `date`.

Quote statuses carry a `probability` percentage — this is how pipeline stage is expressed. Read available quote statuses from `GET /statuses?filters[entityType]=quote` to find the codes and their associated probabilities.

```http
POST /quotes
Content-Type: application/json

{
  "clientId": 42,
  "date": "2026-11-01",
  "status": "negotiation"
}
```

Add line items after creation:

```http
POST /quotes/{id}/lines
Content-Type: application/json

[
  {
    "productId": 7,
    "quantity": 2,
    "price": 500.00
  }
]
```

## Traps to avoid

- **`relatedCompanyIds` on a person replaces the full set on `PATCH`.** If you send `"relatedCompanyIds": [10]` on an update, all other company associations are removed. Read the current value first, then send the merged array.
- **Registration code and tax code filters are partial matches.** `GET /companies?filters[registrationCode]=123` returns any company whose registration code contains "123". Always compare the exact field value in the response before concluding it's a match.
- **There is no deals or opportunities endpoint.** Use quotes with statuses for pipeline tracking. Pipeline stage = quote status code + probability.
- **`clientId` on a quote is a company ID, not a person ID.** Quotes link to companies, not individual contacts.
- **Quote → Order → Invoice links are read-only.** Agents cannot create these links programmatically. See `references/data-model.md`.
