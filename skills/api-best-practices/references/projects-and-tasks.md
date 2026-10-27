# Projects and Tasks

## Table of contents
- Projects
- Project phases
- Tasks
- Reporting pattern
- Traps to avoid

## Projects

Required field: `companyId` — every project must be linked to a client company.

Filter projects for reporting:

```http
GET /projects?filters[statuses][]=active&filters[managerIds][]=5&perPage=100
```

Project budget is a **separate API call** — not returned in the project list or detail:

```http
GET /projects/{id}/budget
```

Key fields returned:

| Field | Meaning |
|---|---|
| `budgetAmount` | Total budget for the project |
| `actualAmount` | Cost incurred so far |
| `trackedAmount` | Revenue tracked against the project |

## Project phases

Phases are not returned with the project by default — fetch them separately:

```http
GET /projects/{id}/phases
```

When creating tasks, use `projectPhaseId` to assign a task to a specific phase:

```http
POST /tasks
{
  "name": "Write API documentation",
  "projectId": 42,
  "projectPhaseId": 7
}
```

## Tasks

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

Task statuses are site-defined — read them from `GET /statuses?filters[entityType]=task` before creating or updating.

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

**Read-only pattern:** For reporting integrations, request only `r` scopes. Never write to Scoro during a reporting run.

## Traps to avoid

- **Project budget requires a separate API call.** It is not included in `GET /projects` or `GET /projects/{id}`. If you're building a portfolio budget report, you will need one `GET /projects/{id}/budget` call per project — space these out to avoid rate limits.
- **Task lists have no total count.** Always paginate until a page returns fewer items than `perPage`. A single page with 20 results does not mean there are only 20 tasks.
- **Subtasks are not returned in task list responses by default.** To include subtasks in the response, add `includeSubtasks=true` to the filter. Without it, parent tasks appear without their children.
- **Task statuses are site-defined.** Do not hardcode status values like `"open"` or `"done"` — read available statuses from `GET /statuses?filters[entityType]=task` and send the `code` string.
- **Project phases are not returned with the project.** A `GET /projects/{id}` response does not include phases. Fetch them from `GET /projects/{id}/phases` when you need phase assignments.
