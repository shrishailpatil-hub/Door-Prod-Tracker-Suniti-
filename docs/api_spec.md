# API Specification

## 1. Authentication

### POST `/api/auth/login`

**Access**: Public (Unauthenticated)

**Request Body** (`application/json`)
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response Body** (200 OK)
```json
{
  "token": "<jwt-token>",
  "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "name": "User Name",
  "role": "MANAGER"
}
```

- Returns a JWT signed with HS256 containing `sub` (email), `userId`, `role`, and expiration claims.
- The `Authorization` header must be passed as `Bearer <token>` on all protected endpoints.
- On every request, the user's active status and current role are loaded from the database; deactivated accounts are immediately blocked with 401 Unauthorized.

---

## 2. Role-Based Access Control (RBAC)

| Role | Accessible Endpoint Prefixes |
|---|---|
| **ADMIN** | `/api/admin/**`, `/api/notifications/**` |
| **MANAGER** | `/api/manager/**`, `/api/notifications/**` |
| **WORKER** | `/api/worker/**`, `/api/notifications/**` |
| **ALL** | `/api/auth/**` (public) |

Unauthorized role access receives `403 Forbidden`. Unauthenticated calls receive `401 Unauthorized`.

---

## 3. Error Responses

Consistent JSON error format across all endpoints:
```json
{
  "status": 400,
  "message": "Validation or error message description"
}
```

Common status codes:
- `400 Bad Request`: Validation failure, invalid transition, or out-of-order workflow action.
- `401 Unauthorized`: Missing, expired, or deactivated authentication token.
- `403 Forbidden`: Authenticated user lacks required role.
- `404 Not Found`: Entity (user, process step, job, step, notification) not found.
- `409 Conflict`: Duplicate unique key (email, job number, active process step name) or optimistic locking conflict.
- `500 Internal Server Error`: Unexpected server exception.

---

## 4. Admin Management APIs

**Access**: `ROLE_ADMIN`

### Admin User Management (`/api/admin/users`)

- `POST /api/admin/users`
  - Body: `{"name": "...", "email": "...", "password": "...", "role": "MANAGER"}`
  - Returns created user `UserResponse`.
- `GET /api/admin/users`
  - Returns `List<UserResponse>`.
- `GET /api/admin/users/{id}`
  - Returns `UserResponse` or 404.
- `PUT /api/admin/users/{id}`
  - Body: `{"name": "...", "email": "...", "password": "...", "role": "..."}`
  - Updates user details.
- `PATCH /api/admin/users/{id}/status`
  - Body: `{"isActive": false}`
  - Updates user status (self-deactivation returns 400 Bad Request).

### Admin Process Step Management (`/api/admin/process-steps`)

- `POST /api/admin/process-steps`
  - Body: `{"name": "Cutting", "stepOrder": 1}`
  - Inserts step, automatically shifting subsequent active steps. Enforces contiguous ordering and case-insensitive uniqueness.
- `GET /api/admin/process-steps`
  - Returns all process steps ordered by `stepOrder` (including inactive).
- `GET /api/admin/process-steps/{id}`
  - Returns `ProcessStepResponse` or 404.
- `PUT /api/admin/process-steps/{id}`
  - Body: `{"name": "Cutting & Sizing", "stepOrder": 2}`
  - Renames or reorders active step, automatically closing and shifting ordering gaps.
- `DELETE /api/admin/process-steps/{id}`
  - Deactivates step (`isActive = false`) and closes active step ordering gaps. Idempotent.
- `POST /api/admin/process-steps/{id}/reactivate`
  - Reactivates an inactive step (`isActive = true`) and appends it to the end of the active workflow (`stepOrder = activeSteps.size() + 1`).
  - Returns `400 Bad Request` if step is already active.
  - Returns `409 Conflict` if an active step with the same name already exists.

### Admin Log Access & Export (`/api/admin/logs`)

- `GET /api/admin/logs`
  - Access: `ROLE_ADMIN` only.
  - Returns `List<JobStepHistoryResponse>` ordered newest `createdAt` first.
