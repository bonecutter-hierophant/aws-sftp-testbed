# AWS SFTP Boundary

Date: 2026-06-16

This repository creates disposable AWS infrastructure for SFTP integration testing. AWS work must stay explicit, reviewable, and safe by default.

Project AWS access can be durable; runtime infrastructure should be disposable. Use `docs/operations/aws-access-setup.md` for IAM user, role, policy, and local profile boundaries.

The repository itself is not intended to run a persistent service. It owns command-line tooling that installs, inspects, tests, stops, and uninstalls AWS-hosted SFTP infrastructure.

## MVP Boundary

Use:

- CloudFormation
- AWS CLI wrapper scripts
- EC2
- Amazon Linux 2023
- OpenSSH `internal-sftp`
- AWS Systems Manager Parameter Store

## Connection Detail Publication

The MVP publishes current SFTP connection details to AWS Systems Manager Parameter Store as a `SecureString` parameter. Parameter Store standard parameters fit this disposable testbed because the project rotates credentials by redeploying the runtime stack rather than maintaining long-lived rotated secrets.

Consumers should treat the published payload as a secret and store it wherever their project normally stores sensitive connection details. That may be Parameter Store, AWS Secrets Manager, another managed vault, or a local-only development store with clear handling rules. Avoid source-controlled files and casual `.env` workflows for live credentials; they are easy to leak through logs, screenshots, cloud tooling, and agent-assisted development.

AWS Secrets Manager remains a future option if managed credential rotation becomes a requirement, but it is not the default for MVP connection publication because this testbed should avoid durable paid secret resources when a short-lived encrypted parameter is sufficient.

Parameter Store names must not start with provider-reserved prefixes such as `aws` or `ssm`. Put the project or domain namespace first. The default connection parameter path is `/sftp-testbed/aws-sftp-server/connection`, not `/aws-sftp-server/connection`.

Use this naming convention for new AWS-owned names and paths where provider-reserved prefixes might apply: start with a neutral project namespace such as `sftp-testbed`, then add the specific resource or account label.

## Manual Endpoint Validation

For MVP manual testing, fetch the connection payload directly from Parameter Store using authenticated project access, then use those values from the machine that will run the SFTP client. This proves the test is using the connection details the tool published rather than copied local notes.

Validate:

- the server answers at the published `host` or `publicIp`
- TCP port `22` is reachable from the client source network
- the published `username` and `password` authenticate successfully
- the published `remotePath` is visible and writable as expected
- bad usernames or passwords fail

The payload includes `hostKeyFingerprints` so clients can compare the SSH host key prompt when practical. This is recommended for MVP but not mandatory. The value is discovered through the testbed tooling and should be treated as testbed trust-on-first-use, not a production certificate chain. Destroying and rebuilding the server creates new host keys; stopping and starting the same instance should preserve them.

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
