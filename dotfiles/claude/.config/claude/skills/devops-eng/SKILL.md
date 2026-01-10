---
name: devops-eng
description: DevOps engineering with CI/CD, containers, Kubernetes, infrastructure as code, and cloud platforms. Use when setting up pipelines, deploying services, writing Dockerfiles, or managing infrastructure.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
---

# DevOps Engineering

## Containers

### Docker
- Use multi-stage builds to minimize image size
- Pin base image versions (avoid :latest in production)
- Run as non-root user
- Use .dockerignore to exclude unnecessary files
- Order Dockerfile commands for optimal layer caching

### Podman
- Rootless containers by default
- Compatible with Docker CLI commands
- Use pods for multi-container applications

## Orchestration

### Kubernetes
- Use namespaces for isolation
- Define resource requests and limits
- Use ConfigMaps and Secrets for configuration
- Implement health checks (liveness, readiness probes)
- Use Deployments for stateless, StatefulSets for stateful apps

### Helm
- Template reusable configurations
- Use values files for environment-specific settings
- Version charts properly

## CI/CD

### GitHub Actions
- Use matrix builds for multiple environments
- Cache dependencies to speed up builds
- Use secrets for sensitive data
- Implement proper branch protection

### GitLab CI
- Use stages for pipeline organization
- Leverage artifacts between jobs
- Use rules for conditional execution

### General Practices
- Fail fast: run linting and tests early
- Automate versioning and changelog generation
- Use ephemeral environments for PR previews

## Infrastructure as Code

### Nix/NixOS
- Use flakes for reproducibility
- Pin nixpkgs versions
- Modularize configuration
- Use home-manager for user environments

### Terraform
- Use modules for reusable infrastructure
- Store state remotely with locking
- Use workspaces or separate state files per environment
- Plan before apply

### Ansible
- Use roles for organization
- Idempotent tasks
- Use vault for secrets

## Monitoring & Observability

### Metrics
- Prometheus for metrics collection
- Grafana for visualization
- Define SLIs, SLOs, and error budgets

### Logging
- Structured logging (JSON)
- Centralized log aggregation
- Appropriate log levels

### Tracing
- Implement distributed tracing
- Correlate logs with trace IDs

## Security

### Secrets Management
- Never commit secrets to version control
- Use tools like SOPS, Vault, or sealed-secrets
- Rotate secrets regularly

### Container Security
- Scan images for vulnerabilities
- Use read-only file systems where possible
- Limit capabilities

### Network Security
- Use network policies in Kubernetes
- Implement mTLS for service-to-service communication
- Principle of least privilege

## Best Practices
- Infrastructure should be version controlled
- Document runbooks for incident response
- Implement proper backup and disaster recovery
- Use GitOps workflows where applicable
