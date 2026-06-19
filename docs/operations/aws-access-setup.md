# AWS Access Setup

Date: 2026-06-16

This project should use durable, project-scoped AWS access for disposable infrastructure. It may also include a separate high-privilege bootstrap lane for creating or configuring that project-scoped AWS access from the AWS CLI.

The structure matters because account setup and SFTP runtime setup have different risk profiles. Creating an AWS account, identity, and permission set is durable administrative work. Starting an EC2 SFTP testbed is routine runtime work. The tooling should make that distinction hard to miss.

The AWS account, IAM Identity Center assignment, local AWS profile, and related access setup can remain available for future testbed use. The SFTP EC2 instance and CloudFormation-managed runtime resources should be temporary and destroyed when testing is complete.

## Bootstrap Vs Routine Operation

Bootstrap uses elevated access by design. It may require management-account or administrator credentials to inspect AWS Organizations, confirm the project account, or configure an identity, role, permission set, or policy. Creating the AWS account itself is a human-owned prerequisite because account email ownership, root-account access, billing posture, and multi-factor authentication cannot be safely treated as routine automation. Bootstrap commands must be explicit, human-approved, and dry-run documented before they perform live AWS changes.

Routine operation should use narrower project-scoped access that can deploy, start, stop, describe, smoke-test, update connection parameters for, and destroy this project's SFTP runtime resources without retaining account-creation authority.

This is the ratchet: use elevated access to create the safer operating lane, then use the safer operating lane for the work the project exists to do.

The approved privilege sequence is:

1. Use admin/management-account AWS CLI access for bootstrap only.
1. Create or confirm the project AWS account as a human-owned setup step.
1. Create the project-scoped IAM Identity Center permission set and account assignment.
1. Validate that the new project-scoped access works inside the project account.
1. Switch routine commands to the project-scoped profile or role.
1. Use the project-scoped access for EC2, CloudFormation, Systems Manager Parameter Store, and SFTP smoke-test operations.
1. Keep admin access out of normal deploy, start, stop, destroy, describe, and smoke-test commands.

## Access Model

Use IAM Identity Center as the preferred routine access model for this project. The expected shape is an AWS Organization with a dedicated member account, a project-scoped permission set, and an account assignment that lets the operator sign in to the project account through one central AWS access portal.

Use a dedicated project assignment instead of sharing broader personal, SimpleETL, or Bonecutters deployment credentials.

The permission set should be scoped to:

- deploy, update, describe, and delete this project's CloudFormation stack
- create, tag, describe, start, stop, and terminate only this project's EC2 resources
- manage the project security group ingress and egress rules needed for the runtime stack
- create or update the project-owned Parameter Store connection parameter
- pass only the IAM role required by the EC2 instance profile
- read the SSM public AMI parameter for Amazon Linux 2023

The routine assignment should not have broad administrator access after setup. If bootstrap work needs elevated permissions, keep that separate from the normal testbed operator identity.

## Existing Access Context

Some environments may have a pre-existing management-account IAM user or role for administrative bootstrap tasks. Treat that as legacy or transitional bootstrap access, not the preferred routine model. It is acceptable for bootstrap only, as long as the boundary stays explicit:

- the management-account IAM principal is used to create or configure the project account and Identity Center assignment
- the routine SFTP server work switches to the IAM Identity Center identity assigned to the project account
- normal deploy, start, stop, destroy, describe, parameter-update, and smoke-test commands do not use the management-account bootstrap principal

An operator may have both an IAM principal and an IAM Identity Center identity. Treat those as separate access paths even when they represent the same person or team. Routine project commands should use the IAM Identity Center profile.

Local AWS profile names are private operator configuration. To rediscover them on a workstation, use:

```text
aws configure list-profiles
```

Then run bootstrap inspection with the local management/admin profile selected explicitly. Do not commit real profile names or command output.

## Durable Vs Disposable

Durable:

- AWS account or client relationship
- bootstrap documentation and scripts, when approved
- project-scoped IAM Identity Center permission set or account assignment
- legacy IAM user or role used only for approved bootstrap access, if an environment already depends on one
- local AWS profile name kept outside source control
- project permissions policy
- optional project-owned connection parameter name

Disposable:

