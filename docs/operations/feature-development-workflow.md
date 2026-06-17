# Feature Development Workflow

Date: 2026-06-16

This repository uses a documented feature workflow so public changes remain easy to review and safe to publish.

## Reader Path

Before implementation:

- Read the root `README.md`.
- Read the relevant local README beside the code being changed.
- Read `docs/operations/public-repository-sanitization.md` before first commit, PR, or push.
- Read `docs/operations/aws-sftp-boundary.md` before AWS CLI, CloudFormation, Secrets Manager, EC2, IAM, or network-security work.
- Read `docs/operations/aws-access-setup.md` before creating or documenting project-scoped AWS users, roles, policies, profiles, or account setup.
- Read `docs/operations/diagram-rendering.md` before changing PlantUML diagram workflow.
- Read `docs/operations/sandbox-safe-verification.md` before changing verification tooling.
- Read `docs/operations/scoped-verification-gates.md` before naming verification.
- For cross-cutting structure changes, update `docs/architecture/project-structure.md` and `docs/architecture/testbed-lifecycle.puml`.

## Proposal Rule

Small documentation, verification, and single-script changes can proceed directly when owner docs stay accurate.

Create a proposal in `docs/proposals/` before implementation when work changes:

- AWS resource shape
- IAM permissions
- project-scoped AWS access setup
- public network exposure
- secret schema
- credential-generation behavior
- lifecycle semantics for deploy, start, stop, or destroy
- repository workflow or verification tooling
- diagram rendering workflow

The proposal should include scope, public-repo safety notes, dependencies, implementation steps, verification gates, out-of-scope items, and a closeout checklist.

## Implementation Rules

- Keep implementation inside the approved scope.
- Keep user-facing command entrypoints in `scripts/`.
- Keep shared shell helpers in `scripts/lib/`.
- Keep deployable infrastructure in `infra/cloudformation/`.
- Keep docs close to the code or workflow that owns the behavior.
- Avoid unrelated refactors and formatting churn.
- Do not add secrets, private AWS account identifiers, tokens, credentials, generated keys, or live AWS CLI output to source control.
- Run the public sanitization gate before committing public-facing work.

## Closeout

Before calling work complete:

- Run the scoped verification gates selected for the touched files.
- Run `npm run verify:scoped structure,public-sanitization,shell-static,docs` before the first public commit or whenever public-facing structure changes.
- Confirm durable README and PlantUML docs describe the final behavior.
- Update the root README when project structure, verification, deployment, or feature status changes.
- Keep the working tree limited to intentional changes before committing.
