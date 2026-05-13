# Architecture

> Populated by `/onboard-project` — do not edit by hand until after customization is complete.
> Update this file whenever the service boundary, data flow, or integration topology changes.

## Service type

<!-- e.g. ASP.NET Core Web API / .NET Worker Service / Minimal API / Background Service -->
_populated by /onboard-project_

## What this service does

<!-- 2–4 sentences: purpose, who uses it, core value it provides -->
_populated by /onboard-project_

## Data flow

```
<!-- ASCII diagram populated by /onboard-project — example:

[Client] ──HTTP──> [API Controller]
                       │
                  [Service Layer]
                       │
               ┌───────┴───────┐
        [EF Core Repo]    [Message Bus]
               │
          [SQL Server]
-->
```

## Key boundaries

<!-- Rules derived from Program.cs and service patterns — e.g.:
- All external input validated at the controller/consumer layer — never inside domain services
- Database access only through repository interfaces — no DbContext in controllers or services
- Hosted services own their queue connections
-->
_populated by /onboard-project_

## Integration points

<!-- Upstream and downstream systems — e.g.:
| System | Direction | Protocol | Purpose |
|--------|-----------|----------|---------|
| SQL Server | downstream | EF Core | Primary datastore |
| RabbitMQ | both | AMQP | Async messaging |
| Auth service | upstream | JWT | Identity |
-->
_populated by /onboard-project_

## Hosted service topology

<!-- If applicable — describes IHostedService / BackgroundService implementations:
- MyHostedService — owns the inbound queue; dispatches to IDeviceService per message type
- OutboxHostedService — polls outbox table, publishes to broker, deletes on success
-->
_populated by /onboard-project_