- `GET /api/admin/logs/export`
  - Access: `ROLE_ADMIN` only.
  - Downloads an Excel spreadsheet (`.xlsx`) containing complete job audit logs across all job statuses (`IN_PROGRESS`, `WORK_DONE`, `JOB_COMPLETED`, `CANCELLED`, reopened).
  - Response Headers:
    - `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
    - `Content-Disposition: attachment; filename="job_logs.xlsx"`
  - Worksheet Name: `Job Logs` (top row frozen, styled headers, auto-sized columns).
  - Columns:
    1. `Job Number`
    2. `Company Name`
    3. `Job Status`
    4. `Chalan Number`
    5. `Step Name` (blank for job-level events `CHALAN_ADDED` and `JOB_COMPLETED`)
    6. `Action`
    7. `Performed By`
    8. `Timestamp` (UTC: `yyyy-MM-dd HH:mm:ss`)
  - Ordering: Deterministic (`created_at DESC, id DESC`).

---

## 5. Manager Job Management APIs

**Access**: `ROLE_MANAGER`

### Job Lifecycle

```
[CREATE] -> IN_PROGRESS
              |      \
              |       \ [Cancel]
              v        v
          WORK_DONE   CANCELLED
          /       \
[Add Chalan]       \ [Reopen from Step X]
        v           v
  JOB_COMPLETED   IN_PROGRESS
```

### Endpoints (`/api/manager/jobs`)

- `POST /api/manager/jobs`
  - Body:
    ```json
    {
      "jobNumber": "1704",
      "companyName": "Acme Doors"
    }
    ```
  - Creates job with status `IN_PROGRESS` and `createdBy` bound to the authenticated manager.
  - Snapshots current active `ProcessStep` records into decoupled `JobStep` entities in contiguous order.
- `GET /api/manager/jobs`
  - Returns `List<JobResponse>` sorted newest `createdAt` first.
- `GET /api/manager/jobs/{id}`
  - Returns single `JobResponse` including ordered snapshot steps.
- `PUT /api/manager/jobs/{id}/cancel`
  - Cancels an `IN_PROGRESS` job -> sets status to `CANCELLED`.
  - Rejects cancelling already `CANCELLED` (400), `WORK_DONE` (400), or `JOB_COMPLETED` (400) jobs.
- `PUT /api/manager/jobs/{id}/reopen`
  - Body: `{"stepId": "<uuid>"}`
  - Reopens a `WORK_DONE` job:
    - Resets target step and all subsequent steps to `PENDING` (clears `completedBy` and `completedAt`).
    - Earlier steps remain `COMPLETED`.
    - Resets Job `status` to `IN_PROGRESS` and `completedAt` to `null`.
    - Creates audit entry in `JobStepHistory` with `action = REOPENED`.
  - Rejects `IN_PROGRESS` or `CANCELLED` jobs (400).
- `GET /api/manager/jobs/logs`
  - Returns audit trail of all job step actions across jobs ordered newest `createdAt` first.
- `GET /api/manager/jobs/{id}/logs`
  - Returns audit trail for a specific job (`List<JobStepHistoryResponse>`).
- `GET /api/manager/logs/export`
  - Access: `ROLE_MANAGER` only.
  - Downloads an Excel spreadsheet (`.xlsx`) identical in structure, headers, and scope to the Admin log export.
  - Response Headers:
    - `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
    - `Content-Disposition: attachment; filename="job_logs.xlsx"`
  - Worksheet Name: `Job Logs` (top row frozen, styled headers, auto-sized columns).
  - Columns:
    1. `Job Number`
    2. `Company Name`
    3. `Job Status`
    4. `Chalan Number`
    5. `Step Name` (blank for job-level events `CHALAN_ADDED` and `JOB_COMPLETED`)
    6. `Action`
    7. `Performed By`
    8. `Timestamp` (UTC: `yyyy-MM-dd HH:mm:ss`)
  - Ordering: Deterministic (`created_at DESC, id DESC`).

---

## 6. Worker Job Workflow APIs

**Access**: `ROLE_WORKER`

### Endpoints (`/api/worker`)

- `GET /api/worker/jobs`
  - Returns active jobs available to workers (status `IN_PROGRESS` only; excludes `CANCELLED` and `WORK_DONE`).
  - Deterministic order (newest `createdAt` first).
- `GET /api/worker/jobs/{id}`
  - Returns job details and ordered `JobStep` snapshot.
- `PUT /api/worker/job-steps/{stepId}/complete`
  - Completes exactly one step:
    - Enforces sequential execution: must be the **first pending step** in `stepOrder`.
    - Sets step `status = COMPLETED`, `completedBy = authenticatedWorker`, and `completedAt = now`.
    - If this was the final pending step, sets `Job.status = WORK_DONE` and `Job.completedAt = now`.
    - Creates a `JobStepHistory` entry with `action = COMPLETED`.
    - Automatically creates a `Notification` for all active managers:
      `Job #{jobNumber}: {stepName} completed by {workerName}.`
