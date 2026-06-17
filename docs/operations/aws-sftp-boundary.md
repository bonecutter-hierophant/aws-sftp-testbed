# AWS SFTP Boundary

Date: 2026-06-16

This repository creates disposable AWS infrastructure for SFTP integration testing. AWS work must stay explicit, reviewable, and safe by default.

Project AWS access can be durable; runtime infrastructure should be disposable. Use `docs/operations/aws-access-setup.md` for IAM user, role, policy, and local profile boundaries.

## MVP Boundary

Use:

- CloudFormation
- AWS CLI wrapper scripts
- EC2
- Amazon Linux 2023
- OpenSSH `internal-sftp`
- AWS Secrets Manager

Do not use by default:

- AWS Transfer Family
- Elastic IP
- NAT Gateway
- load balancer
- long-lived public endpoint
- production-grade high availability

## Required Safety Defaults

- Require `AllowedCidr` for deployment.
- Refuse `0.0.0.0/0` unless an explicit temporary override flag is provided.
- Generate random credentials.
- Never print full secrets unless an explicit sensitive-output flag is passed.
- Disable shell access for the SFTP user.
- Disable root SSH login.
- Disable forwarding and tunneling.
- Use a chrooted SFTP directory.
- Emit the host key fingerprint.
- Tag all resources.
- Provide a destroy command.
- Document cost and cleanup behavior clearly.

## Cost Posture

Optimize for disposable, low-cost use, but do not promise that the testbed is free. Avoid static IPv4 resources unless explicitly requested. Prefer full stack deletion when testing is complete.

The stop flow should warn:

```text
Instance stopped. EC2 instance usage charges should stop, but attached EBS volumes and some other resources may still incur charges. Use destroy.sh for full teardown.
```

## Human Approval Boundary

Commands that contact AWS, create resources, change security groups, write secrets, or destroy infrastructure should remain human-approved. Sandbox-safe verification must not contact AWS.
