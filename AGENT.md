# AGENT Instructions

## Commit Message Policy (Mandatory)

All commits **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Required format

`<type>(<scope>): <description>`

- `type` is required
- `scope` is optional
- `description` is required and should be concise, imperative, and lowercase (except proper nouns)

Examples:

- `feat(parser): add support for flake check assertions`
- `fix(ci): run flake check on pull requests`
- `chore: update nix inputs`

### Allowed types

- `feat`
- `fix`
- `docs`
- `style`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `chore`
- `revert`

### Breaking changes

Use either:

- `type(scope)!: description`
- or include a `BREAKING CHANGE:` footer in the commit body

Examples:

- `feat(api)!: rename sdk assertion output schema`
- with footer:
  - `BREAKING CHANGE: assertion JSON keys were renamed`

### Additional rules

- Do not use vague subjects like "update" or "changes"
- Keep subject line under 72 characters
- Reference issues/PRs in footer when relevant (e.g., `Refs: #1`)

### Non-compliant commits

Commit messages that do not follow this format should be rejected and rewritten before merging.
