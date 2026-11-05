---
name: heeler-vulnerabilities-scan
description: Run Heeler dependency vulnerability scanning and policy gating. Use when the user asks for CVE analysis, severity gating, baseline regression checks, or SBOM-based vulnerability assessment.
---

# Heeler Vulnerabilities Scan

Use this skill for dependency vulnerability workflows.

## When to use

- User asks for dependency risk or CVE scanning.
- User asks to fail on severity, IDs, or any vulnerability.
- User asks for baseline vs new-findings-only behavior in CI.

## Trigger cues

- Dependency changes are detected (manifest/lockfile edits, added package, upgraded package).
- User asks if a dependency update is safe.
- User asks for release readiness or security posture of dependencies.

## Help format (reference)

```text
heelercli vulnerabilities [flags]
```

Important flags:

- `--fail-on-any`
- `--fail-on-severity critical,high`
- `--fail-on-id CVE-2024-1234,GHSA-xxxx-yyyy-zzzz`
- `--exclude-dir path/to/dir` (repeatable; relative to the invocation directory, prefix match)
- `--new-findings-only` (new relative to the monitored branch's latest scan), or with `--baseline <path>` (new relative to a baseline file)
- `--format detailed|table|json|sarif|llm`
- `--output <path>`
- `-q, --quiet`

## Heelercli preflight (required)

Before running scan commands:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm authentication context is available:
   - valid stored login (`heelercli login <base-url> <HEELER_API_KEY>`), or
   - `HEELER_API_KEY` environment variable.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## How the scan runs

- The CLI uploads the source in scope (the invocation directory and below) to Heeler. Heeler resolves the dependencies and evaluates findings. No local package-manager toolchain is needed.
- By default the working tree is uploaded, including uncommitted and untracked files. Credential files such as `.npmrc`, `.pypirc`, `settings.xml`, `.netrc`, `.env*` and private keys are never uploaded.
- The CLI waits up to 30 minutes. If the wait ends first, the scan keeps running and the output names a `fetch` command; run it rather than starting a new scan.

Exit codes:

- `0`: complete scan, no gate failure.
- `1`: gate failure, or invalid option, configuration or baseline.
- `3`: authentication or access rejected; stop and return auth fix instructions.
- `4`: CI scanning is not enabled for the organization; report it and stop.
- `10`: not scanned, incomplete resolution, no dependency roots, or the wait ended. Report it as incomplete, never as clean.

## Workflow

1. Confirm project manifests are present, and run from the directory whose subtree should be scanned (the repository root for a full scan).
2. Run a default scan: `heelercli vulnerabilities --format llm -q`.
3. Add policy gates requested by user (severity, any, specific IDs).
4. For CI regression mode, use baseline + new-only flags.
5. For agent/human mixed workflows, prefer `--format llm -q`.
6. Prefer `json` or `sarif` only when another tool explicitly requires those formats.
7. Report findings grouped by severity and package, then explain fail/pass decision.
8. For top findings, validate repository exposure by checking whether affected packages are reachable from network-facing or auth-bypassable code paths.

## Policy and decision rules

- If a vulnerability policy is explicitly defined (for example `--fail-on-any`, `--fail-on-severity`, `--fail-on-id`, baseline rules), enforce that policy for pass/fail.
- If no policy is defined, do not force a strict pass/fail gate from absence of findings alone.
- Without policy, prioritize and discuss `critical` vulnerabilities first, then `high`, then the rest.
- Without policy, prioritize in this order:
  1. `critical` + exploitability `ACTIVE` + network-accessible/reachable
  2. `critical` + exploitability `LIKELY`
  3. `high` + exploitability `ACTIVE`
  4. remaining findings by severity and exploitability
- Without policy, provide an agent judgment: risk level, notable exposures, and recommended action (ship, ship-with-monitoring, or block for remediation).
- Advisory default without policy:
  - Any `critical` vulnerability: recommend `block for remediation` unless strong compensating controls are documented.
  - No `critical`, but `high` vulnerabilities present: recommend `ship-with-monitoring` only with explicit risk acceptance; otherwise remediate first.
  - Only `medium/low`: recommend based on exposure and exploitability context.

## Exploitability and reachability analysis

- Use CLI-provided exploitability classification (`ACTIVE`, `LIKELY`, `NOT`) as primary signal.
- Include CVSS vector string when present.
- For high-priority items, verify repository context:
  - Is the vulnerable package used in this codebase?
  - Is usage reachable from network-facing entry points?
  - Is auth required, and does that materially reduce risk?
  - Are there mitigating controls (WAF, sandboxing, feature flags, isolated runtime)?
- Optionally use web/advisory sources to confirm active exploitation campaigns when needed.

## Optional SBOM path
- This is not the primary mode of operation. Do not scan SBOMs within a repository unless the user asks for it.
- If user provides an SBOM directly: `heelercli assess-sbom --sbom ./sbom.json --format llm -q [flags]`.

## Output style

- Include command, fail policy, counts by severity, and failing reasons.
- If coverage is incomplete (exit `10`, `Coverage: INCOMPLETE`, or `coverage.complete: false`), name the unresolved roots and reasons and call out incomplete coverage clearly.
- Explicitly label result as either `policy-gated` or `advisory`.
- In advisory mode, list top risks in strict severity order with `critical` items first.
- For top risks, include: CVE/GHSA, CVSS vector (if available), exploitability (`ACTIVE`/`LIKELY`/`NOT`), and reachability (`confirmed`/`possible`/`not observed`).

## Heeler MCP context

If the Heeler MCP server is connected, pair this skill with stored platform context: pull `get_endpoint_security_context_for_project` for existing auth patterns, `get_vulnerabilities_for_project` for active dependency findings, and the `secure_development_checklist` prompt before writing new code. MCP tools reflect the last platform scan of committed code; this skill covers the working tree that scan cannot see.
