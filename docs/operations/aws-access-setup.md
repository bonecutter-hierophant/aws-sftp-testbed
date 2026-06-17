# AWS Access Setup

Date: 2026-06-16

This project should use durable, project-scoped AWS access for disposable infrastructure.

The AWS account, IAM principal, local AWS profile, and related access setup can remain available for future testbed use. The SFTP EC2 instance and CloudFormation-managed runtime resources should be temporary and destroyed when testing is complete.

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
- project-scoped IAM user or role
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
- policy documents copied from a live account without sanitization
- generated stack output

Committed docs may describe required permission categories with placeholders. Real names and identifiers belong in local notes, `.local/`, environment variables, or AWS itself.

## Setup Notes

The first implementation pass should add a public-safe IAM policy template or checklist only after the CloudFormation template shape is known. Until then, this document records the intended boundary: persistent project access, disposable runtime infrastructure.
