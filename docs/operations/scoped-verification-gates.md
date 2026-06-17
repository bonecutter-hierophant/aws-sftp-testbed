# Scoped Verification Gates

Date: 2026-06-16

This repository uses repo-owned verification gates so public changes can be reviewed from local commands. The model is inherited from SimpleETL and reduced for a smaller tooling repository: keep the command surface stable, keep each gate narrow, and make the chosen verification lane visible in proposals and review notes.

The guiding rule is "touch a thing, test that thing." Documentation-only work should not need live AWS access. Script or infrastructure work should get static and dry-run coverage before a human-approved live smoke test. High-privilege account bootstrap work should never be validated only by a successful live command.

## Gates

- `structure`: checks required first-commit directories and owner docs.
- `public-sanitization`: scans text files for common secrets, local user paths, generated keys, and public-repo hygiene risks.
- `shell-static`: statically checks shell entrypoints for basic safety shape.
- `docs`: scans workspace text files for trailing whitespace without requiring Git.

These are not a complete product test suite yet. They are the foundation for one: public-safe repository shape first, static command safety second, deterministic dry-run checks next, and live AWS smoke tests only when a human intentionally runs them.

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

## Review Use

Every meaningful proposal should name its expected verification lane before implementation starts. If implementation expands into AWS account bootstrap, IAM, public network exposure, secret schema, or lifecycle behavior, update the proposal and broaden the verification plan before continuing.

When a live AWS check is needed, keep it separate from `verify:safe`, name the exact command or manual checklist in the proposal, and require human approval before running it.
