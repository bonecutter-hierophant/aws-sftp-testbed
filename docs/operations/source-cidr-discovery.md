# Source CIDR Discovery

Date: 2026-06-18

`AllowedCidr` is the source network that can reach TCP 22 on the disposable SFTP server. It should describe the outbound source of the client that connects to SFTP, not the user sitting at a browser and not the public DNS name of this testbed.

## Key Rule

CloudFront is not the source of SFTP traffic. CloudFront can front HTTP and HTTPS workflows, but it does not proxy SFTP connections to this EC2 testbed.

The MVP assumes the operator can provide a stable or known source CIDR for the actual SFTP client execution path. Choose `AllowedCidr` from that path:

- local developer machine: use the developer machine's current public IP as `/32`
- CI runner: use the CI runner's documented outbound IP range, if stable and trusted
- AWS Lambda in a VPC: use the NAT Gateway Elastic IP as `/32`
- AWS ECS, EC2, or batch worker in a private subnet: use the NAT Gateway Elastic IP as `/32`
- AWS workload with direct public egress and no static IP: add stable egress first, or treat the source as unsuitable for a narrow `AllowedCidr`

## First Diagnostic Check

When SFTP times out, verify the source IP before adding diagnostic infrastructure:

1. Run an IP check from the same machine and network that will run the SFTP client.
1. Copy the value directly where possible.
1. Compare the deployed `AllowedCidr` and the observed IP character by character.
1. Check for transposed digits before widening access.

Most timeout failures should be handled here. If the IP was mistyped, fix the security group or redeploy with the corrected `/32`.

## Stable Egress

For backend systems, prefer a stable outbound path:

1. Put the client workload in private subnets.
1. Route outbound internet traffic through a NAT Gateway.
1. Attach an Elastic IP to the NAT Gateway.
1. Use that Elastic IP as `AllowedCidr` with a `/32` suffix.

This project does not create that consumer-side egress path and does not try to discover dynamic egress during normal deploy. It only creates the SFTP server side and enforces the caller-provided CIDR.

## Temporary Public Access

`AllowedCidr=0.0.0.0/0` is refused unless the caller explicitly passes the public-open override. Use it only as a temporary troubleshooting step and destroy the runtime stack when finished.

```text
npm run deploy -- 0.0.0.0/0 allow-public-cidr
```

## Diagnostic Helper

Use the SSM diagnostics helper only when the simple IP check does not explain the timeout, such as when a network appears to route SFTP differently from browser traffic:

```text
npm run diagnostics:enable
npm run diagnose:source-ip
npm run diagnostics:disable
```

This helper temporarily attaches a project-scoped SSM instance profile, asks the instance for recent `sshd` journal entries through SSM Run Command, and reports the source IP the server saw. It does not enable CloudWatch log ingestion. After identifying the source, replace temporary public access with the observed `/32` rule or destroy the runtime stack.

This is intentionally a last-resort diagnostic workflow, not normal egress discovery, not a separate server type, and not a permanent exposure model.
