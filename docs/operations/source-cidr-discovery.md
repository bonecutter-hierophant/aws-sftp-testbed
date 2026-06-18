# Source CIDR Discovery

Date: 2026-06-18

`AllowedCidr` is the source network that can reach TCP 22 on the disposable SFTP server. It should describe the outbound source of the client that connects to SFTP, not the user sitting at a browser and not the public DNS name of this testbed.

## Key Rule

CloudFront is not the source of SFTP traffic. CloudFront can front HTTP and HTTPS workflows, but it does not proxy SFTP connections to this EC2 testbed.

Choose `AllowedCidr` from the actual SFTP client execution path:

- local developer machine: use the developer machine's current public IP as `/32`
- CI runner: use the CI runner's documented outbound IP range, if stable and trusted
- AWS Lambda in a VPC: use the NAT Gateway Elastic IP as `/32`
- AWS ECS, EC2, or batch worker in a private subnet: use the NAT Gateway Elastic IP as `/32`
- AWS workload with direct public egress and no static IP: add stable egress first, or treat the source as unsuitable for a narrow `AllowedCidr`

## Stable Egress

For backend systems, prefer a stable outbound path:

1. Put the client workload in private subnets.
1. Route outbound internet traffic through a NAT Gateway.
1. Attach an Elastic IP to the NAT Gateway.
1. Use that Elastic IP as `AllowedCidr` with a `/32` suffix.

This project does not create that consumer-side egress path. It only creates the SFTP server side and enforces the caller-provided CIDR.

## Temporary Public Access

`AllowedCidr=0.0.0.0/0` is refused unless the caller explicitly passes the public-open override. Use it only as a temporary troubleshooting step and destroy the runtime stack when finished.

```text
npm run deploy -- 0.0.0.0/0 allow-public-cidr
```

## Future Helper Decision

This repository should document CIDR selection for now rather than provide a generic discovery command. A helper can be added later for narrow cases, such as detecting the current local public IP for developer-only testing, but backend egress discovery needs application-specific context.