- EC2 instance
- EBS volume
- public IPv4/DNS assignment
- security group rules created for a specific run
- generated SFTP credentials
- smoke-test files

## Bootstrap Rollback And Cleanup Limits

AWS account bootstrap is not disposable in the same way the SFTP runtime stack is disposable. Treat account creation, IAM Identity Center configuration, and local access setup as durable administrative work.

Rollback limits:

- AWS Organizations member accounts should not be treated as throwaway resources. Closing an AWS account is a separate administrative process, may have billing and access consequences, and may not be reversible after AWS-defined grace periods.
- Account creation cannot be undone by deleting a CloudFormation stack. Runtime `destroy` commands must not attempt to close or remove the project AWS account.
- IAM Identity Center permission sets and account assignments can be changed or removed, but doing so affects operator access for future runs.
- The Organizations-created cross-account role can be changed or removed inside the member account, but removing it may make later bootstrap repair harder.
- Local AWS CLI profiles and SSO cached sessions are machine-local configuration. They can be removed from a workstation without changing AWS account state.
- Billing, account email ownership, support-plan state, tax settings, and organization membership are account-level concerns and require explicit administrative review.

Preferred cleanup posture:

- Use runtime `destroy` commands for EC2, EBS, security group, generated credential, and stack cleanup.
- Preserve the dedicated project account and IAM Identity Center assignment for future testbed runs unless an explicit administrative decommission is approved.
- If the project account must be decommissioned, document and approve that as a separate account-closure workflow outside routine testbed teardown.

## Public Repository Boundary

Do not commit:

- AWS account IDs
- IAM user names that reveal private account structure
- ARNs
- local AWS profile names
- access keys
- account-creation request output
- policy documents copied from a live account without sanitization
- generated stack output

Committed docs may describe required permission categories with placeholders. Real names and identifiers belong in local notes, `.local/`, environment variables, or AWS itself.

## Setup Notes

The first implementation pass should add a public-safe IAM policy template or checklist only after the CloudFormation template shape is known. Bootstrap implementation should remain separate from routine runtime scripts, and it should never hide account creation behind a normal deploy command.

## Bootstrap Workflow

The preferred bootstrap model for this repository is:

1. Use management-account access only for the bootstrap lane.
1. Create or confirm a dedicated AWS Organizations member account for this project so billing, ownership, and resource risk stay separate from other development projects. Treat account creation, root access, billing setup, and multi-factor authentication as human-owned prerequisites.
1. Use a public-safe account name such as `aws-sftp-server` when documenting the workflow.
1. Create or update a public-safe IAM Identity Center permission set such as `AwsSftpServer-Operator`.
1. Assign that permission set to the existing operator identity for the project account.
1. Validate routine access through the assigned identity before creating EC2, Parameter Store, or network resources.

The dedicated account is intentional. This testbed simulates an external SFTP server owned outside the consuming application, so it should not be attached to a larger development environment. The separation also keeps billing clearer and prevents EC2 create/destroy permissions from becoming part of unrelated project accounts.

Routine access should use IAM Identity Center assignment to the existing project operator identity. The MVP does not need a separate read-only role because the project account exists primarily to create, inspect, stop, destroy, and rebuild short-lived SFTP servers. If a future hosted-service use case needs operational separation, add that as a reviewed follow-up.

Bootstrap commands should run in phases:

- inspect current AWS and IAM Identity Center state
- report what exists now
- request human approval for the next create or assignment phase
- run the approved phase as a bounded sequence
- report enough state for review without writing live identifiers into the repository

Human approval should happen at clear phase boundaries, not for every individual AWS API call inside an approved phase. For example, the inspect phase can be approved once, then the script reports current state. A later create phase should print the account, permission set, assignment, and validation work it intends to perform, then ask for one explicit approval before running that bounded sequence.

The first implemented bootstrap command is `bootstrap/scripts/inspect.sh`. It is read-only, contacts AWS, and refuses to run unless the caller passes `--bootstrap`.

The public setup path treats account creation as a human-owned step. The account needs a unique email address, working account ownership, billing visibility, root-account recovery access, and multi-factor authentication. A monitored forwarding address or alias is acceptable for the account email if it reliably reaches the responsible owner.

