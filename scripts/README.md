# Scripts

This directory owns public command-line entrypoints for the SFTP testbed.

Planned commands:

- `login.sh`: sign in to the configured IAM Identity Center profile for routine operation
- `validate-routine-access.sh`: confirm the routine IAM Identity Center profile is active and lacks AWS Organizations bootstrap authority
- `deploy.sh`: deploy or update the CloudFormation stack after validating safety inputs
- `start.sh`: start an existing stopped testbed and refresh current connection details
- `stop.sh`: stop the EC2 instance while warning about remaining storage and resource charges
- `destroy.sh`: delete the CloudFormation stack
- `describe.sh`: print non-sensitive current stack and endpoint details
- `update-parameter.sh`: write current connection details to SSM Parameter Store
- `smoke-test.sh`: prove SFTP connect, upload, list, download, and delete behavior

Shared helpers live in `scripts/lib/`.

Scripts should refuse unsafe defaults and avoid printing sensitive values unless an explicit sensitive-output flag is provided.

Implemented routine commands:

- `login.sh`: runs `aws sso login` for the routine operator profile, verifies the profile is configured for the expected project permission set, and prints the resulting caller identity for review. It defaults to `aws-sftp-server-operator` or `AWS_SFTP_SERVER_PROFILE`. Local account IDs must not be committed.
- `validate-routine-access.sh`: confirms caller identity for the routine profile and verifies AWS Organizations bootstrap access is denied.
- `deploy.sh`: validates CIDR safety inputs, discovers or accepts the target VPC/subnet, generates disposable local SFTP credentials, deploys the CloudFormation stack, refreshes the SSM Parameter Store connection parameter, and prints non-sensitive stack outputs. Generated credentials are written under `.local/`.
- `describe.sh`: prints non-sensitive stack, endpoint, and SFTP metadata and attempts host key fingerprint discovery without printing credentials.
- `start.sh`: starts an existing stopped EC2 instance, refreshes the SSM Parameter Store connection parameter, and warns that public endpoint values may change.
- `stop.sh`: stops EC2 compute while warning that attached storage and other resources may still incur charges.
- `destroy.sh`: deletes the CloudFormation-managed runtime stack and removes the project-owned connection parameter by default, while preserving durable account access. Direct script callers can pass `--keep-parameter` for explicit debugging or handoff cases.
- `update-parameter.sh`: creates or updates the project-owned SSM Parameter Store SecureString connection parameter from current stack outputs and local generated credentials.
- `smoke-test.sh`: uses `sshpass`, `sftp`, and `ssh-keyscan` to prove connect, upload, list, download, delete, and post-delete list behavior.

Common deploy form:

```text
npm run deploy -- <source-cidr>
npm run describe
npm run stop
npm run start
npm run update:parameter
npm run smoke:test
npm run destroy
```

Bootstrap commands live in `scripts/bootstrap/`. They are intentionally separate from routine testbed commands because they may use management-account access to inspect or configure AWS Organizations and IAM Identity Center.

Implemented bootstrap commands:

- `bootstrap/inspect.sh`: read-only discovery for the current AWS caller, AWS Organizations accounts, and IAM Identity Center instances. Requires `--bootstrap`.
