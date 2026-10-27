# Projects and Tasks

## Table of contents
- Projects
- Project phases
- Tasks
- Reporting pattern
- Traps to avoid

## Projects

Required fields: `name` and `companyId` — every project must be linked to a client company.

Filter projects for reporting:

```http
GET /projects?filters[statuses][]=active&filters[managerIds][]=5&perPage=100
```

Project budget is a **separate API call** — not returned in the project list or detail:

```http
GET /projects/{id}/budget
```

The response is keyed on `budgetType`: `"manual"` (budget entered on the project) or `"quote"` (budget derived from the linked quote). Key fields:

| Field | Meaning |
|---|---|
| `budgetedSum` | Budget amount in site currency |
| `budgetedDuration` | Planned duration in seconds |
| `earnedRevenue` | Revenue so far, based on logged time and selling price |
| `estimatedLaborCost`, `actualLaborCost` | Planned vs. incurred labor cost |
| `estimatedBills`, `estimatedExpenses`, `actualBillsSum`, `actualExpensesSum` | Purchase side, on `manual` budgets |
| `estimatedBillsAndExpenses`, `actualBillsAndExpenses` | Purchase side, combined, on `quote` budgets |
| `currency`, `priceListId` | Budget currency and price list |

Cost and margin values are hidden for users without finance permissions.

## Project phases

Phases are not returned with the project by default — fetch them separately:

```http
GET /projects/{id}/phases
```

A phase has `title`, `type` (`"phase"` or `"milestone"`), `startDate`, `endDate` and `sortOrder`. `title` and `type` are required when creating one with `POST /projects/{projectId}/phases`.

When creating tasks, use `projectPhaseId` to assign a task to a specific phase (the `projectId` is then filled in automatically):

```http
POST /tasks
{
  "name": "Write API documentation",
  "projectId": 42,
  "projectPhaseId": 7
}
```

## Tasks

Only `name` is required — a task can exist without a project.

Filter open tasks on a project:

```http
GET /tasks?filters[projectIds][]=42&filters[isDone]=false&perPage=100
```

Create a subtask by setting `parentId`:

```http
POST /tasks
{
  "name": "Draft outline",
  "projectId": 42,
  "parentId": 101
}
```

Subtask rules: the parent must belong to a project, a subtask cannot have subtasks of its own, a task linked to a quote line cannot become a subtask, and a billable task cannot move under a non-billable parent. `PATCH` with `"parentId": null` promotes a subtask back to a top-level task.

Task statuses are site-defined — read them from `GET /statuses?filters[modules][]=tasks` before creating or updating. `priorityId` is `1` (high), `2` (normal) or `3` (low). To complete a task, `POST /tasks/{id}/set-done` is simpler than guessing the site's "done" status code.

## Reporting pattern

For a complete project report, combine these calls:

| Data | Endpoint |
|---|---|
| Project details | `GET /projects/{id}` |
| Project budget | `GET /projects/{id}/budget` |
| Project phases | `GET /projects/{id}/phases` |
| Open tasks | `GET /tasks?filters[projectIds][]={id}&filters[isDone]=false` |
| Logged time | `GET /tasks/time-entries?filters[projectIds][]={id}` |
| Capacity booked | `GET /bookings?filters[projectIds][]={id}` |
| Revenue forecast | `GET /revenue-forecast-periods?filters[projectIds][]={id}` |

Always paginate all list responses with `perPage=100` — project task lists can be large.

**Read-only pattern:** For reporting integrations, request only `r` scopes (`projects:r`, `tasks:r`, `bookings:r`, `revenue-forecast-periods:r`). Never write to Scoro during a reporting run.

## Traps to avoid

- **Project budget requires a separate API call.** It is not included in `GET /projects` or `GET /projects/{id}`. A portfolio budget report needs one `GET /projects/{id}/budget` call per project — watch the `X-RateLimit-Remaining` header.
- **Task lists have no total count.** Always paginate until a page returns fewer items than `perPage`. A single page with 20 results does not mean there are only 20 tasks.
- **Subtasks are not returned in task list responses by default.** To include them, pass `filters[includeSubtasks]=true`. Without it, parent tasks appear without their children.
- **Task statuses are site-defined.** Do not hardcode status values like `"open"` or `"done"` — read available statuses from `GET /statuses?filters[modules][]=tasks` and send the `code` string.
- **Project phases are not returned with the project.** A `GET /projects/{id}` response does not include phases. Fetch them from `GET /projects/{id}/phases` when you need phase assignments.
