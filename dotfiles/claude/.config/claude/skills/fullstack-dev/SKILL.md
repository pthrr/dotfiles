---
name: fullstack-dev
description: Fullstack web development with React, TypeScript, Node.js, databases, and APIs. Use when building web applications, REST/GraphQL APIs, frontend components, or database schemas.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
---

# Fullstack Development

## Frontend

### React/TypeScript
- Use functional components with hooks
- Prefer TypeScript strict mode
- Use proper type definitions, avoid `any`
- Component naming: PascalCase
- Hook naming: use prefix (useState, useEffect, useCustomHook)

### Styling
- Prefer CSS modules or Tailwind CSS
- Mobile-first responsive design
- Use CSS custom properties for theming

## Backend

### Node.js/TypeScript
- Use async/await over callbacks
- Proper error handling with try/catch
- Use environment variables for configuration
- Validate all user input

### API Design
- RESTful: Use proper HTTP methods (GET, POST, PUT, DELETE)
- GraphQL: Define clear schemas with proper types
- Always return consistent response formats
- Include proper error codes and messages

### Database
- Use migrations for schema changes
- Index frequently queried columns
- Use transactions for multi-step operations
- Parameterized queries to prevent SQL injection

## Testing
- Unit tests for business logic
- Integration tests for API endpoints
- E2E tests for critical user flows

## Security
- Sanitize user input
- Use HTTPS in production
- Implement proper authentication (JWT, sessions)
- Set secure HTTP headers (CORS, CSP)
