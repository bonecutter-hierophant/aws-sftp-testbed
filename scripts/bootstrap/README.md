# Bootstrap Scripts

This directory owns the high-privilege AWS bootstrap command surface.

Bootstrap is separate from routine SFTP testbed operation. It may use management-account or administrator access to inspect AWS Organizations and IAM Identity Center, create or select the project AWS account, create a project-scoped permission set, and assign that permission set to the operator identity.

Public-safe defaults:

- use a dedicated AWS Organizations member account for this project
- use public-safe names such as `aws-sftp-server` and `AwsSftpServer-Operator`
- use IAM Identity Center for the routine operator assignment
- keep the SFTP server account separate from consuming application accounts so it can simulate an external client-owned server and expose separate billing
- avoid adding EC2 create/destroy permissions to unrelated project accounts
- inspect first, then require a human approval gate before create or assign operations
- approve whole bounded phases after review, not every individual AWS API call inside an approved phase
- keep real account IDs, account emails, IAM Identity Center ARNs, identity store IDs, profile names, and command output out of source control

Implemented commands:

- `inspect.sh`: read-only bootstrap discovery for the current AWS caller, AWS Organizations, and IAM Identity Center
- `create-account.sh`: human-approved AWS Organizations member account creation with status polling
- `ensure-permission-set.sh`: human-approved IAM Identity Center permission set creation or update
- `assign-permission-set.sh`: human-approved IAM Identity Center user assignment for the project account
- `configure-routine-profile.sh`: human-approved local AWS CLI profile setup for routine operation

Run through npm:

```text
npm run bootstrap:inspect -- --bootstrap --profile <local-admin-profile>
npm run bootstrap:create-account -- --bootstrap --approve-create-account --profile <local-admin-profile> --account-email <account-email>
npm run bootstrap:ensure-permission-set -- --bootstrap --approve-permission-set --profile <local-admin-profile>
npm run bootstrap:assign-permission-set -- --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
npm run bootstrap:configure-profile
```

On Windows, if npm resolves Bash through a local shell path that cannot launch, run the script directly through Git Bash:

```text
& 'C:\Program Files\Git\bin\bash.exe' scripts/bootstrap/inspect.sh --bootstrap --profile <local-admin-profile>
& 'C:\Program Files\Git\bin\bash.exe' scripts/bootstrap/create-account.sh --bootstrap --approve-create-account --profile <local-admin-profile> --account-email <account-email>
& 'C:\Program Files\Git\bin\bash.exe' scripts/bootstrap/ensure-permission-set.sh --bootstrap --approve-permission-set --profile <local-admin-profile>
& 'C:\Program Files\Git\bin\bash.exe' scripts/bootstrap/assign-permission-set.sh --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
& 'C:\Program Files\Git\bin\bash.exe' scripts/bootstrap/configure-routine-profile.sh --bootstrap --approve-local-profile
```

The profile name is local-only context. Do not commit it to documentation or examples.

Planned commands:

- routine-access validation

Bootstrap commands must not be called from deploy, start, stop, destroy, describe, or smoke-test commands.
