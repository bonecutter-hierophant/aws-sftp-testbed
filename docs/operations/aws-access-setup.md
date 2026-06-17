# AWS Access Setup

Date: 2026-06-16

This project should use durable, project-scoped AWS access for disposable infrastructure. It may also include a separate high-privilege bootstrap lane for creating or configuring that project-scoped AWS access from the AWS CLI.

The structure matters because account setup and SFTP runtime setup have different risk profiles. Creating an AWS account, identity, and permission set is durable administrative work. Starting an EC2 SFTP testbed is routine runtime work. The tooling should make that distinction hard to miss.

The AWS account, IAM principal, local AWS profile, and related access setup can remain available for future testbed use. The SFTP EC2 instance and CloudFormation-managed runtime resources should be temporary and destroyed when testing is complete.

## Bootstrap Vs Routine Operation

Bootstrap uses elevated access by design. It may require management-account or administrator credentials to create or configure a new AWS account, identity, role, permission set, or policy. Bootstrap commands must be explicit, human-approved, and dry-run documented before they perform live AWS changes.

Routine operation should use narrower project-scoped access that can deploy, start, stop, describe, smoke-test, update secrets for, and destroy this project's SFTP runtime resources without retaining account-creation authority.

This is the ratchet: use elevated access to create the safer operating lane, then use the safer operating lane for the work the project exists to do.

The approved privilege sequence is:

1. Use admin/management-account AWS CLI access for bootstrap only.
1. Create or configure the project AWS account.
1. Create the project-scoped identity and permission set.
1. Validate that the new project-scoped access works inside the project account.
1. Switch routine commands to the project-scoped profile or role.
1. Use the project-scoped access for EC2, CloudFormation, Secrets Manager, and SFTP smoke-test operations.
1. Keep admin access out of normal deploy, start, stop, destroy, describe, and smoke-test commands.

## Access Model

Use a dedicated AWS identity for this project instead of sharing broader personal, SimpleETL, or Bonecutters deployment credentials.

The identity should be scoped to:

- deploy, update, describe, and delete this project's CloudFormation stack
- create, tag, describe, start, stop, and terminate only this project's EC2 resources
- manage the project security group rules needed for SFTP
- create or update the project-owned Secrets Manager secret
- pass only the IAM role required by the EC2 instance profile
- read the SSM public AMI parameter for Amazon Linux 2023

The identity should not have broad administrator access after setup. If bootstrap work needs elevated permissions, keep that separate from the normal testbed operator identity.

## Durable Vs Disposable

Durable:

- AWS account or client relationship
- bootstrap documentation and scripts, when approved
- project-scoped IAM user or role
- optional IAM Identity Center permission set or account assignment
- local AWS profile name kept outside source control
- project permissions policy
- optional project-owned secret name

Disposable:

- EC2 instance
- EBS volume
- public IPv4/DNS assignment
- security group rules created for a specific run
- generated SFTP credentials
- smoke-test files

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
