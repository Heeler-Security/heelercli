---
name: heeler-scan-all
description: Run a complete security scan workflow with Heeler: secrets, vulnerabilities, and license checks. Use when the user asks for a single "full scan" or "scan everything" pass.
---

# Heeler Scan All

Use this skill for one-command-style full security coverage.

## Scope

- Secrets scanning (`heelercli secrets`)
- Dependency vulnerability scanning (`heelercli vulnerabilities`)
- License checks (dependency license inventory + policy check)
- Malicious package detection (`heelercli detect-malicious-packages`)

## Heelercli preflight (required)

Before running any scan in this workflow:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm authentication context is available:
   - valid stored login (`heelercli login <base-url> <HEELER_API_KEY>`), or
   - `HEELER_API_KEY` environment variable.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## Workflow

1. Run secrets scan first and capture findings + exit code: `heelercli secrets -q`.
2. Run vulnerability scan second with requested fail policy: `heelercli vulnerabilities --format llm -q`.
3. Run license check third and classify policy violations: `heelercli licenses --format llm -q`.
4. Run malicious package scan: `heelercli detect-malicious-packages --format llm -q`.
5. Produce a consolidated report with all executed sections and overall pass/fail.

## Defaults

- Secrets: include validated findings in report; support `--only-validated` on request.
- Vulnerabilities: use `--format llm -q` by default; keep informational unless user asks for fail policy.
- Licenses: use `--format llm -q` by default.
- Licenses: flag unknown and strong copyleft for review.
- Malicious packages: include dedicated findings section from `detect-malicious-packages` output.
- Policy handling: only enforce pass/fail for vulnerability/license checks when a policy is explicitly defined.
- Without vulnerability policy: prioritize `critical` findings and base advisory recommendation on critical/high exposure.
- Without license policy: prefer permissive OSS licenses and call out copyleft/unknown/custom-license risks.
- Exploitability-aware triage: prioritize `critical` findings with exploitability `ACTIVE`, especially when network-accessible and reachable in repository code paths.

## Output contract

- Section A: Secrets summary (count, validated count, fail triggers)
- Section B: Vulnerabilities summary (severity counts, policy failures)
  - For top risks, include CVSS vector (if available), exploitability (`ACTIVE`/`LIKELY`/`NOT`), and reachability context.
- Section C: License summary (violations, unknowns)
- Section D: Malicious package summary
- Final verdict:
  - `PASS`/`FAIL` only for policy-gated checks.
  - `ADVISORY` when no policy is defined, with explicit risk judgment and recommendation.
- In advisory mode, include: `top critical vulnerabilities` and `top license risks` sections.

## Notes

- If one scanner cannot run (missing toolchain), continue remaining scans and clearly mark partial coverage.
