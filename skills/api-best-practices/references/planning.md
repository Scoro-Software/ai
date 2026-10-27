# Resource Planning — Availability, Bookings, and Time Off

## Table of contents
- Availability lookup
- Free time slots
- Bookings
- Time off
- Traps to avoid

## Availability lookup

`GET /availability/lookup` returns working hours and booked time for users or roles over a date range.

Required parameter: `filters[period]` — an ISO date range (start and end date).

Optional but almost always needed:
- `filters[userIds][]` — filter to specific users
- `filters[roleIds][]` — filter to a specific role

```http
GET /availability/lookup?filters[period][from]=2026-11-01&filters[period][to]=2026-11-30&filters[userIds][]=12&filters[userIds][]=15
```

Maximum date range: **2 years**.

## Free time slots

`GET /free-time-slots` returns available windows within a short date range — useful for scheduling individual meetings or short bookings.

Maximum range: **14 days**.

```http
GET /free-time-slots?filters[period][from]=2026-11-04&filters[period][to]=2026-11-07&filters[userIds][]=12
```

For planning windows longer than 14 days, use availability lookup instead.

## Bookings

Bookings reserve capacity on a project for a person or role.

Required fields:

| Field | Description |
|---|---|
| `projectId` | The project this booking is for |
| `startDate` | Start date (ISO date, e.g. `"2026-11-04"`) |
| `endDate` | End date (ISO date) |
| `amount` | Quantity of the booking |
| `amountType` | `"hour"` — fixed hours, `"percent"` — percentage of working time, `"total"` — total hours across the range |

Booking a specific person:

```http
POST /bookings
Content-Type: application/json

{
  "projectId": 42,
  "userId": 12,
  "startDate": "2026-11-04",
  "endDate": "2026-11-15",
  "amount": 40,
  "amountType": "hour"
}
```

Booking a role (unassigned capacity):

```http
POST /bookings
Content-Type: application/json

{
  "projectId": 42,
  "roleId": 3,
  "roleProjectId": 42,
  "startDate": "2026-11-04",
  "endDate": "2026-11-15",
  "amount": 40,
  "amountType": "hour"
}
```

Soft (tentative) booking — placeholder that doesn't block confirmed work:

```http
{
  "projectId": 42,
  "userId": 12,
  "startDate": "2026-11-04",
  "endDate": "2026-11-08",
  "amount": 50,
  "amountType": "percent",
  "isTentative": true
}
```

## Time off

Read time off records from `GET /time-offs`. Filter by user and date range:

```http
GET /time-offs?filters[userIds][]=12&filters[period][from]=2026-11-01&filters[period][to]=2026-11-30
```

Time off types come from `GET /time-off-types`.

Don't create or modify time off records unless the user explicitly requests it — time off affects payroll and approval workflows.

## Traps to avoid

- **Availability lookup without a user filter returns only your own availability.** Without `filters[userIds][]` or `filters[roleIds][]`, the endpoint returns data only for the authenticated user. Always pass user IDs when building a team scheduling tool.
- **Free time slots are capped at 14 days.** For planning over weeks or months, use the availability lookup endpoint with a longer range instead.
- **`roleId` without `roleProjectId` on a booking.** When booking by role, both `roleId` and `roleProjectId` are required — the project context determines which role configuration applies.
- **`amountType` must match your intent.** `"percent"` means percent of working capacity per day. `"total"` means total hours across the entire date range. Using `"hour"` when you mean `"total"` will result in a much larger booking than intended.
- **Time off records affect availability.** Factor in time off when computing remaining capacity — the availability lookup already accounts for it, but manual calculations from raw booking data will be wrong if you ignore time-off records.
