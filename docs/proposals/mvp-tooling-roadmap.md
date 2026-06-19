# MVP Tooling Roadmap

Date: 2026-06-17

Status: approved for initial implementation planning

Source PRD: Disposable AWS SFTP Testbed for SimpleETL

## Summary

`aws-sftp-testbed` should make disposable SFTP setup easy from the command line. The project is tooling for tooling: an operator toolkit that creates a realistic public SFTP endpoint that developers, CI, or coding agents can use while testing features that depend on SFTP connectivity.

The repo should be useful beyond SimpleETL, but the MVP is anchored on SimpleETL's current need for an external SFTP server that can be deployed, used, stopped, destroyed, and rebuilt with minimal manual work.

The proposal intentionally treats safety as part of the user experience. A useful public tool should not only create infrastructure; it should guide users toward scoped access, explicit network boundaries, deterministic checks, and complete teardown. In spirit, this is closer to a cloud installer/uninstaller than a service process: the thing that persists is the documented command surface, not a running application in this repository.

## Locked MVP Assumptions

- Deployment model: CloudFormation plus AWS CLI wrapper scripts.
- Region default: `us-west-1`.
- Endpoint type: public EC2 public IPv4/DNS.
- IP model: dynamic public IP, no Elastic IP by default.
- SFTP server: Amazon Linux 2023 with OpenSSH `internal-sftp`.
- Connection publication behavior: update AWS Systems Manager Parameter Store after deploy/start.
- Auth MVP: username and password.
- Auth future option: SSH public-key support after key material handling is designed.
- Remote path MVP: `/data`.
- Lifecycle default: destroy when testing is complete.
- Network safety: required `AllowedCidr`.
- Public-open override: explicit temporary flag only.
- SimpleETL coupling: connection parameter schema v1 with no dependency on SimpleETL internals.

Connection publication decision: use SSM Parameter Store `SecureString` for the MVP because standard parameters fit the low-cost disposable testbed model. Document the consumer side generically as "store the connection secret in a secret store appropriate to your project" rather than as a branded Secret Keeper requirement. Do not use Secrets Manager by default unless a future managed-rotation feature is reviewed and approved.

## Public-Repo Safety Notes

- Do not commit AWS account IDs, ARNs, local profile names, generated credentials, stack output, host keys, smoke-test files, or live Parameter Store payloads.
- Keep durable AWS access setup separate from disposable runtime infrastructure.
- Refuse deploy without `AllowedCidr`.
- Refuse `0.0.0.0/0` unless an explicit temporary override flag is provided.
- Never print full passwords or private keys unless an explicit sensitive-output flag is passed.
- Document costs plainly. The project can be low-cost, but it must not promise to be free.

## Proposal Review Status

- [x] Reviewed against the Google PRD.
- [x] Public-repo safety model accepted.
- [x] AWS access and runtime infrastructure boundary accepted.
- [x] Cost posture accepted.
- [x] Verification plan accepted.
- [x] Open decisions accepted as intentionally unresolved.
- [x] High-privilege AWS account bootstrap scope accepted.
- [x] Human owner approved this proposal as the active implementation checklist.
- [x] Approved proposal committed before implementation begins.

Review notes:

- Added lifecycle-aware connection-parameter handling: stop/start preserve or refresh the parameter for reusable runtime stacks, while destroy removes it by default to avoid stale endpoint records.
- Added command-output expectations for non-sensitive connection details because the PRD expects `describe.sh` to help the operator find the current host and SFTP username.
- Added explicit tooling dependencies so the roadmap can produce the command-line experience described by the PRD.
- Added AWS account bootstrap as an explicit product surface after proposal review. This is intentionally separate from routine testbed operation because it requires management-account or administrator authority. The approved privilege sequence is: use elevated bootstrap access to create the project AWS account, identity, and permission set; then ratchet down to the created project-scoped access for routine EC2/SFTP work.

## Privilege Sequence

1. Use existing admin/management-account AWS CLI access only for bootstrap.
2. Create or confirm a dedicated AWS Organizations member account for this project as a human-owned setup step, documented with a public-safe name such as `aws-sftp-server`.
3. Create the project-scoped IAM Identity Center permission set for this SFTP server account, documented with a public-safe name such as `AwsSftpServer-Operator`.
4. Verify the project-scoped identity can assume or access only the intended project account.
5. Switch local routine commands to the project-scoped profile or role.
6. Use the project-scoped access, not admin access, for CloudFormation, EC2, Parameter Store, and smoke-test operations.
7. Keep admin bootstrap access out of normal deploy/start/stop/destroy command paths.

