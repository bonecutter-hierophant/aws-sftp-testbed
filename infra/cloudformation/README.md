# CloudFormation

This directory owns the CloudFormation template for the disposable SFTP testbed.

The template should eventually define:

- EC2 instance using the current Amazon Linux 2023 SSM public AMI parameter
- security group with caller-provided inbound SFTP CIDR
- IAM instance profile with only required permissions
- user data for OpenSSH `internal-sftp`
- resource tags that identify the testbed and support cleanup
- outputs needed by scripts to discover current host and update Secrets Manager

Do not commit generated stack outputs or live AWS identifiers.
