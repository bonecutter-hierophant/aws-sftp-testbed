# Bootstrap Walkthrough

This walkthrough describes the one-time setup phase that makes an AWS account ready to use `aws-sftp-testbed`.

Bootstrap is intentionally separate from routine testbed operation. It may inspect AWS Organizations and IAM Identity Center, confirm the dedicated project account, create or update the project permission set, assign that permission set to an operator, and configure a local AWS CLI SSO profile.

After bootstrap, routine commands in `scripts/` should be used for deploy, describe, start, stop, smoke test, diagnostics, parameter publication, and destroy.

## Phase 1: Human Account Setup

Before running project bootstrap commands, a human account owner should:

- have an AWS account that can use AWS Organizations and IAM Identity Center
- create or confirm the dedicated project member account
- control the project account email address
- complete root-account recovery and multi-factor authentication setup
- confirm billing visibility for the account
- confirm the intended operator user exists in IAM Identity Center

AWS requires a unique email address for each account. A monitored forwarding address or alias is acceptable if it receives AWS account mail.

## Phase 2: Bootstrap Inspection

Inspect first. This phase is read-only but may print private account identifiers to the terminal, so do not commit the output.

```text
npm run bootstrap:inspect -- --bootstrap --profile <local-admin-profile>
```

Review:

- current caller
- organization visibility
- existing accounts
- IAM Identity Center instance visibility
- existing permission sets and users relevant to the project

## Phase 3: Optional Account Creation Aid

The public workflow treats account creation as human-owned. Advanced operators with explicit approval may use the account creation helper:

```text
npm run bootstrap:create-account -- --bootstrap --approve-create-account --profile <local-admin-profile> --account-email <account-email>
```

This helper does not replace root-account recovery, email ownership, billing review, or MFA setup.

## Phase 4: IAM Identity Center Access

Create or update the project permission set:

```text
npm run bootstrap:ensure-permission-set -- --bootstrap --approve-permission-set --profile <local-admin-profile>
```

Assign it to the project operator user:

```text
npm run bootstrap:assign-permission-set -- --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
```

Configure the local routine AWS CLI profile:

```text
npm run bootstrap:configure-profile
```

## Phase 5: Routine Validation

Sign in with the routine profile and prove it can operate only inside the project account:

```text
npm run login
npm run validate:routine-access
```

Routine deploy/start/stop/destroy commands should use the IAM Identity Center profile, not the management-account bootstrap profile.

## Public Repository Hygiene

Do not commit account emails, account IDs, ARNs, IAM Identity Center identifiers, local profile names, generated AWS CLI output, credentials, or screenshots of live account state.