The dedicated account is part of the safety model. The SFTP server should look and behave like an external server owned outside the consuming application account, keep billing separate, and keep EC2 create/destroy permissions out of unrelated project accounts.

Bootstrap approvals happen at phase boundaries. A human should approve inspect, then review the report, then approve a bounded create or assignment phase that may run several AWS API calls as one clear operation.

## Dependencies

- AWS CLI v2.
- Bash-compatible shell for repo scripts.
- OpenSSH client tools, including `ssh` and `sftp`, for smoke testing.
- Management-account or administrator AWS CLI access for the bootstrap lane that creates or configures the project AWS account and identity.
- Project-scoped AWS operator identity with CloudFormation, EC2, SSM public parameter, SSM project connection parameter, and smoke-test permissions for routine testbed operation.
- Java SDK, Graphviz, and the VS Code PlantUML extension for local diagram rendering.

## MVP Checklist

### 1. Repository Foundation

- [x] Checkout empty public repository.
- [x] Establish root README and agent workflow.
- [x] Establish docs, infrastructure, scripts, and tools ownership structure.
- [x] Add public-repository sanitization gate.
- [x] Add sandbox-safe verification lane.
- [x] Add PlantUML diagram workflow matching SimpleETL.
- [x] Add proposal review process to feature workflow.
- [x] Commit this proposal only after review approval.

### 2. AWS Account Bootstrap

- [x] Define a separate high-privilege bootstrap lane for AWS Organizations/account and identity setup.
- [x] Document that bootstrap requires management-account or administrator AWS CLI access and human approval.
- [x] Add a bootstrap preflight that refuses to run unless the caller explicitly selects the bootstrap lane.
- [x] Create or document creation of the project AWS member account from the CLI.
- [x] Track asynchronous account creation status before continuing account setup.
- [x] Document the automatically created cross-account access role and how bootstrap uses it.
- [x] Create or configure the project-scoped operator identity for routine testbed operation.
- [x] Create or configure the permission set used by that project-scoped identity.
- [x] Attach only the permissions needed to create and manage this project's EC2/SFTP testbed resources inside the project account.
- [x] Add a post-bootstrap validation step that proves routine commands are using the project-scoped identity, not the admin bootstrap identity.
- [x] Separate bootstrap credentials from routine operator credentials in docs and scripts.
- [x] Document local AWS profile setup without committing real profile names.
- [x] Store only sanitized bootstrap examples in the repo.
- [x] Decide that account bootstrap scripts live under top-level `bootstrap/`.
- [x] Document rollback/cleanup limits for AWS account creation, including operations that cannot be treated as disposable.

Bootstrap decisions baked into implementation:

- Use a dedicated AWS Organizations member account rather than attaching runtime permissions to an existing development account.
- Treat AWS account creation, root-account access, account email ownership, billing setup, and multi-factor authentication as human-owned prerequisites. Bootstrap tooling may guide or inspect this work, and advanced helpers may exist behind explicit approval gates, but routine project tooling should assume the account already exists.
- Use `aws-sftp-server` as the public-safe account name in docs and examples.
- Use IAM Identity Center for routine operator access. Treat direct IAM users or IAM roles as legacy/transitional bootstrap access only unless a reviewed follow-up has a specific reason to use them.
- Use `AwsSftpServer-Operator` as the public-safe permission set name in docs and examples.
- Keep one-time setup helpers and walkthroughs in top-level `bootstrap/`; keep routine SFTP server lifecycle commands in `scripts/`.
- Do not add a read-only role for MVP unless a reviewed follow-up needs it.
- Use phase-level approval gates: inspect, report, then approve a bounded create or assignment phase.

### 3. Routine AWS Access Setup

- [x] Define durable operator identity boundaries for IAM user, role, or IAM Identity Center assignment.
- [x] Draft public-safe IAM permission categories for routine operation.
- [x] Decide whether to include a sanitized IAM policy template after the CloudFormation shape is known.
- [x] Document which routine commands are human-approved AWS actions.
- [x] Confirm routine identity cannot perform account bootstrap after setup is complete.
- [x] Confirm routine identity is scoped to the project AWS account created during bootstrap.

Follow-up requirement: when the CloudFormation template and runtime resource names are implemented, update `docs/operations/aws-access-setup.md` with the final permission set shape and add a sanitized IAM policy template or explain why category-level guidance remains the safer public form.

### 4. CloudFormation Infrastructure

