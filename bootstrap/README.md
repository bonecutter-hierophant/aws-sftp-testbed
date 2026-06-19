# Bootstrap

This directory owns the high-privilege AWS bootstrap setup phase.

Bootstrap is separate from routine SFTP testbed operation. It may use management-account or administrator access to inspect AWS Organizations and IAM Identity Center, confirm the project AWS account, create a project-scoped permission set, and assign that permission set to the operator identity.

Use `bootstrap/walkthrough.md` for the step-by-step setup flow. Use `scripts/` for normal deploy, inspect, smoke-test, stop, and destroy operations after setup is complete.

The public setup path treats AWS account creation as a human-owned prerequisite. The account owner must control the account email, billing posture, root-account recovery path, and multi-factor authentication. The optional account creation helper is available for advanced operators with explicit approval, but it does not replace those human-owned account setup responsibilities.

Public-safe defaults:

- use a dedicated AWS Organizations member account for this project
- create or confirm that account through a human-owned setup step before routine project operation
- use public-safe names such as `aws-sftp-server` and `AwsSftpServer-Operator`
- use IAM Identity Center for the routine operator assignment
- keep the SFTP server account separate from consuming application accounts so it can simulate an external client-owned server and expose separate billing
- avoid adding EC2 create/destroy permissions to unrelated project accounts
- inspect first, then require a human approval gate before create or assign operations
- approve whole bounded phases after review, not every individual AWS API call inside an approved phase
- keep real account IDs, account emails, IAM Identity Center ARNs, identity store IDs, profile names, and command output out of source control

Implemented commands:

- `scripts/inspect.sh`: read-only bootstrap discovery for the current AWS caller, AWS Organizations, and IAM Identity Center
- `scripts/create-account.sh`: optional human-approved AWS Organizations member account creation aid with status polling
- `scripts/ensure-permission-set.sh`: human-approved IAM Identity Center permission set creation or update
- `scripts/assign-permission-set.sh`: human-approved IAM Identity Center user assignment for the project account
- `scripts/configure-routine-profile.sh`: human-approved local AWS CLI profile setup for routine operation

Run through npm:

```text
npm run bootstrap:inspect -- --bootstrap --profile <local-admin-profile>
npm run bootstrap:ensure-permission-set -- --bootstrap --approve-permission-set --profile <local-admin-profile>
npm run bootstrap:assign-permission-set -- --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
npm run bootstrap:configure-profile
```

Optional account-creation aid for advanced operators:

```text
npm run bootstrap:create-account -- --bootstrap --approve-create-account --profile <local-admin-profile> --account-email <account-email>
```

On Windows, if npm resolves Bash through a local shell path that cannot launch, run the script directly through Git Bash:

```text
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/inspect.sh --bootstrap --profile <local-admin-profile>
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/ensure-permission-set.sh --bootstrap --approve-permission-set --profile <local-admin-profile>
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/assign-permission-set.sh --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/configure-routine-profile.sh --bootstrap --approve-local-profile
```

The profile name is local-only context. Do not commit it to documentation or examples.

Planned commands:

- routine-access validation

Bootstrap commands must not be called from deploy, start, stop, destroy, describe, or smoke-test commands.
