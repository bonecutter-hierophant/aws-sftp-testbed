# Sandbox-Safe Verification

Date: 2026-06-16

Sandbox-safe verification must be read-only or limited to local process execution inside the repository. It must not contact AWS, mutate cloud state, create credentials, or depend on machine-local private configuration.

## Safe Gates

Safe gates may:

- scan text files
- inspect repository structure
- parse committed metadata
- statically inspect shell scripts

Safe gates must not:

- run AWS CLI commands
- deploy, update, stop, or destroy infrastructure
- read local AWS credentials
- print secrets
- depend on `.local/`
- mutate files outside temporary ignored locations

## Closeout Bias

Use `npm run verify:safe` while iterating. Use narrower scoped gates when touching a small area, and record why a narrower set is acceptable if the recommendation runner suggests broader verification.