- [x] Replace scaffold template with real CloudFormation resources.
- [x] Use the current Amazon Linux 2023 AMI through SSM public parameters.
- [x] Add configurable stack name, project name, region, instance type, and allowed CIDR parameters.
- [x] Make VPC/subnet selection explicit and associate a public IPv4 address.
- [x] Create security group allowing inbound TCP 22 only from `AllowedCidr`.
- [x] Add explicit public-open override path for temporary `0.0.0.0/0` use.
- [x] Create EC2 instance with minimal EBS volume.
- [x] Add IAM instance profile only if runtime bootstrap needs AWS API access.
- [x] Configure tags on every resource.
- [x] Output instance ID, public DNS/IP, security group ID, and non-sensitive connection metadata.
- [x] Keep Elastic IP, NAT Gateway, load balancer, Transfer Family, and multi-AZ resources out of MVP.

### 5. SFTP Host Bootstrap

- [x] Configure OpenSSH `internal-sftp`.
- [x] Create chroot-safe SFTP directory layout.
- [x] Use `/data` as the MVP remote path.
- [x] Disable shell access for the SFTP user.
- [x] Disable root SSH login.
- [x] Disable forwarding and tunneling.
- [x] Generate random password credentials.
- [x] Decide SSH public-key auth is not part of the first runtime implementation because password auth satisfies the MVP and key material handling should be reviewed separately.
- [x] Emit host key fingerprint without exposing private key material.
- [x] Ensure no generated credential or key material is written into tracked paths.

### 6. Script Command Surface

- [x] Keep command behavior installer-like: each command should perform a bounded AWS setup, inspection, test, stop, or teardown task and then exit.
- [x] Implement `scripts/deploy.sh`.
- [x] Implement `scripts/start.sh`.
- [x] Implement `scripts/stop.sh`.
- [x] Implement `scripts/destroy.sh`.
- [x] Implement `scripts/describe.sh`.
- [x] Implement `scripts/update-parameter.sh`.
- [x] Implement `scripts/smoke-test.sh`.
- [x] Add consistent argument parsing in `scripts/lib/`.
- [x] Add required command checks for `aws`, `ssh`, `sftp`, and other runtime tools.
- [x] Add safe defaults and refusal messages for unsafe inputs.
- [x] Redact sensitive values by default.
- [x] Add `--show-sensitive` only where genuinely useful and clearly labeled.
- [x] Ensure `describe.sh` prints current host, port, username, remote path, host key fingerprint, and stack/resource status without printing secrets.
- [ ] Add bootstrap command surface only after its safety prompts, docs, and dry-run behavior are approved.

### 7. Connection Parameter Publication

- [x] Choose an interim connection parameter JSON schema.
- [x] Promote the connection parameter schema to v1 with `schemaVersion` and `protocol`.
- [x] Create or update a project-owned Parameter Store SecureString parameter.
- [x] Write current host/IP after deploy.
- [x] Refresh current host/IP after start.
- [x] Include `host`, `port`, `username`, `password`, `remotePath`, and host key fingerprint where supported.
- [x] Avoid logging full parameter payloads.
- [x] Document how SimpleETL or another consumer should read the parameter.
- [x] Delete the project-owned Parameter Store parameter by default when destroying runtime infrastructure.
- [x] Add an explicit opt-in path if parameter preservation is ever needed.
- [x] Finalize the MVP schema as v1 while keeping future additive fields reviewable.

### 8. Source CIDR Discovery

- [x] Document that CloudFront is not the source of SFTP traffic.
- [x] Add guidance for determining the outbound source IP/CIDR for the relevant backend execution path.
- [x] Add opt-in SSM diagnostics helpers to temporarily attach, use, and remove source-IP diagnostics without CloudWatch log ingestion.
- [x] Keep Lambda/NAT/EIP assumptions explicit and revisitable.

### 9. Smoke Testing

- [x] Prove SFTP connection succeeds.
- [x] Upload a test file.
- [x] List files in `/data`.
- [x] Download the test file.
- [x] Delete the test file.
- [x] Confirm empty-directory behavior.
- [x] Exercise bad credentials or unreachable host failure path.
- [x] Keep smoke-test artifacts ignored and disposable.

### 10. Lifecycle And Cleanup

- [x] Make destroy the recommended cleanup path.
- [x] Implement stop only for preserving temporary state.
- [x] Print the PRD-required stop warning about EBS and remaining resource costs.
- [x] Ensure destroy deletes all CloudFormation-managed resources.
- [x] Ensure destroy removes the runtime connection parameter by default while preserving durable AWS account access.
- [x] Document how to confirm stack deletion.
- [x] Document expected behavior when restarting after dynamic public IP changes.

### 11. Verification And Documentation

