#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const templatePath = join(repoRoot, "infra/cloudformation/template.yaml");
const template = readFileSync(templatePath, "utf8");
const failures = [];

requireText("Rules:", "template must define CloudFormation rules");
requireText("PublicCidrRequiresOverride:", "template must gate public CIDR use");
requireText("AllowPublicCidr", "template must expose explicit public CIDR override");
requireText("0.0.0.0/0", "template must explicitly account for public CIDR");
requireText("FromPort: 22", "security group must allow SFTP port 22");
requireText("ToPort: 22", "security group must allow SFTP port 22");
requireText("CidrIp: !Ref AllowedCidr", "security group ingress must use AllowedCidr");
requireText("AssociatePublicIpAddress: true", "instance network interface must explicitly associate a public IP");
requireText("HttpTokens: required", "instance metadata options must require IMDSv2");
requireText("Encrypted: true", "root EBS volume must be encrypted");
requireText("DeleteOnTermination: true", "root EBS volume must be deleted on termination");
requireText("ForceCommand internal-sftp -d /data", "SFTP user must be forced into internal-sftp");
requireText("ChrootDirectory /sftp", "SFTP user must be chrooted");
requireText("PermitRootLogin no", "root SSH login must be disabled");
requireText("AllowTcpForwarding no", "SFTP user TCP forwarding must be disabled");
requireText("X11Forwarding no", "SFTP user X11 forwarding must be disabled");
requireText("PermitTunnel no", "SFTP user tunneling must be disabled");
requireText("EnableSsmDiagnostics", "template must expose opt-in diagnostics flag");
requireText("AWS::NoValue", "diagnostics instance profile must be removable from normal operation");

forbidText("AWS::EC2::EIP", "MVP must not allocate Elastic IPs");
forbidText("AWS::ElasticLoadBalancing", "MVP must not create load balancers");
forbidText("AWS::Transfer", "MVP must not create AWS Transfer Family resources");

if (failures.length > 0) {
  console.error("CloudFormation static check failed:");
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
}

function requireText(needle, message) {
  if (!template.includes(needle)) {
    failures.push(message);
  }
}

function forbidText(needle, message) {
  if (template.includes(needle)) {
    failures.push(message);
  }
}