- `PUT /api/worker/job-steps/{stepId}/undo`
  - Undoes exactly one step:
    - Only the **latest completed step** (highest `stepOrder`) can be undone.
    - Job must be `IN_PROGRESS`. Cannot undo steps in `WORK_DONE`, `CANCELLED`, or `JOB_COMPLETED` jobs.
    - Sets step `status = PENDING`, `completedBy = null`, and `completedAt = null`.
    - Creates a `JobStepHistory` entry with `action = UNDONE`.
- `PUT /api/worker/jobs/{id}/chalan`
  - Records or updates the dispatch Chalan number on a job.
  - Body:
    ```json
    {
      "chalanNumber": "CH-10294"
    }
    ```
  - Rules:
    - Restricted to `ROLE_WORKER`.
    - Job must exist (404).
    - Job must be in `WORK_DONE` status (returns 400 if `IN_PROGRESS`, `CANCELLED`, or `JOB_COMPLETED`).
    - `chalanNumber` must be non-blank and maximum 100 characters (trimmed).
    - Records an audit entry in `JobStepHistory` with `action = CHALAN_ADDED` (job-level, `jobStepId = null`).
    - Returns updated `JobResponse`.
- `PUT /api/worker/jobs/{id}/complete`
  - Final completion of a manufacturing job.
  - Rules:
    - Restricted to `ROLE_WORKER`.
    - Job must exist (404).
    - Job must currently be in `WORK_DONE` status (returns 400 if `IN_PROGRESS`, `CANCELLED`, or `JOB_COMPLETED`).
    - All job steps must be `COMPLETED` (returns 400 if any step is `PENDING`).
    - `chalanNumber` must already be present and non-blank (returns 400 if missing).
    - Updates job `status = JOB_COMPLETED` and sets `completedAt = now`.
    - Records an audit entry in `JobStepHistory` with `action = JOB_COMPLETED` (job-level, `jobStepId = null`).
    - Once completed, the job is permanently locked (cannot be cancelled, reopened, or steps modified).
    - Returns updated `JobResponse`.

---

## 7. Notifications APIs

**Access**: Authenticated (`ADMIN`, `MANAGER`, `WORKER`)

- `GET /api/notifications`
  - Returns all notifications belonging to the authenticated user, newest first.
- `GET /api/notifications/unread`
  - Returns only unread notifications (`isRead = false`) for the authenticated user.
- `PUT /api/notifications/{id}/read`
  - Marks notification as read (`isRead = true`).
  - Users can only mark their own notifications (accessing another user's notification returns 404).

---

## 8. Common Data Transfer Objects

### `JobResponse`
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "jobNumber": "1704",
  "companyName": "Acme Doors",
  "status": "IN_PROGRESS",
  "createdBy": "Alice Manager",
  "createdAt": "2026-09-09T07:00:00Z",
  "updatedAt": "2026-09-09T07:00:00Z",
  "completedAt": null,
  "chalanNumber": "CH-10294",
  "steps": [
    {
      "id": "c71a34b2-031f-49f3-8b77-3ce93fc0c598",
      "stepName": "Cutting",
      "stepOrder": 1,
      "status": "COMPLETED",
      "completedBy": "Bob Worker",
      "completedAt": "2026-09-09T07:15:00Z"
    },
    {
      "id": "df112233-4455-6677-8899-aabbccddeeff",
      "stepName": "Welding",
      "stepOrder": 2,
      "status": "PENDING",
      "completedBy": null,
      "completedAt": null
    }
  ]
}
```

### `JobStepHistoryResponse`
```json
{
  "id": "01234567-89ab-cdef-0123-456789abcdef",
  "jobId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "jobStepId": "c71a34b2-031f-49f3-8b77-3ce93fc0c598",
  "stepName": "Cutting",
  "action": "COMPLETED",
  "performedBy": "Bob Worker",
  "createdAt": "2026-09-09T07:15:00Z"
}
```

### `NotificationResponse`
```json
{
  "id": "98765432-10fe-dcba-9876-543210fedcba",
  "jobId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "message": "Job #1704: Cutting completed by Bob Worker.",
  "isRead": false,
  "createdAt": "2026-09-09T07:15:00Z"
}
```