- [x] Add static checks for CloudFormation template shape.
- [x] Add dry-run/static verification for bootstrap scripts that does not create AWS accounts.
- [x] Add shell-script static checks for required safety guards.
- [x] Preserve the stable verification command pattern: public `npm run verify:*` commands should call repo-owned checks with visible gate names.
- [x] Add runtime smoke tests only as human-approved commands outside `verify:safe`.
- [x] Add docs for every implemented command.
- [x] Update architecture diagrams when lifecycle or resource boundaries change.
- [x] Keep `README.md` current with implemented command examples.
- [x] Run `npm run verify:safe` for routine changes.
- [x] Run `npm run verify:scoped structure,public-sanitization,shell-static,cloudformation-static,bootstrap-static,docs` before public pushes.

## Open Decisions

- [x] AWS account creation is a human-owned bootstrap prerequisite. Document the step, account email requirement, billing/root/MFA responsibilities, and optional agent prompt guidance; do not treat full account creation as routine project automation.
- [x] Routine access should use IAM Identity Center: organization, member account, project permission set, account assignment, and local SSO-backed AWS CLI profile. Direct IAM users or IAM roles are bootstrap-only or legacy/transitional access paths, not the preferred routine workflow.
- [x] Bootstrap setup belongs in top-level `bootstrap/` with its own README, scripts, and walkthrough. Routine SFTP server lifecycle commands stay in `scripts/`.
- [x] Final connection parameter JSON schema for MVP: `schemaVersion`, `protocol`, `host`, `publicIp`, `port`, `username`, `password`, `remotePath`, `hostKeyFingerprints`, and `projectName`.
- [x] Consumer secret-store wording: document this generically as a connection secret that should live in a secret store the consumer trusts. This repo publishes to Parameter Store by default; consumers may use Parameter Store, Secrets Manager, another vault, or a controlled local-only development store, but should avoid source-controlled files and casual `.env` workflows for live credentials.
- [x] Host key validation is recommended but not required in MVP. Publish `hostKeyFingerprints`, recommend comparing client prompts when practical, and document Parameter Store-based manual validation as the primary MVP check for host, credentials, and remote path.
- [x] Use one `remotePath` for MVP. Add separate semantic paths such as inbox, archive, or error folders later only if a consuming workflow needs them.
- [x] Consumer file lifecycle is outside this tool's MVP contract. The default SFTP account supports read, write, and delete access; consumers decide whether to delete, archive, move, or preserve remote files.
- [x] Archive or processed-file movement is consumer-owned behavior. Add dedicated paths or stricter test fixtures later only if a consuming workflow needs them.
- [x] Password authentication is the MVP default. SSH public-key authentication is a future enhancement because it is common for SFTP, but key generation, storage, publication, rotation, and cleanup should be designed explicitly before implementation.
- [x] Assume the SFTP client has a stable or known outbound source CIDR for MVP. Operators provide `AllowedCidr`; dynamic egress discovery is optional troubleshooting, not a normal deploy feature.

## Explicit Non-Goals

- No UI.
- No managed AWS Transfer Family server.
- No production-grade SFTP service.
- No high availability.
- No multi-AZ redundancy.
- No long-term file retention.
- No vendor-specific SFTP quirks in MVP.
- No permanent public endpoint.
- No dependency on SimpleETL internals beyond the connection parameter schema and expected directory behavior.

## Future Enhancements

Durable version planning now lives in `docs/specs/sftp-testbed-version-spec.md`. The list below is retained as the original MVP proposal backlog; promote future work through the spec and a reviewed proposal before implementation.

- [ ] Scheduled start/test/stop workflow.
- [ ] GitHub Actions workflow.
- [ ] EventBridge-based auto-shutdown.
- [ ] Multiple test users.
- [ ] Read-only user.
- [ ] Upload-only user.
- [ ] Permission-denied fixtures.
- [ ] Large-file fixture.
- [ ] Many-small-files fixture.
- [ ] Host key rotation test.
- [ ] Credential rotation test.
- [ ] S3-backed fixture file seeding.
- [ ] Private VPC-only mode.
- [ ] Terraform alternative.
- [ ] CDK alternative.

## Closeout Criteria

The MVP is complete when:

- [ ] High-privilege bootstrap docs/scripts can guide creation of the project account and operator identity from the CLI with explicit human approval gates.
- [ ] The testbed can be deployed from the command line.
- [ ] The security group allows only the intended SFTP source CIDR unless explicit temporary public-open override is used.
- [ ] Parameter Store contains current host/IP and credentials after deploy/start.
- [x] A smoke test proves connect, upload, list, download, delete, and empty-directory behavior.
- [ ] Destroy tears down all runtime resources.
- [ ] Destroy removes the runtime connection parameter and tears down all CloudFormation-managed resources.
- [ ] Documentation describes setup, use, cost posture, safety defaults, and cleanup.
- [x] Public sanitization and sandbox-safe verification pass.
