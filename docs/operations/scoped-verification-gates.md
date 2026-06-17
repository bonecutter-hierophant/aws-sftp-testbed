# Scoped Verification Gates

Date: 2026-06-16

This repository uses repo-owned verification gates so public changes can be reviewed from local commands.

## Gates

- `structure`: checks required first-commit directories and owner docs.
- `public-sanitization`: scans text files for common secrets, local user paths, generated keys, and public-repo hygiene risks.
- `shell-static`: statically checks shell entrypoints for basic safety shape.
- `docs`: scans workspace text files for trailing whitespace without requiring Git.

## Common Commands

```text
npm run verify:list
npm run verify:safe
npm run verify:scoped structure,public-sanitization,shell-static,docs
```

Git-based recommendation is available as a human-approved checkpoint:

```text
npm run verify:recommend:dirty
```

## Defaults

- Documentation-only changes: `npm run verify:scoped public-sanitization,docs`
- Script changes: `npm run verify:scoped structure,public-sanitization,shell-static,docs`
- Infrastructure template changes: `npm run verify:scoped structure,public-sanitization,docs`
- Tooling or package changes: `npm run verify:scoped structure,public-sanitization,shell-static,docs`

`verify:safe` is the normal frequent local lane. It does not contact AWS.