The optional account creation helper is `bootstrap/scripts/create-account.sh`. It is for advanced operators who have already reviewed the account-creation implications and want a gated CLI aid for creating the dedicated AWS Organizations member account. It defaults the account name to `aws-sftp-server`, defaults the Organizations access role name to `OrganizationAccountAccessRole`, polls the asynchronous account creation request, and refuses to run unless the caller passes both `--bootstrap` and `--approve-create-account`. It does not replace the human responsibility to complete root-account, email, billing, and MFA setup.

AWS Organizations creates the named cross-account access role in the new member account during account creation. Bootstrap uses that role only to complete account setup and validate the lower-privilege operating lane. Routine testbed commands should use the project-scoped IAM Identity Center assignment instead.

The permission set command is `bootstrap/scripts/ensure-permission-set.sh`. It creates or updates the public-safe `AwsSftpServer-Operator` permission set and installs an inline policy for routine CloudFormation, EC2, SSM public AMI parameter reads, project connection parameter writes, and caller-identity operations needed by this project. It refuses to run unless the caller passes both `--bootstrap` and `--approve-permission-set`.

The assignment command is `bootstrap/scripts/assign-permission-set.sh`. It assigns the project permission set to the operator IAM Identity Center user for the project account and polls the asynchronous assignment request. It refuses to run unless the caller passes both `--bootstrap` and `--approve-assignment`.

The routine login command is `scripts/login.sh`. It signs in the local AWS CLI profile for routine operation through IAM Identity Center, verifies that the profile is configured for the expected project permission set, and prints the resulting caller identity for review. It defaults to `aws-sftp-server-operator`, or the `AWS_SFTP_SERVER_PROFILE` environment variable when set. It does not create AWS resources.

The routine validation command is `scripts/validate-routine-access.sh`. It confirms the routine profile caller identity and checks that AWS Organizations bootstrap access is denied.

The local profile setup command is `bootstrap/scripts/configure-routine-profile.sh`. It writes the routine AWS CLI profile using the project account discovered from AWS Organizations, the project permission set name, and an existing local AWS CLI SSO session. When a bootstrap profile is not provided, it discovers a signed-in local profile with AWS Organizations access. It writes only local AWS configuration and refuses to run unless the caller passes both `--bootstrap` and `--approve-local-profile`.

## Permission Guidance

The bootstrap workflow creates the `AwsSftpServer-Operator` permission set with the permission categories needed for routine operation. Public documentation should describe those categories so another operator can reproduce the access model safely.

Routine operator permissions should include only:

- CloudFormation actions needed to create, update, inspect, and delete this project's stack
- EC2 actions needed to create, tag, inspect, read console output for bootstrap diagnostics, reboot, start, stop, and terminate this project's runtime resources
- security group actions needed for the explicit SFTP ingress boundary and CloudFormation-managed egress rule
- SSM public parameter reads for the Amazon Linux 2023 AMI
- SSM Parameter Store actions needed to create, read, update, and optionally delete the project-owned connection parameter
- Parameter Store console discovery actions needed to list parameters, with value access still scoped to the project-owned connection path
- SSM Run Command permissions for optional source-IP diagnostics when the stack is deployed with SSM diagnostics enabled
- IAM role and instance-profile permissions limited to the project-scoped SSM diagnostics instance profile
- caller identity and account metadata reads needed for validation and diagnostics

The current CloudFormation runtime shape does not require an EC2 instance profile because instance bootstrap does not call AWS APIs. If a future runtime change adds an instance profile, add IAM role, instance profile, and pass-role permissions only for project-prefixed resources and document why they are needed.

Routine operator permissions should not include:

- AWS Organizations account creation or management
- IAM Identity Center administration
- broad administrator access
- access to unrelated project accounts
- permission to close AWS accounts
- permission to manage Parameter Store values outside this project's connection-parameter path

A committed sanitized IAM policy template should be added only after the CloudFormation template and runtime resource names are implemented. Until then, keep the public documentation at the permission-category level and keep any live policy output out of source control.

Connection details are published by this tool to Systems Manager Parameter Store as a `SecureString` parameter. Consumers may copy or sync the payload into whatever secret store they are comfortable operating, but they should not treat source-controlled files or casual `.env` workflows as safe places for live credentials. Secrets Manager is intentionally not the MVP default because managed rotation is not part of the disposable testbed credential model. Prefer destroy and redeploy for testbed credential rotation unless a future reviewed feature adds managed rotation.

