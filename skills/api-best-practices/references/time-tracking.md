# Time Tracking

## Table of contents
- Creating time entries
- Reading time entries
- Duration format
- Billable time
- Activity types
- Approval state
- Incremental sync
- Traps to avoid

## Creating time entries

Time entries are always created under a task — there is no way to log time directly to a project or user.

Required field: `duration` (in seconds, rounded to the nearest minute). `taskId` is in the URL. Everything else is optional:

- `startDateTime` — ISO 8601 with a timezone offset; defaults to now. This is how you set the entry's date and time.
- `userId` — defaults to the token's user. Setting another user requires the "modify time entries for other users" permission.
- `activityTypeId`, `description`, `billableTimeType`, `billableDuration`.

```http
POST /tasks/{taskId}/time-entries
Content-Type: application/json

{
  "duration": 3600,
  "startDateTime": "2026-10-27T09:00:00+02:00",
  "activityTypeId": 5
}
```

`timeEntryDate` appears in responses and as a list filter, but it is not a request field.

Running timers are a separate resource: `POST /time-trackers` starts one; `POST /time-trackers/{id}/pause`, `POST /time-trackers/{id}/resume` and `POST /time-trackers/{id}/complete` control it.

## Reading time entries

To read time entries across multiple tasks or projects, use the top-level list endpoint — not the task-scoped one:

```http
GET /tasks/time-entries?filters[projectIds][]=42&filters[userIds][]=12&perPage=100
```

Useful filters:

| Filter | Description |
|---|---|
| `filters[userIds][]` | Filter by user |
| `filters[projectIds][]` | Filter by project |
| `filters[taskIds][]` | Filter by task |
| `filters[timeEntryDate][from]` and `[to]` | Filter by entry date range |
| `filters[modifiedDateTime][from]` | Incremental sync — entries changed since a timestamp |

Entries can also belong to calendar events (`filters[calendarEventIds][]`), even though v4 only creates them under tasks.

## Duration format

All duration values are in **seconds** — not HH:MM:SS strings.

| Duration | Seconds |
|---|---|
| 1 hour | `3600` |
| 30 minutes | `1800` |
| 7.5 hours | `27000` |

Both `duration` (total logged time) and `billableDuration` (billable portion) are in seconds.

## Billable time

The `billableTimeType` field controls how billable time is calculated:

| Value | Behavior |
|---|---|
| `"billable"` | `billableDuration` equals `duration` |
| `"non_billable"` | `billableDuration` is 0 |
| `"custom"` | Set `billableDuration` explicitly |

```http
# Log 2 hours, billable at 1.5 hours
{
  "duration": 7200,
  "billableTimeType": "custom",
  "billableDuration": 5400
}
```

## Activity types

Activity types categorize time entries (e.g. "Development", "Meetings", "Support"). Read available types from:

```http
GET /activity-types
```

Do not hardcode `activityTypeId` values — they vary between Scoro sites. Always resolve them by name from the activity types list.

## Approval state

Time entries carry three approval fields:

| Field | Meaning |
|---|---|
| `isSubmitted` | Employee has submitted for approval |
| `isConfirmed` | Manager has confirmed |
| `isLocked` | Entry is locked — cannot be edited |

Read these fields to check approval status. **Never change them unless the user explicitly requests an approval action** — modifying approval state without permission breaks manager approval workflows and may affect payroll.

## Incremental sync

For payroll or billing integrations, use `modifiedDateTime` to fetch only changed entries:

```http
GET /tasks/time-entries?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z&perPage=100
```

Store the timestamp of your last successful sync and use it as the `from` value on the next run. Deleted entries are not returned — poll `filters[isDeleted]=true&filters[deletedDateTime][from]=...` separately.

## Traps to avoid

- **Duration is in seconds, not HH:MM:SS.** Passing `"1:30:00"` as `duration` will result in a validation error. Convert to seconds: 1 hour 30 minutes = `5400`.
- **Time entries require a task ID.** You cannot log time without a task. If no task exists, create one first (even a placeholder task) before logging time.
- **Set the date with `startDateTime`, not `timeEntryDate`.** `timeEntryDate` is a response field and a list filter only.
- **`activityTypeId` values are site-specific.** Do not hardcode them. Always look them up from `GET /activity-types` by name.
- **Approval fields are informational.** Agents that write `isConfirmed: true` without explicit user instruction will corrupt approval workflows. Read these fields; do not set them unless asked.
- **Logging time for another user requires permission.** If the OAuth token belongs to user A and you set `userId` to user B, the request fails unless A has the "modify time entries for other users" permission, and B must be an active regular user. Check `enabledPermissions` on `GET /users/me` before attempting.
- **`userId` cannot be cleared.** Sending `"userId": null` on an update is a `400`; omit it to leave the user unchanged.
- **Use `GET /tasks/time-entries` for cross-task reads**, not `GET /tasks/{taskId}/time-entries`. The task-scoped endpoint returns only entries for a single task.
