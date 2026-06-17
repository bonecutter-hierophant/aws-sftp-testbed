# Script Helpers

This directory owns shared shell helpers used by `scripts/*.sh`.

Expected helper responsibilities:

- consistent error handling
- argument parsing
- required command checks
- CIDR safety validation
- sensitive output redaction
- AWS CLI wrapper functions
- common stack naming and tagging defaults

Helpers must not contain live credentials or machine-local configuration.
