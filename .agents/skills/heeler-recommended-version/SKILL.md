---
name: heeler-recommended-version
description: Determine the recommended dependency version for a package ecosystem. Use when installing a new dependency/updating a dependency or users ask what version of a dependency they should install or upgrade to.
---

# Heeler Recommended Version

Use this skill to answer dependency version-selection questions for third-party packages (especially when installing or updating to new versions).

## When to use

- User asks what version of a dependency to install.
- User asks whether a dependency should be upgraded and to which version.
- Dependency additions/upgrades are detected and version guidance is needed.

## Trigger cues

- A new dependency is being added to the project.
- A dependency version is being upgraded or pinned.
- Manifest/lockfile files change in a PR and version guidance is needed.

## Mandatory invocation conditions

- MUST run when a new dependency is added.
- MUST run when dependency versions are upgraded or newly pinned.
- MUST run when invoked by `heeler-security-review` after dependency-change detection.

## Heelercli preflight (required)

Before running recommendation commands:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm authentication context is available:
   - valid stored login (`heelercli login <base-url> <HEELER_API_KEY>`), or
   - `HEELER_API_KEY` environment variable.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## Workflow

1. Identify dependency package names and ecosystems that need guidance (from user input or manifest/lockfile changes).
2. For each package, run:
   - `heelercli get-recommended-version <package-name> --package-ecosystem <ecosystem>`
3. Use `--format detailed` for human-readable responses and `--format json` for automation/parsing workflows.
4. Use command output as the primary recommendation source.
5. Return package-specific guidance with recommended version and a short rationale.
6. If multiple package updates are requested, run the command per package and present a compact mapping.

## Rules

- The command requires exactly one positional argument: `<package-name>`.
- The `--package-ecosystem` flag is required for each invocation.
- Ecosystem should be explicit and use canonical lowercase values when possible: `maven`, `pypi`, `npm`, `go`, `nuget`, `rubygems`, `composer`, `cargo` (or `default` when applicable).
- Parsing is case-insensitive, but prefer canonical lowercase values in generated commands and examples.
- The recommendation is package/ecosystem-aware and based on Heeler platform heuristics (including usage and active vulnerabilities).
- Do not substitute this with GitHub latest-release checks.
- If package identity is ambiguous (same name across ecosystems), resolve with repository context first and ask only if still ambiguous.
- Do not use this skill to recommend `heelercli` release tags for pre-commit hook pinning.

## Command reference

```text
heelercli get-recommended-version <package-name> --package-ecosystem <ecosystem> [--format detailed|json] [--output <file>]
```

## Ecosystem mapping hints

- `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock` -> `npm`
- `requirements.txt`, `pyproject.toml`, `poetry.lock`, `Pipfile.lock` -> `pypi`
- `pom.xml` -> `maven`
- `build.gradle`, `build.gradle.kts` -> `maven` (Java ecosystem in Heeler)
- `go.mod` -> `go`
- `.csproj`, `.sln`, `packages.config` -> `nuget`
- `composer.json`, `composer.lock` -> `composer`
- `Cargo.toml`, `Cargo.lock` -> `cargo`
- `Gemfile`, `Gemfile.lock` -> `rubygems`
- If multiple ecosystems exist, map each package to its source manifest/lockfile before invocation.

## Output style

- For each package: show package name, recommended version, and one-line rationale.
- If multiple packages are evaluated, return a short table or bullet map.
