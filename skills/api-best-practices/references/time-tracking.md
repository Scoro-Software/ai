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

Required fields: `taskId` (in the URL), `duration` (in seconds), and `userId`.

```http
POST /tasks/{taskId}/time-entries
Content-Type: application/json

{
  "userId": 12,
  "duration": 3600,
  "timeEntryDate": "2026-10-27",
  "activityTypeId": 5
}
```

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
| `filters[timeEntryDate][from]` and `[to]` | Filter by entry date range |
| `filters[modifiedDateTime][from]` | Incremental sync — entries changed since a timestamp |

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
  "userId": 12,
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

Store the timestamp of your last successful sync and use it as the `from` value on the next run.

## Traps to avoid

- **Duration is in seconds, not HH:MM:SS.** Passing `"1:30:00"` as `duration` will result in a validation error. Convert to seconds: 1 hour 30 minutes = `5400`.
- **Time entries require a task ID.** You cannot log time without a task. If no task exists, create one first (even a placeholder task) before logging time.
- **`activityTypeId` values are site-specific.** Do not hardcode them. Always look them up from `GET /activity-types` by name.
- **Approval fields are informational.** Agents that write `isConfirmed: true` without explicit user instruction will corrupt approval workflows. Read these fields; do not set them unless asked.
- **Logging time for another user requires permission.** If the OAuth token belongs to user A and you set `userId` to user B, the request fails unless the token's Scoro account has the "log time for others" permission. Check capabilities before attempting.
- **Use `GET /tasks/time-entries` for cross-task reads**, not `GET /tasks/{taskId}/time-entries`. The task-scoped endpoint returns only entries for a single task.
