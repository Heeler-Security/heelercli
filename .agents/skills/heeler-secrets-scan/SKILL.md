---
name: heeler-secrets-scan
description: Scan local repository files or staged changes for secrets using Heeler CLI. Use before committing or for credential-leak checks; not a dependency scan or an offline-only guarantee.
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
  --only-validated    only fail on active credentials plus assumed-valid key material
  --pre-commit        enable pre-commit mode
```

Global flags:

- `-q, --quiet` disable spinners/progress output for clean automation logs.

## Heelercli preflight (required)

Before running scan commands:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm the repository/path and staged versus broader scope. Secret detection
   does not require a Heeler platform login; do not demand or change authentication
   merely to run this local check. These instructions target CLI 1.0.24 or newer.
3. Detection runs locally, but validation can contact credential providers using
   candidate credentials. Configured CLI usage telemetry can contact Heeler too.
   CLI 1.0.24 exposes no offline/no-validation switch. If the user forbids egress or
   credential probes, stop before scanning and explain the limitation.

## Workflow

1. Choose mode:
   - CI or local full check: `heelercli secrets -q`
   - Pre-commit behavior: `heelercli secrets --pre-commit -q`
2. Apply optional tuning:
   - Exclusions: `--exclude "dist/**" --exclude "vendor/**"`
   - Rule-family gate (not severity): `--fail-on aws,github,slack`
   - Lower-noise mode: `--only-validated`
3. Run scan and capture stdout, stderr and the actual exit code. Preserve a failure
   in automation; a wrapper or formatter must not turn it into success. Exit 1 alone
   does not distinguish findings from an execution error.
4. Report:
   - Total findings.
   - Active, assumed-valid, unverified and inactive findings separately.
   - Which items triggered failure criteria.
   - Next remediation actions.

## Output style

- Always separate "findings" from "fail criteria".
- Include exact command used.
- Report a pass only after successful completion, qualified by scope and filters.
  Timeout, missing prerequisites or malformed output mean incomplete coverage, not
  zero findings. A passing policy gate with remaining findings is not a clean scan.

## Scope and privacy

Pre-commit mode scans staged content in a Git repository; it does not establish
that unstaged/untracked changes or all history are clean. Do not stage or modify
files to make the scan work without authorization. Use `--path` for a requested
local path; report the broader mode without claiming an exhaustive history audit.
Honor requested exclusions and disclose their coverage gaps.

`--only-validated` changes failure eligibility to active credentials plus
assumed-valid key material; not every eligible finding was proved live. Unverified
does not mean safe. Do not enable filtering or edit suppressions merely to pass.

Do not send source, candidate secrets or raw scanner artifacts to MCP. Report rule,
path, line and validation state, not credential values—even partially masked ones.
The scanner uses a temporary findings file and attempts to remove it afterward;
CLI logs and saved reports can persist. Do not promise zero retention or guaranteed
cleanup after interruption. Recommend rotation/revocation where appropriate;
removing a line does not invalidate a credential. Do not rotate keys or install
hooks unless requested.

## Heeler MCP context

No MCP connection or architecture review is required. If the user needs stored
finding context, discover available tools and use their current schemas. Indexed
platform findings are separate from this local/staged scan and cannot certify
uncommitted changes. Use [heeler-scan-all](../heeler-scan-all/SKILL.md) for combined
checks only when the user requests that broader scope.
