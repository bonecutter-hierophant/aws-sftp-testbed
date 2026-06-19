# Specification: AWS SFTP Testbed Version Plan

Date: 2026-06-19

Status: V1 MVP implemented and under documentation closeout

## 1. Product Overview

`aws-sftp-testbed` is a public command-line toolkit that creates a disposable AWS-hosted SFTP server for integration testing. It is designed to simulate an external SFTP endpoint that another project can connect to, use, and tear down without making SFTP infrastructure part of that consuming project.

The project has two phases:

1. Bootstrap setup prepares an AWS account and IAM Identity Center operator assignment that can use the tool safely.
1. Routine operation deploys, inspects, tests, stops, starts, updates connection details for, and destroys short-lived SFTP servers.

The durable artifact is the command surface and documentation. The runtime EC2 instance, generated credentials, security group rules, public IP, smoke-test files, and connection parameter are disposable.

## 2. Current V1 Scope

V1 is the disposable EC2 SFTP testbed.

V1 includes:

- CloudFormation-managed EC2 runtime infrastructure.
- Amazon Linux 2023 with OpenSSH `internal-sftp`.
- One SFTP user with generated username/password credentials.
- One writable remote path, `/data`.
- Public IPv4 endpoint with no Elastic IP by default.
- Explicit inbound TCP `22` source CIDR through `AllowedCidr`.
- Refusal of `0.0.0.0/0` unless an explicit temporary override is passed.
- Systems Manager Parameter Store `SecureString` connection publication.
- Connection schema v1: `schemaVersion`, `protocol`, `host`, `publicIp`, `port`, `username`, `password`, `remotePath`, `hostKeyFingerprints`, and `projectName`.
- Deploy, describe, start, stop, destroy, parameter update, parameter read, diagnostics, and smoke-test command wrappers.
- Optional SSM diagnostics helper for exceptional source-IP troubleshooting.
- Destroy behavior that removes CloudFormation-managed runtime resources and deletes the project-owned connection parameter by default.

V1 bootstrap includes:

- Top-level `bootstrap/` setup lane separate from routine `scripts/`.
- Human-owned AWS account creation guidance.
- IAM Identity Center as the preferred routine access model.
- Project-scoped `AwsSftpServer-Operator` permission set.
- Account assignment to the project operator identity.
- Local SSO-backed AWS CLI routine profile setup.
- Validation that routine access cannot use AWS Organizations bootstrap APIs.

## 3. V1 Locked Decisions

- The user must already have access to an AWS account and be able to sign in through the AWS CLI.
- AWS account creation, account email ownership, billing visibility, root-account recovery, and MFA are human-owned prerequisites.
- One-time setup helpers live in `bootstrap/`.
- Routine runtime commands live in `scripts/`.
- Routine operator access uses IAM Identity Center.
- Legacy IAM users or roles may exist for bootstrap, but they are not the preferred routine workflow.
- Parameter Store is the default publisher for connection details because standard `SecureString` parameters fit the low-cost disposable testbed model.
- Consumers may store the connection secret in whatever reviewed secret store they trust; this repo does not require a branded Secret Keeper integration.
- Generated username/password authentication is the V1 auth mode.
- SSH public-key authentication is deferred until key material generation, storage, publication, rotation, and cleanup are designed explicitly.
- Host key fingerprints are published and recommended for comparison, but host key validation is not mandatory in V1.
- Manual validation should fetch connection values from Parameter Store using authenticated project access, then test those values from the SFTP client machine.
- The SFTP client is assumed to have a stable or known outbound source CIDR.
- Dynamic source-IP diagnostics are optional troubleshooting, not part of normal deploy.
- Consumer file lifecycle behavior is outside this tool's V1 contract. The test account can read, write, and delete files; consumers decide whether to delete, archive, move, or preserve remote files.

## 4. V1 Command Surface

Bootstrap commands:

- `npm run bootstrap:inspect`
- `npm run bootstrap:create-account`
- `npm run bootstrap:ensure-permission-set`
- `npm run bootstrap:assign-permission-set`
- `npm run bootstrap:configure-profile`

Routine setup and validation commands:

- `npm run login`
- `npm run validate:routine-access`

Runtime commands:

- `npm run deploy -- <source-cidr>`
- `npm run describe`
- `npm run start`
- `npm run stop`
- `npm run destroy`
- `npm run update:parameter`
- `npm run read:parameter`
- `npm run smoke:test`

Diagnostics commands:

- `npm run diagnostics:enable`
- `npm run diagnose:source-ip`
- `npm run diagnostics:disable`

## 5. V1 Security And Cleanup Model

The runtime stack should be destroyed when testing is complete. `stop` is available when temporary state should be preserved, but it may leave billable storage and other resources behind.

The default security model is narrow:

- inbound SFTP only from an operator-provided CIDR
- no shell access for the SFTP user
- no root SSH login
- no forwarding or tunneling
- generated credentials kept out of source control
- connection details stored in Parameter Store as `SecureString`
- connection parameter deleted by default on destroy
- optional diagnostics profile removed after use

## 6. V1 Non-Goals

V1 does not provide:

- a production-grade SFTP service
- AWS Transfer Family hosting
- managed credential rotation
- SSH public-key authentication
- multiple SFTP users
- read-only or upload-only fixture users
- inbox/archive/error directory conventions
- scheduled auto-shutdown
- stable Elastic IP by default
- private VPC-only operation
- managed NAT/EIP egress for consumers
- high availability or multi-AZ operation
- a UI
- Terraform or CDK alternatives

## 7. Candidate V2 Scope

V2 should promote only features that improve repeated testbed operation without turning the project into a production SFTP service.

Candidate V2 items:

- EventBridge-based auto-shutdown for one-hour and twenty-four-hour disposable servers.
- Multiple fixture users, such as read-only, upload-only, and permission-denied users.
- SSH public-key authentication after key lifecycle design is approved.
- Host key rotation test fixtures.
- Credential rotation test fixtures.
- Large-file and many-small-files fixtures.
- S3-backed fixture file seeding.
- A stricter smoke-test matrix for success and failure paths.
- GitHub Actions examples for human-approved live smoke testing.
- More deterministic dry-run verification before live AWS actions.

V2 should preserve the V1 cleanup and public-network safety model.

## 8. Candidate V3 Scope

V3 and later ideas should be promoted only if this project becomes a broader SFTP service simulator or client-facing helper.

Candidate V3 items:

- Private VPC-only mode.
- Terraform implementation alternative.
- CDK implementation alternative.
- Customer-specific diagnostic server mode.
- Durable hosted-service mode for clients that cannot operate their own SFTP endpoint.
- Billing and cost reporting helpers for longer-lived hosted use.
- Managed credential rotation using Secrets Manager or another reviewed vault.
- More realistic remote workflow conventions, such as inbox/archive/error paths.
- Scheduled lifecycle orchestration beyond simple auto-shutdown.

V3 must not be treated as current scope. Each V3 item needs a separate proposal before implementation.

## 9. Completion Criteria For V1

V1 is complete when:

- Bootstrap docs and helpers can guide account and IAM Identity Center setup with explicit human approval gates.
- Routine access deploys the testbed without requiring management-account access.
- A deployed server accepts SFTP connections from the intended source CIDR.
- Parameter Store contains current host, IP, credentials, remote path, and host key fingerprint data after deploy or start.
- Manual or scripted smoke testing proves connect, upload, list, download, delete, empty-directory behavior, wrong-user rejection, and wrong-password rejection.
- Destroy removes CloudFormation-managed runtime resources and deletes the runtime connection parameter by default.
- Public docs describe setup, use, costs, safety defaults, validation, and cleanup.
- `npm run verify:safe` and the scoped public documentation/static gates pass.
