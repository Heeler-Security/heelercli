---
name: heeler-secrets-scan
description: Run Heeler secret scanning for a repository or staged changes. Use when the user asks to detect, validate, or gate on exposed secrets, tokens, credentials, or API keys.
---

# Heeler Secrets Scan

Use this skill for secret-detection workflows with `heelercli`.

## When to use

- User asks for secret scanning, credential leak checks, or pre-commit secret gates.
- User wants to reduce false positives with validated-only findings.
- User wants to fail only for specific secret types.

## When not to use

- User asks for dependency/CVE analysis only (use vulnerability scanning skill).
- User asks for licensing/compliance checks only (use license skill).

## Help format (reference)

```text
heelercli secrets [flags]

  --exclude strings   (repeatable) directories to exclude as glob patterns (similar to .gitignore)
  --fail-on strings   comma-separated list of types to fail on
  --only-validated    filter to only show validated items
  --pre-commit        enable pre-commit mode
```

Global flags:

- `-q, --quiet` disable spinners/progress output for clean automation logs.

## Heelercli preflight (required)

Before running scan commands:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm authentication context is available for platform-backed checks:
   - valid stored login (`heelercli login <base-url> <HEELER_API_KEY>`), or
   - `HEELER_API_KEY` environment variable.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## Workflow

1. Choose mode:
   - CI or local full check: `heelercli secrets -q`
   - Pre-commit behavior: `heelercli secrets --pre-commit -q`
2. Apply optional tuning:
   - Exclusions: `--exclude "dist/**" --exclude "vendor/**"`
   - Severity/type gate: `--fail-on aws,github,slack`
   - Lower-noise mode: `--only-validated`
3. Run scan and capture both findings and exit code.
4. Report:
   - Total findings.
   - Which findings are validation-backed.
   - Which items triggered failure criteria.
   - Next remediation actions.

## Output style

- Always separate "findings" from "fail criteria".
- Include exact command used.
- If no findings, explicitly say scan passed.
