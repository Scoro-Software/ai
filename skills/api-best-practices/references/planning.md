# Resource Planning — Availability, Bookings, and Time Off

## Table of contents
- Availability lookup
- Free time slots
- Bookings
- Time off
- Traps to avoid

## Availability lookup

`GET /availability/lookup` returns **capacity**, not bookings: `baseAvailability` (working hours) and `actualAvailability` (working hours minus time off, plus extra availability), both in **seconds**, per user or role over a date range.

Required parameter: `filters[period]` — a date range (`from` and `to`, at most 2 years).

Optional but almost always needed:
- `filters[userIds][]` — specific users
- `filters[roleIds][]` — specific roles
- `filters[groupBy]=day` — adds a per-day `periods` breakdown under each user

```http
GET /availability/lookup?filters[period][from]=2026-11-01&filters[period][to]=2026-11-30&filters[userIds][]=12&filters[userIds][]=15
```

To get remaining capacity, subtract booked time from `GET /bookings` for the same users and period.

## Free time slots

`GET /calendar/free-time-slots` returns open windows for a set of users within a short date range — useful for scheduling meetings.

Parameters go under `filters`: `userIds[]`, `startDate` and `endDate` (inclusive, at most **14 days**), plus optionally `requiredUserIds[]`, `dayStartTime` and `dayEndTime` (`HH:mm`), `eventDuration` (seconds) and `stepLength` (seconds, minimum 600).

```http
GET /calendar/free-time-slots?filters[startDate]=2026-11-04&filters[endDate]=2026-11-07&filters[userIds][]=12&filters[eventDuration]=3600
```

Each result has `startDateTime`, `endDateTime` and `busyUserIds`. A `422` means the participants' working hours have no common window. For planning windows longer than 14 days, use availability lookup instead.

## Bookings

Bookings reserve capacity on a project for a person or a role placeholder.

Required fields:

| Field | Description |
|---|---|
| `projectId` | The project this booking is for |
| `startDate` | Start date (`"2026-11-04"`) |
| `endDate` | End date |
| `amount` | Integer. The unit depends on `amountType` — see below |
| `amountType` | `"hour"` — **seconds per working day**; `"percent"` — percent of the user's daily capacity; `"total"` — **total seconds**, spread across the working days in the range |

Plus exactly one of `userId` (a person) or `roleProjectId` (the ID of a role placeholder on the project — not the project ID). `roleId` is a shortcut that resolves to the first placeholder for that role on the project. Never send `userId` together with a role field.

Booking a person for 4 hours a day:

```http
POST /bookings
Content-Type: application/json

{
  "projectId": 42,
  "userId": 12,
  "startDate": "2026-11-04",
  "endDate": "2026-11-15",
  "amount": 14400,
  "amountType": "hour"
}
```

Booking a role placeholder for 40 hours in total across the range:

```http
POST /bookings
Content-Type: application/json

{
  "projectId": 42,
  "roleId": 3,
  "startDate": "2026-11-04",
  "endDate": "2026-11-15",
  "amount": 144000,
  "amountType": "total"
}
```

Soft (tentative) booking — a placeholder that doesn't block confirmed work:

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
GET /time-offs?filters[userIds][]=12&filters[date][from]=2026-11-01&filters[date][to]=2026-11-30
```

Time off types come from `GET /time-off-types`. The time-off filters are `date`, `createdDate` and `modifiedDate` — not `period` or `modifiedDateTime`.

Don't create or modify time off records unless the user explicitly requests it — time off affects payroll and approval workflows.

## Traps to avoid

- **Booking `amount` is in seconds, not hours.** `{"amount": 40, "amountType": "hour"}` books 40 seconds per day. 4 h/day is `14400`; 40 h in total is `144000` with `"total"`.
- **`hour` is per day, `total` is for the whole range.** Using `"hour"` when you mean `"total"` multiplies the booking by the number of working days.
- **`roleProjectId` is not the project ID.** It is the ID of the role placeholder *on* the project. Use `roleId` if you only know the role.
- **Availability lookup without a user filter returns only your own availability.** Always pass user IDs when building a team scheduling tool.
- **Availability lookup returns capacity, not bookings.** It already subtracts time off; it does not subtract bookings. Read bookings separately to compute remaining capacity.
- **Free time slots are capped at 14 days.** For planning over weeks or months, use the availability lookup endpoint with a longer range instead.
