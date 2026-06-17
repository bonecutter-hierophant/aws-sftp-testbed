# aws-sftp-testbed

`aws-sftp-testbed` is a public command-line infrastructure helper for creating a disposable AWS-hosted SFTP server for integration testing.

The project is designed for SimpleETL development and similar workflows that need a realistic external SFTP endpoint. It is not part of SimpleETL itself, and it is not intended to be a production SFTP service.

## Current Status

- [x] Empty public repository checked out
- [x] Initial documentation and ownership structure established
- [x] Public-repository sanitization and static verification scaffolded
- [ ] CloudFormation template implemented
- [ ] Deploy/start/stop/destroy scripts implemented
- [ ] Secrets Manager update flow implemented
- [ ] SFTP smoke test implemented

## Intended Shape

The MVP should provide AWS CLI wrapper scripts that can:

- deploy a public EC2-based SFTP test server with CloudFormation
- require a caller-provided allowed CIDR for inbound SFTP
- generate disposable SFTP credentials
- discover the current public host after deploy or start
- update AWS Secrets Manager with current connection details
- run an SFTP smoke test for connect, upload, list, download, and delete
- stop or destroy the testbed when testing is complete

## Structure

```text
.
+-- docs/
|   +-- architecture/       Repo-level structure and diagrams
|   +-- operations/         Workflow, AWS boundary, and verification docs
+-- infra/
|   +-- cloudformation/     CloudFormation template and template docs
+-- scripts/                Public command-line entrypoints
|   +-- lib/                Shared shell helpers
+-- tools/                  Repo-owned verification helpers
```

## Reader Path

- Repo workflow: `AGENTS.md`
- Feature process: `docs/operations/feature-development-workflow.md`
- Public repository sanitization: `docs/operations/public-repository-sanitization.md`
- AWS SFTP boundary: `docs/operations/aws-sftp-boundary.md`
- AWS access setup: `docs/operations/aws-access-setup.md`
- Sandbox-safe verification: `docs/operations/sandbox-safe-verification.md`
- Verification gates: `docs/operations/scoped-verification-gates.md`
- Project structure: `docs/architecture/project-structure.md`
- Script entrypoints: `scripts/README.md`
- CloudFormation ownership: `infra/cloudformation/README.md`

## Verification

List available gates:

```text
npm run verify:list
```

Run the sandbox-friendly safe lane:

```text
npm run verify:safe
```

Run the normal first-commit structure lane:

```text
npm run verify:scoped structure,public-sanitization,shell-static,docs
```

## Public Repository Boundary

This repository is public. Do not commit secrets, private keys, AWS account IDs, IAM ARNs, live AWS CLI outputs, generated credentials, deployment logs, local profiles, or machine-local private context.

The committed project should stay boring, explicit, and safe by default. Real AWS values belong in local environment variables, ignored local files, or AWS services, not in source control.

AWS access should be durable and project-scoped, while the SFTP runtime stack should be disposable. Keep the account/user/profile setup available for future testbed runs, but destroy EC2 runtime resources when testing is complete.

## Cost Posture

This project should optimize for disposable, low-cost use, but it should not claim to be free. Stopped EC2 instances do not accrue instance runtime charges, but attached EBS volumes and some other resources can still incur charges. Full teardown should be the default when the testbed is no longer needed.
