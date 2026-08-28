---
name: heeler-scan-all
description: Run a complete Heeler security scan in one pass - secrets, dependency vulnerabilities, licenses, and malicious packages. Use when the user asks for a single 'full scan', 'scan everything', or a pre-release security gate.
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

1. Get the reconciled counts and the overall verdict in one pass:

   ```
   heelercli ci --checks vulnerabilities,licenses,malicious-packages,secrets --format llm -q
   ```

   `ci` generates the SBOM once and reuses it across the dependency checks, so this is
   the cheapest way to learn what each check found and whether anything violated policy.
   Its per-check summary lines are the source of truth for the counts in Section A-D.

2. Run detail passes only for the sections that need more than a count. `ci` reports
   status, violations and a summary per check - it does not return CVE identifiers, CVSS
   vectors, exploitability, license rows or secret detail, all of which this skill's
   output contract requires:

   - `heelercli vulnerabilities --format llm -q` - for top CVEs, CVSS and exploitability.
   - `heelercli licenses --format llm -q` - for the package-to-license mapping.
   - `heelercli detect-malicious-packages --format llm -q` - for flagged packages.
   - `heelercli secrets -q` - for per-finding paths and validation status.

   Skip any detail pass whose `ci` check reported nothing of interest, and say in the
   report that it was skipped for that reason.

3. Reconcile: if a detail pass disagrees with the `ci` count for the same check, report
   both numbers and treat the discrepancy as a finding rather than silently picking one.

4. Produce a consolidated report with all executed sections and overall pass/fail.

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

## Heeler MCP context

If the Heeler MCP server is connected, pair this skill with stored platform context: pull `get_endpoint_security_context_for_project` for existing auth patterns, `get_vulnerabilities_for_project` for active dependency findings, and the `secure_development_checklist` prompt before writing new code. MCP tools reflect the last platform scan of committed code; this skill covers the working tree that scan cannot see.
