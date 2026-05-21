---
title: "API 文档"
description: "API 接口文档示例"
category: "realworld"
expectedFeatures:
  - "API 文档"
  - "HTTP 代码块"
  - "参数表格"
---

# User API

## Get User

```http
GET /api/users/{id}
```

### Path Parameters

| Parameter | Type   | Required | Description |
|-----------|--------|----------|-------------|
| id        | string | Yes      | User ID     |

### Response

```json
{
    "id": "12345",
    "name": "John Doe",
    "email": "john@example.com",
    "role": "admin",
    "created_at": "2024-01-15T10:30:00Z"
}
```

### Error Codes

- `200` - Success
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `500` - Server Error

## Update User

```http
PUT /api/users/{id}
```

### Body Parameters

| Field | Type   | Required | Description  |
|-------|--------|----------|--------------|
| name  | string | No       | User name    |
| email | string | No       | User email   |
| role  | string | No       | User role    |
