# Project Structure

`aws-sftp-testbed` is a public command-line AWS toolkit. It should remain small, scriptable, and safe to inspect.

The repo owns the commands and documentation that affect AWS. The SFTP server runs on disposable AWS infrastructure created by those commands, not as a persistent process inside this repository.

```text
.
+-- bootstrap/
|   +-- scripts/            One-time AWS account and IAM Identity Center setup helpers
+-- docs/
|   +-- architecture/       Repo-level structure and diagrams
|   +-- operations/         Workflow, AWS boundary, and verification docs
|   +-- proposals/          Active implementation proposals and public roadmap checklists
|   +-- specs/              Durable product/version specifications
+-- infra/
|   +-- cloudformation/     CloudFormation template and template docs
+-- scripts/                Public command-line entrypoints
|   +-- lib/                Shared shell helpers
+-- tools/                  Repo-owned verification helpers
+-- .vscode/                Public-safe editor recommendations and PlantUML/YAML settings
+-- .local/                 Ignored machine-local configuration
```

## Ownership

- `scripts/` owns user-facing commands such as deploy, start, stop, destroy, describe, parameter update, and smoke testing.
- `scripts/lib/` owns shared shell helpers for argument parsing, safety checks, AWS CLI invocation, and output formatting.
- `bootstrap/` owns one-time setup docs and helpers for AWS Organizations, IAM Identity Center permission sets, account assignments, and local routine profile configuration.
- `infra/cloudformation/` owns the CloudFormation template for EC2, security group, IAM instance profile, and related disposable resources.
- `docs/operations/` owns workflow, AWS safety boundaries, and verification policy.
- `docs/proposals/` owns active implementation proposals before durable docs absorb the final behavior.
- `docs/specs/` owns durable version specs that describe shipped behavior and future expansion buckets.
- `tools/` owns sandbox-safe verification helpers that do not contact AWS.

## Public Safety

Generated credentials, AWS CLI output, stack exports, local profiles, and operator-specific values must stay out of source control. Use AWS Systems Manager Parameter Store or another reviewed secret store for live connection secrets. Use `.local/` and ignored generated files only as local operator scratch space, and avoid casual `.env` workflows for credentials that may be exposed through logs, screenshots, cloud tooling, or agent-assisted development.
