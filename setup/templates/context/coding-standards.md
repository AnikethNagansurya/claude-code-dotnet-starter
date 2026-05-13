# Coding Standards

> Baseline standards live in `.claude/rules/coding-standards.md`.
> This file captures **service-specific extensions and overrides** — patterns unique to this codebase
> that differ from or extend the baseline. Populated by `/onboard-project`; updated via `@lesson-curator`.

## Naming conventions

<!-- Service-specific extensions to the baseline naming rules — e.g.:
- DTOs use `XxxDTO` suffix (not `XxxDto` or `XxxResponse`)
- Repository classes: `EF{Entity}Repository` prefix
- Hosted services: `{Concern}HostedService` suffix
- Constants class: `{Domain}Constants` (not static, fields not properties)
-->
_populated by /onboard-project_

## Async and cancellation

<!-- Any deviations from baseline async rules — e.g.:
- Fire-and-forget pattern is intentional in OutboxService — uses _ = Task.Run(...)
- CancellationToken is optional on internal helper methods per team decision
-->
_populated by /onboard-project_

## EF Core conventions

<!-- Service-specific EF patterns — e.g.:
- All entities have a shadow `RowVersion` byte[] for optimistic concurrency
- Soft-delete via `IsArchived` bool + global query filter (never use hard delete)
- Migrations: manual Up/Down only — never run `dotnet ef migrations add`
-->
_populated by /onboard-project_

## GUID / ID generation

<!-- Any deterministic ID patterns — e.g.:
- Status type GUIDs are derived via SHA-256 from the type name — see GuidHelper.Deterministic()
- Never use Guid.NewGuid() for entity IDs that must be stable across deployments
-->
_populated by /onboard-project_

## Logging conventions

<!-- Service-specific logging patterns — e.g.:
- Method name prefix in every log call: const string method = "[ServiceName.MethodAsync]"
- CorrelationId always pushed into scope at controller/consumer entry point
-->
_populated by /onboard-project_

## Service-specific conventions

<!-- Anything else unique to this codebase that agents should know — e.g.:
- Message type routing uses a Dictionary<string, IMessageProcessor> — do NOT use switch
- All appsettings sections are strongly typed via IOptions<T> with ValidateOnStart
-->
_populated by /onboard-project_
