# Project Structure

`aws-sftp-testbed` is a public command-line AWS toolkit. It should remain small, scriptable, and safe to inspect.

The repo owns the commands and documentation that affect AWS. The SFTP server runs on disposable AWS infrastructure created by those commands, not as a persistent process inside this repository.

```text
.
+-- docs/
|   +-- architecture/       Repo-level structure and diagrams
|   +-- operations/         Workflow, AWS boundary, and verification docs
|   +-- proposals/          Active implementation proposals and public roadmap checklists
+-- infra/
|   +-- cloudformation/     CloudFormation template and template docs
+-- scripts/                Public command-line entrypoints
|   +-- lib/                Shared shell helpers
+-- tools/                  Repo-owned verification helpers
+-- .vscode/                Public-safe editor recommendations and PlantUML/YAML settings
+-- .local/                 Ignored machine-local configuration
```

## Ownership

- `scripts/` owns user-facing commands such as deploy, start, stop, destroy, describe, secret update, and smoke testing.
- `scripts/lib/` owns shared shell helpers for argument parsing, safety checks, AWS CLI invocation, and output formatting.
- `infra/cloudformation/` owns the CloudFormation template for EC2, security group, IAM instance profile, and related disposable resources.
- `docs/operations/` owns workflow, AWS safety boundaries, and verification policy.
- `docs/proposals/` owns active implementation proposals before durable docs absorb the final behavior.
- `tools/` owns sandbox-safe verification helpers that do not contact AWS.

## Public Safety

Generated credentials, AWS CLI output, stack exports, local profiles, and operator-specific values must stay out of source control. Use `.local/`, environment variables, AWS Secrets Manager, and ignored generated files for live values.