## Setup Guide

This is the public-safe shape for setting up the access model from a management account.

Before starting:

- Sign in locally with management-account access that can use AWS Organizations and IAM Identity Center.
- Confirm IAM Identity Center is enabled for the organization.
- Confirm the intended operator user exists in IAM Identity Center.
- Create or confirm the dedicated project AWS account as the human account owner. AWS requires a unique email address for each account. A forwarding address or alias that reaches the responsible owner is acceptable if it can receive AWS account mail.
- Complete root-account recovery and multi-factor authentication setup for the dedicated account outside this repository's normal command workflow.
- Keep the real account email, account IDs, IAM Identity Center identifiers, local profile names, and command output out of source control.

Target structure:

```text
AWS Organizations
+-- Management account
    +-- uses management/admin access for bootstrap only
+-- aws-sftp-server account
    +-- IAM Identity Center permission set: AwsSftpServer-Operator
    +-- IAM Identity Center account assignment: operator user -> AwsSftpServer-Operator
    +-- local routine AWS CLI profile: aws-sftp-server-operator
```

Setup steps:

1. Inspect the management account, organization accounts, and IAM Identity Center instance.
1. Create or confirm the dedicated `aws-sftp-server` AWS Organizations member account as a human-owned prerequisite.
1. Create or update the `AwsSftpServer-Operator` IAM Identity Center permission set.
1. Assign `AwsSftpServer-Operator` to the operator user for the `aws-sftp-server` account.
1. Configure the local routine AWS CLI profile.
1. Sign in through IAM Identity Center using the routine profile.
1. Validate that the routine profile is scoped to the project account and cannot use AWS Organizations bootstrap APIs.

Command sequence:

```text
npm run bootstrap:inspect -- --bootstrap --profile <local-admin-profile>
npm run bootstrap:ensure-permission-set -- --bootstrap --approve-permission-set --profile <local-admin-profile>
npm run bootstrap:assign-permission-set -- --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
npm run bootstrap:configure-profile
npm run login
npm run validate:routine-access
```

After setup, routine SFTP testbed commands should use the routine profile path, not the management-account bootstrap path.

Optional account-creation aid for advanced operators who have explicit approval to create the account from AWS Organizations:

```text
npm run bootstrap:create-account -- --bootstrap --approve-create-account --profile <local-admin-profile> --account-email <account-email>
```

Preferred invocation after the dedicated account exists:

```text
npm run bootstrap:inspect -- --bootstrap --profile <local-admin-profile>
npm run bootstrap:ensure-permission-set -- --bootstrap --approve-permission-set --profile <local-admin-profile>
npm run bootstrap:assign-permission-set -- --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
npm run bootstrap:configure-profile
npm run login
npm run validate:routine-access
```

Windows operators can call Git Bash directly if local npm shell resolution chooses a non-working Bash path:

```text
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/inspect.sh --bootstrap --profile <local-admin-profile>
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/ensure-permission-set.sh --bootstrap --approve-permission-set --profile <local-admin-profile>
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/assign-permission-set.sh --bootstrap --approve-assignment --profile <local-admin-profile> --operator-username <operator-username>
& 'C:\Program Files\Git\bin\bash.exe' bootstrap/scripts/configure-routine-profile.sh --bootstrap --approve-local-profile
& 'C:\Program Files\Git\bin\bash.exe' scripts/login.sh
& 'C:\Program Files\Git\bin\bash.exe' scripts/validate-routine-access.sh
```

The profile name, account email, and operator username are local-only context and should not be committed.

Optional agent prompt for account-access bootstrap:

```text
Help me set up aws-sftp-testbed access from a management account. First inspect the current AWS Organizations and IAM Identity Center state and report what exists without making changes. Treat AWS account creation as a human-owned prerequisite: confirm the dedicated project account name, account email ownership, billing visibility, root recovery access, and MFA status. After I explicitly approve, create or update only the project IAM Identity Center permission set and account assignment needed for the routine operator profile. Do not commit account IDs, ARNs, emails, local profile names, credentials, or live command output.
```
