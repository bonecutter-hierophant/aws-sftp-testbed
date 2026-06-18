# Public Repository Sanitization

Date: 2026-06-16

This repository is public. Treat every committed file as something a future collaborator, search engine, or security reviewer might inspect.

That standard is especially important here because the project documents AWS account bootstrap, IAM boundaries, public networking, and generated SFTP credentials. The repository should teach a careful workflow without publishing private account details or making broad cloud access look routine.

## Commit Boundary

Do not commit:

- secrets, tokens, private keys, OAuth credentials, API keys, or generated passwords
- private AWS account IDs, IAM ARNs, access keys, live profile names, or account aliases
- generated AWS CLI responses, CloudFormation outputs, stack event dumps, or deployment logs
- generated SFTP host keys, client keys, known-hosts files, or smoke-test artifacts
- live secret, SecureString, or parameter payloads
- local operator configuration from `.local/`
- customer data, private project context, or machine-local private paths
- generated scratch output, logs, dependency folders, build output, or infrastructure state files

## Required Checks

Before a first public commit, PR, or push:

```text
npm run verify:safe
npm run verify:scoped structure,public-sanitization,shell-static,docs
```

Use `npm run verify:recommend:dirty` only as a human-approved Git checkpoint.

The `public-sanitization` gate scans repo text files for common credential patterns, generated key material, local user paths, and public-repo hygiene risks. It is a backstop, not a substitute for human review.

Sanitization is intentionally conservative. A clean scan means the obvious patterns were not found; it does not mean a public reader could not infer something private from careless prose, copied command output, or overly specific local naming.

## Human Review

Before publishing, review the diff for:

- unsafe defaults
- private AWS details
- generated credentials or operational output
- misleading cost claims
- comments or docs that reveal internal-only process details
- generated files that should be ignored instead

When in doubt, keep the first public version conservative, accurate, and easy to replace.
