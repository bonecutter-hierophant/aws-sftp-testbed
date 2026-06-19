# aws-sftp-testbed

`aws-sftp-testbed` is a public command-line infrastructure toolkit for creating a disposable AWS-hosted SFTP server for integration testing.

The project is designed for SimpleETL development and similar workflows that need a realistic external SFTP endpoint. It is not part of SimpleETL itself, and it is not intended to be a production SFTP service.

The public shape matters because this kind of tool sits at an unusual boundary. It is not a long-running application in the traditional sense; it is closer to an installer or operator toolkit that affects AWS instead of a local machine. Its commands create, inspect, test, stop, and destroy cloud resources. Because those actions touch AWS accounts, IAM, public networking, credentials, and cleanup, the repository treats safety and repeatability as product features, not afterthoughts. Bootstrap access, routine operator access, runtime infrastructure, generated credentials, and documentation all get separate boundaries so the tool can be useful without normalizing broad cloud permissions.

## Current Status

- [x] Empty public repository checked out
- [x] Initial documentation and ownership structure established
- [x] Public-repository sanitization and static verification scaffolded
- [x] AWS account bootstrap workflow implemented and documented
- [x] CloudFormation template implemented
- [x] Deploy/start/stop/destroy scripts implemented
- [x] Parameter Store update flow implemented
- [x] SFTP smoke test implemented

## Intended Shape

The MVP should provide AWS CLI wrapper scripts that can:

- deploy a public EC2-based SFTP test server with CloudFormation
- require a caller-provided allowed CIDR for inbound SFTP
- generate disposable SFTP credentials
- discover the current public host after deploy or start
- update AWS Systems Manager Parameter Store with current connection details
- run an SFTP smoke test for connect, upload, list, download, and delete
- stop or destroy the testbed when testing is complete

The long-term goal is not merely "an EC2 instance with SSH enabled." The goal is a small public toolkit that explains and automates the responsible path: create or configure a scoped AWS account, switch away from elevated bootstrap access, deploy a disposable SFTP endpoint, publish only the current connection details needed by a consumer, then tear the runtime resources all the way down when testing is done.

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
- Source CIDR discovery: `docs/operations/source-cidr-discovery.md`
- Diagram rendering: `docs/operations/diagram-rendering.md`
- MVP tooling roadmap: `docs/proposals/mvp-tooling-roadmap.md`
- Sandbox-safe verification: `docs/operations/sandbox-safe-verification.md`
- Verification gates: `docs/operations/scoped-verification-gates.md`
- Project structure: `docs/architecture/project-structure.md`
- Script entrypoints: `scripts/README.md`
- CloudFormation ownership: `infra/cloudformation/README.md`

## Verification

Verification follows the same top-down pattern used in SimpleETL, scaled down for this repository: stable public commands call repo-owned checks, and each check has a narrow responsibility. The current framework is intentionally static and sandbox-safe because the first public version should prove repository shape and safety before it creates live AWS resources.

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

Current gates:

- `structure` confirms the documented owner folders and required docs exist.
- `public-sanitization` scans text files for common secrets, local user paths, generated keys, and public-repo hygiene risks.
- `shell-static` checks shell entrypoints for basic safety shape.
- `cloudformation-static` checks safety-critical CloudFormation template shape.
- `bootstrap-static` checks bootstrap scripts for lane selection, approval gates, and expected bounded AWS calls.
- `docs` checks text files for trailing whitespace.

Future runtime work should add deterministic dry-run checks before any live AWS smoke test becomes part of the workflow.

## Deploy Preview

The deploy command creates or updates the disposable runtime stack and requires an explicit inbound SFTP source CIDR:

```text
npm run deploy -- <source-cidr>
```

Temporary public exposure must be explicit:

```text
npm run deploy -- 0.0.0.0/0 allow-public-cidr
```

