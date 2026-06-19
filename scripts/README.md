# Scripts

This directory owns routine public command-line entrypoints for the SFTP testbed.

One-time AWS account and IAM Identity Center setup lives in `bootstrap/`. Keep that setup phase isolated from routine deploy, inspect, smoke-test, stop, and destroy commands.

Planned commands:

- `login.sh`: sign in to the configured IAM Identity Center profile for routine operation
- `validate-routine-access.sh`: confirm the routine IAM Identity Center profile is active and lacks AWS Organizations bootstrap authority
- `deploy.sh`: deploy or update the CloudFormation stack after validating safety inputs
- `start.sh`: start an existing stopped testbed and refresh current connection details
- `stop.sh`: stop the EC2 instance while warning about remaining storage and resource charges
- `destroy.sh`: delete the CloudFormation stack
- `describe.sh`: print non-sensitive current stack and endpoint details
- `update-parameter.sh`: write current connection details to SSM Parameter Store
- `read-parameter.sh`: read current connection details from SSM Parameter Store
- `enable-diagnostics.sh`: temporarily attach the SSM diagnostics helper to an existing stack
- `diagnose-source-ip.sh`: read recent `sshd` source IPs through SSM Run Command when diagnostics are enabled
- `disable-diagnostics.sh`: remove the SSM diagnostics helper after diagnosis
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
- `read-parameter.sh`: reads the project-owned SSM Parameter Store SecureString connection parameter with decryption, redacting the password unless `--show-sensitive` is passed.
- `enable-diagnostics.sh`: updates an existing stack to attach the project-scoped SSM diagnostics instance profile.
- `diagnose-source-ip.sh`: queries recent `sshd` journal entries through SSM Run Command to identify the source IP the server saw for SFTP attempts.
- `disable-diagnostics.sh`: updates an existing stack to remove the project-scoped SSM diagnostics instance profile.
- `smoke-test.sh`: uses `sshpass`, `sftp`, and `ssh-keyscan` to prove connect, upload, list, download, delete, and post-delete list behavior.

Common deploy form:

```text
npm run deploy -- <source-cidr>
npm run describe
npm run stop
npm run start
npm run update:parameter
npm run read:parameter
npm run diagnostics:enable
npm run diagnose:source-ip
npm run diagnostics:disable
npm run smoke:test
npm run destroy
```

Bootstrap commands must stay outside this directory so the routine command surface does not blur into management-account setup.
