# AI-Enhanced Project Management System — Dart Backend

A RESTful backend built with **pure Dart** using `dart:io`, the `shelf` framework, and MongoDB.

---

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Dart 3+ |
| HTTP Server | `shelf` + `shelf_router` |
| Database | MongoDB |
| MongoDB Driver | `mongo_dart` |
| Authentication | JWT (`dart_jsonwebtoken`) |
| Password Hashing | `bcrypt` |
| AI Provider | Google Gemini 1.5 Flash |
| HTTP Client | `http` |
| Env Variables | `dotenv` |
| CORS | `shelf_cors_headers` |

---

## Requirements

- [Dart SDK](https://dart.dev/get-dart) ≥ 3.0.0
- [MongoDB](https://www.mongodb.com/try/download/community) (local) or MongoDB Atlas (cloud)
- A [Google Gemini API key](https://aistudio.google.com/app/apikey) (for the AI chat feature)

---

## Project Structure

```
backend/
├── bin/
│   └── server.dart          # Entry point — HTTP server & routing
├── lib/
│   ├── config/
│   │   └── database.dart    # MongoDB connection singleton
│   ├── models/
│   │   ├── user.dart
│   │   ├── project.dart
│   │   ├── task.dart
│   │   ├── milestone.dart
│   │   └── comment.dart
│   └── services/
│       ├── auth_service.dart
│       ├── project_service.dart
│       ├── task_service.dart
│       ├── milestone_service.dart
│       ├── collaboration_service.dart
│       ├── comment_service.dart
│       └── ai_service.dart
├── .env.example
├── pubspec.yaml
└── README.md
```

---

## MongoDB Setup

### Local MongoDB

1. Install MongoDB Community Edition from https://www.mongodb.com/try/download/community
2. Start the MongoDB service:
   ```bash
   # Windows
   net start MongoDB

   # macOS/Linux
   sudo systemctl start mongod
   ```
3. The database `project_management` and its collections will be created automatically on first use.

### MongoDB Atlas (Cloud)

1. Create a free cluster at https://cloud.mongodb.com
2. Create a database user and whitelist your IP
3. Copy the connection string and set it as `MONGO_URI` in your `.env` file

---

## Environment Variables

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

| Variable | Required | Description |
|---|---|---|
| `MONGO_URI` | Yes | MongoDB connection string |
| `JWT_SECRET` | Yes | Secret key for signing JWT tokens |
| `GEMINI_API_KEY` | Yes (for AI) | Google Gemini API key |
| `PORT` | No | Server port (default: `8080`) |

---

## Installation

```bash
cd backend
dart pub get
```

---

## Starting the Server

```bash
dart run bin/server.dart
```

The server will start and print:

```
╔══════════════════════════════════════════════════╗
║   AI Project Management System — Dart Backend   ║
╠══════════════════════════════════════════════════╣
║  Server running on  http://localhost:8080         ║
║  MongoDB connected  ✓                            ║
╚══════════════════════════════════════════════════╝
```

---

## API Endpoints

### Health Check
```
GET /health
```

### Authentication

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/register` | Register a new user |
| POST | `/api/auth/login` | Login and receive JWT token |

### Projects

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/projects` | Create a project |
| GET | `/api/projects` | Get all projects |
| GET | `/api/projects/:id` | Get a single project |
| PUT | `/api/projects/:id` | Update a project |
| DELETE | `/api/projects/:id` | Delete a project (cascades tasks/milestones/comments) |

### Tasks

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/tasks` | Create a task |
| GET | `/api/tasks/project/:projectId` | Get all tasks for a project |
| GET | `/api/tasks/:id` | Get a single task |
| PUT | `/api/tasks/:id` | Update a task |
| DELETE | `/api/tasks/:id` | Delete a task |

### Milestones

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/milestones` | Create a milestone |
| GET | `/api/milestones/project/:projectId` | Get all milestones for a project |
| GET | `/api/milestones/:id` | Get a single milestone |
| PUT | `/api/milestones/:id` | Update a milestone |
| DELETE | `/api/milestones/:id` | Delete a milestone |

### Collaboration

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/projects/:id/collaborators` | Add a collaborator |
| GET | `/api/projects/:id/collaborators` | Get all collaborators |
| DELETE | `/api/projects/:id/collaborators/:userId` | Remove a collaborator |

### Comments

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/projects/:id/comments` | Add a comment |
| GET | `/api/projects/:id/comments` | Get all comments |
| DELETE | `/api/comments/:id` | Delete a comment |

### AI Chat

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/ai/chat` | Send a message to the AI assistant |

---

## Example Requests

### Register a User
```json
POST /api/auth/register
Content-Type: application/json

{
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "password": "securepassword123"
}
```

Response:
```json
{
  "success": true,
  "message": "User registered successfully.",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": "64f3a1b2c3d4e5f678901234",
      "name": "Alice Johnson",
      "email": "alice@example.com",
      "createdAt": "2024-09-01T10:00:00.000Z"
    }
  }
}
```

### Create a Project
```json
POST /api/projects
Content-Type: application/json

{
  "name": "Website Redesign",
  "description": "Complete overhaul of the company website",
  "category": "Design",
  "status": "active",
  "priority": "high",
  "startDate": "2024-09-01",
  "endDate": "2024-12-31",
  "ownerId": "64f3a1b2c3d4e5f678901234"
}
```

### Create a Task
```json
POST /api/tasks
Content-Type: application/json

{
  "projectId": "64f3a1b2c3d4e5f678905678",
  "title": "Design homepage mockup",
  "description": "Create wireframes and high-fidelity designs",
  "status": "in_progress",
  "priority": "high",
  "dueDate": "2024-09-15",
  "assignedTo": "64f3a1b2c3d4e5f678901234"
}
```

### AI Chat with Project Context
```json
POST /api/ai/chat
Content-Type: application/json

{
  "message": "What tasks are still pending and which has the highest priority?",
  "projectId": "64f3a1b2c3d4e5f678905678"
}
```

### Add a Collaborator
```json
POST /api/projects/64f3a1b2c3d4e5f678905678/collaborators
Content-Type: application/json

{
  "userId": "64f3a1b2c3d4e5f678901235"
}
```

### Add a Comment
```json
POST /api/projects/64f3a1b2c3d4e5f678905678/comments
Content-Type: application/json

{
  "userId": "64f3a1b2c3d4e5f678901234",
  "message": "The homepage mockup looks great! Let's proceed to development."
}
```

---

## API Response Format

All responses follow a consistent format:

**Success:**
```json
{
  "success": true,
  "message": "Operation completed successfully.",
  "data": { ... }
}
```

**Error:**
```json
{
  "success": false,
  "message": "Description of what went wrong."
}
```

### HTTP Status Codes

| Code | Meaning |
|---|---|
| 200 | OK — request succeeded |
| 201 | Created — resource was created |
| 400 | Bad Request — invalid input |
| 401 | Unauthorized — authentication failed |
| 403 | Forbidden — not allowed |
| 404 | Not Found — resource missing |
| 409 | Conflict — duplicate resource |
| 500 | Server Error — unexpected error |

---

## Valid Enum Values

### Project Status
`planning`, `active`, `on_hold`, `completed`, `cancelled`

### Project Priority
`low`, `medium`, `high`, `critical`

### Task Status
`todo`, `in_progress`, `in_review`, `done`, `cancelled`

### Task Priority
`low`, `medium`, `high`, `critical`

### Milestone Status
`pending`, `in_progress`, `completed`, `missed`

---

## Postman Testing Instructions

1. **Install Postman** from https://www.postman.com/downloads/
2. **Create a new Collection** called "Project Management API"
3. **Set Base URL** variable: `http://localhost:8080`
4. **Test flow:**
   1. `POST /api/auth/register` — copy the returned `token` and `user.id`
   2. `POST /api/projects` — use the `ownerId` from step 1, copy returned project `id`
   3. `POST /api/tasks` — use the project `id` as `projectId`
   4. `POST /api/milestones` — use the project `id` as `projectId`
   5. `POST /api/projects/{id}/collaborators` — add another user
   6. `POST /api/projects/{id}/comments` — add a comment
   7. `POST /api/ai/chat` — send a message with `projectId` for full context

> **Tip:** Add `Content-Type: application/json` header to all POST/PUT requests.
> The Authorization header (Bearer token) is accepted but not strictly enforced on all routes in this version — authentication middleware can be added per-route as needed.

---

## Architecture

```
Request
   ↓
bin/server.dart        — Route matching, request parsing, response formatting
   ↓
lib/services/          — Business logic, validation, database operations
   ↓
lib/config/database.dart — MongoDB connection singleton
   ↓
MongoDB                — Persistent storage
   ↓
JSON Response
```