Deploy generates disposable SFTP credentials into `.local/<stack-name>-credentials.env`, which is ignored by Git. Do not commit generated credentials or stack outputs.

By default, deploy discovers the account default VPC and a default subnet, then launches the instance with an explicit public IPv4 association. Accounts without a default VPC or default subnet can pass `--vpc-id` and `--subnet-id`; the subnet must be publicly routable for external clients such as FileZilla.

If SFTP times out, first confirm that the deployed `AllowedCidr` exactly matches the public IP of the machine running the SFTP client. If that still does not explain the timeout, temporarily add the diagnostics helper to an existing server:

```text
npm run diagnostics:enable
npm run diagnose:source-ip
npm run diagnostics:disable
```

This attaches a project-scoped SSM instance profile so the helper can read recent `sshd` journal entries through SSM Run Command, then removes that profile when diagnosis is complete. It does not enable CloudWatch log ingestion and is not part of normal server operation.

Common lifecycle commands:

```text
npm run describe
npm run stop
npm run start
npm run destroy
```

`stop` preserves the stack, attached storage, and published connection parameter for later reuse. `start` refreshes the parameter because public endpoint values may change. `destroy` deletes CloudFormation-managed runtime resources and removes the published connection parameter by default so stale endpoints do not accumulate. Direct script users can pass `--keep-parameter` for explicit debugging or handoff cases.

Deploy and start refresh the project-owned connection parameter by default. You can also update it directly:

```text
npm run update:parameter
```

When console access is unavailable, read the published connection value through the CLI:

```text
npm run read:parameter -- show-sensitive
```

Run the SFTP smoke test after the instance is reachable:

```text
npm run smoke:test
```

The smoke test requires `sshpass`, `sftp`, and `ssh-keyscan` for noninteractive password authentication.

A live manual smoke test using FileZilla proved SFTP login, upload, list, download, delete, empty-directory behavior, wrong-user rejection, and wrong-password rejection against a restricted `/32` source rule. The scripted `smoke:test` path remains the repeatable command-line check for the successful transfer flow.

Interim connection parameter schema:

```text
host, publicIp, port, username, password, remotePath, hostKeyFingerprints, projectName
```

The default Parameter Store name is `/sftp-testbed/aws-sftp-server/connection`. For a desktop SFTP client such as FileZilla, use `host` or `publicIp`, `port` value `22`, `username`, and `password` from the Parameter Store value. The remote path is `/data`.

The MVP uses SSM Parameter Store `SecureString` for this published connection payload. This schema is interim until the consuming SFTP implementation settles. Secrets Manager is left as a future option for managed rotation workflows, but disposable testbed credential rotation should normally happen through redeploying the runtime stack.

## Diagram Rendering

PlantUML diagrams follow the SimpleETL local-preview workflow. Install Java SDK, Graphviz, and the recommended VS Code PlantUML extension, then preview `.puml` files from VS Code. Details live in `docs/operations/diagram-rendering.md`.

## Public Repository Boundary

This repository is public. Do not commit secrets, private keys, AWS account IDs, IAM ARNs, live AWS CLI outputs, generated credentials, deployment logs, local profiles, or machine-local private context.

The committed project should stay conservative, explicit, and safe by default. Real AWS values belong in local environment variables, ignored local files, or AWS services, not in source control.

AWS access should be durable and project-scoped, while the SFTP runtime stack should be disposable. Keep the account/user/profile setup available for future testbed runs, but destroy EC2 runtime resources when testing is complete.

The bootstrap lane is deliberately treated as different from ordinary use. Elevated access may be needed to create an AWS account, identity, and permission set; normal deploy/start/stop/destroy commands should use the narrower project-scoped access created by that bootstrap step.

## Cost Posture

This project should optimize for disposable, low-cost use, but it should not claim to be free. Stopped EC2 instances do not accrue instance runtime charges, but attached EBS volumes and some other resources can still incur charges. Full teardown should be the default when the testbed is no longer needed.
