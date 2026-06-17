# Scripts

This directory owns public command-line entrypoints for the SFTP testbed.

Planned commands:

- `deploy.sh`: deploy or update the CloudFormation stack after validating safety inputs
- `start.sh`: start an existing stopped testbed and refresh current connection details
- `stop.sh`: stop the EC2 instance while warning about remaining storage and resource charges
- `destroy.sh`: delete the CloudFormation stack
- `describe.sh`: print non-sensitive current stack and endpoint details
- `update-secret.sh`: write current connection details to AWS Secrets Manager
- `smoke-test.sh`: prove SFTP connect, upload, list, download, and delete behavior

Shared helpers live in `scripts/lib/`.

Scripts should refuse unsafe defaults and avoid printing sensitive values unless an explicit sensitive-output flag is provided.
