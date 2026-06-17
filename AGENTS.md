# aws-sftp-testbed Agent Instructions

This repository follows the same feature-development discipline as Bonecutters, adjusted for a public command-line AWS testbed.

Before changing code:

- Read the root `README.md`.
- Read `docs/operations/public-repository-sanitization.md` before first commit, PR, or push.
- Read `docs/operations/aws-sftp-boundary.md` before AWS CLI, CloudFormation, Secrets Manager, EC2, IAM, or network-security work.
- Read `docs/operations/aws-access-setup.md` before creating or documenting project-scoped AWS users, roles, policies, profiles, or account setup.
- Read `docs/operations/sandbox-safe-verification.md` before adding or changing verification tooling.
- Use `docs/operations/feature-development-workflow.md` for non-trivial feature work.
- Read the relevant local `README.md` beside scripts, infrastructure templates, or docs being changed.
- Keep public-repository hygiene in mind: do not commit secrets, private keys, private AWS account details, generated AWS outputs, live credentials, or machine-local private context.

For implementation:

- Prefer AWS CLI, CloudFormation, and Bash helper scripts.
- Keep deployable infrastructure in `infra/cloudformation/`.
- Keep command-line entrypoints in `scripts/` and shared shell helpers in `scripts/lib/`.
- Keep repo-owned verification helpers in `tools/`.
- Keep docs close to the code or workflow that owns the behavior.
- Document security and cleanup behavior in the same change as any AWS resource or script behavior.
- Refuse unsafe public SFTP defaults. `AllowedCidr` must be explicit, and `0.0.0.0/0` must require an explicit temporary override.

Verification:

- Use `npm run verify:safe` for frequent sandbox-safe checks while iterating.
- Use `npm run verify:scoped <gates>` for deterministic local verification.
- Run `npm run verify:scoped structure,public-sanitization,shell-static,docs` before the first public commit or whenever public-facing structure changes.
- Git commands, including commit, push, branch, and status checks, should remain human-approved.
- AWS access, deployment, teardown, IAM, EC2, Secrets Manager, and network changes should remain human-approved.
