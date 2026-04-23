# API Conventions

[SPEC] Define your project's API conventions. This module pairs with the `api-designer` skill.

## API Style
[SPEC] Choose: REST | GraphQL | gRPC | mixed

## Base URL
[SPEC] e.g., `/api/v1`

## Authentication
[SPEC] Choose: JWT | API key | OAuth2 | Session | none
- Token location: [SPEC] (Authorization header, cookie, query param)
- Token format: [SPEC] (Bearer {token}, X-API-Key: {key})

## Versioning
Strategy: [SPEC] (URL prefix `/v1`, header `Accept-Version`, query `?version=1`)
See also: `docs/specs/versioning/`

## Request/Response Format

### Content type
`application/json` (default)

### Pagination
[SPEC] Choose and fill in:

**Option A — Offset-based:**
```json
GET /api/v1/items?page=1&limit=20

{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

**Option B — Cursor-based:**
```json
GET /api/v1/items?cursor=abc123&limit=20

{
  "data": [...],
  "pagination": {
    "cursor": "def456",
    "hasMore": true
  }
}
```

### Filtering & sorting
```
GET /api/v1/items?status=active&sort=created_at&order=desc
```

### Error format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  }
}
```

### Standard error codes
| Code | HTTP | Meaning |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Request body/params failed validation |
| `UNAUTHORIZED` | 401 | Missing or invalid authentication |
| `FORBIDDEN` | 403 | Authenticated but not authorized |
| `NOT_FOUND` | 404 | Resource does not exist |
| `CONFLICT` | 409 | Resource state conflict (e.g., duplicate) |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unexpected server error |

## Naming conventions
- Resources: plural nouns (`/users`, `/orders`, `/products`)
- Actions: use HTTP methods, not verbs in URL (`POST /orders`, not `/createOrder`)
- Nested resources: max 2 levels (`/users/{id}/orders`, not `/users/{id}/orders/{id}/items`)
- IDs: [SPEC] (UUID v4, nanoid, auto-increment)
- Dates: ISO 8601 (`2026-04-01T12:00:00Z`)
- Enums: lowercase snake_case (`order_status`, not `OrderStatus`)

## Rate limiting
[SPEC] Define per-endpoint or global:
- Public endpoints: [SPEC] requests per minute
- Authenticated endpoints: [SPEC] requests per minute
- Heavy operations: [SPEC] requests per minute
- Response headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`

## CORS
[SPEC] Define allowed origins, methods, headers:
```
Allowed origins: [SPEC]
Allowed methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Allowed headers: Authorization, Content-Type
Max age: 86400
```

## Security
- All endpoints require HTTPS
- Sensitive data never in URL parameters
- Input validation on all parameters (type, length, format)
- Output encoding to prevent XSS in API responses
- See also: `docs/specs/security/`

## Documentation
[SPEC] Choose: OpenAPI/Swagger | API Blueprint | Custom markdown
- Location: [SPEC] (`docs/api/openapi.yaml`, `docs/api/`, etc.)
- Auto-generation: [SPEC] (from code annotations, or manually maintained)
