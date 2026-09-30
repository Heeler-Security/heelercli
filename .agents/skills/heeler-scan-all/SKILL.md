---
name: heeler-scan-all
description: Run existing Heeler CLI checks for local secrets, dependency vulnerabilities, dependency policy and malicious packages in one pass. Use for a full scan or pre-release gate; this is not SAST or a remote working-tree scan.
---

# Heeler Scan All

Use this skill for one-command-style full security coverage.

## Scope

- Secrets scanning (`heelercli secrets`)
- Dependency vulnerability scanning (`heelercli vulnerabilities`)
- Dependency policy (licenses and configured package-age checks)
- Malicious package detection (`heelercli detect-malicious-packages`)

## Heelercli preflight (required)

Before running any scan in this workflow:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm existing authentication and the intended platform target for dependency checks.
   Do not print keys, replace a login or silently switch environments. `--profile`
   selects a policy profile, not an authentication environment.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## Workflow

1. Get the reconciled counts and the overall verdict in one pass:

   ```
   heelercli ci --format llm -q
   ```

   `ci` generates the SBOM once and reuses it across the dependency checks, so this is
   the cheapest way to learn what each check found and whether anything violated policy.
   Its per-check summary lines are the source of truth for the counts in Section A-D.
   In CLI 1.0.24 the defaults are vulnerabilities, dependency-policy, malicious-packages
   and secrets. Respect the user's subset via `--checks`. The optional `licenses`
   check is mutually exclusive with dependency-policy and omits package-age checks.
   SAST and agent-file analysis are not included. Do not add content-uploading
   agent-file checks without a separate scope/data-sharing decision.
   For staged secrets use `--secrets-pre-commit`; dependency inputs remain local
   repository inputs, not a staged-diff-only assessment.

   Capture stdout, stderr and the actual exit status. Preserve failure in automation;
   do not hide it with a pipeline's final exit code or `|| true`. `error` means
   incomplete, not zero findings. Exit 1 can mean policy failure, execution error,
   or both; setup failures may occur before a report. Report SBOM errors, excluded
   manifests and skipped checks; partial coverage cannot establish a clean result.

2. Run detail passes only for the sections that need more than a count. `ci` reports
   status, violations and a summary per check - it does not return CVE identifiers, CVSS
   vectors, exploitability, license rows or secret detail, all of which this skill's
   output contract requires:

   Preserve scope, exclusions and policy in each detail pass. In particular,
   translate CI's staged-secret mode to `secrets --pre-commit` rather than running
   the broader example below. Do not silently expand the scan to get details.

   - `heelercli vulnerabilities --format llm -q` - for top CVEs, CVSS and exploitability.
   - `heelercli licenses --format llm -q` - for the package-to-license mapping;
     this detail pass does not replace the dependency-age verdict.
   - `heelercli detect-malicious-packages --format llm -q` - for flagged packages.
   - `heelercli secrets -q` - for per-finding paths and validation status.

   Skip any detail pass whose `ci` check reported nothing of interest, and say in the
   report that it was skipped for that reason.

3. Reconcile: if a detail pass disagrees with the `ci` count for the same check, report
   both numbers and treat the discrepancy as a finding rather than silently picking one.

4. Produce a consolidated report with all executed sections and overall pass/fail.

## Defaults

- Secrets: separate active, assumed-valid, unverified and inactive findings. Do not
  discard uncertain findings to obtain a pass. For secret-only/staged requests use
  [heeler-secrets-scan](../heeler-secrets-scan/SKILL.md).
- Vulnerabilities: use `--format llm -q` by default; keep informational only when
  neither existing policy nor user-requested failure criteria apply.
- Licenses: use `--format llm -q` by default.
- Licenses: flag unknown and strong copyleft for review.
- Malicious packages: include dedicated findings section from `detect-malicious-packages` output.
- Policy handling: respect existing repository/platform policy and user flags. Keep
  findings separate from policy violations; a passing gate need not mean zero findings.
- Without vulnerability policy: prioritize `critical` findings and base advisory recommendation on critical/high exposure.
- Without license policy: prefer permissive OSS licenses and call out copyleft/unknown/custom-license risks.
- Exploitability-aware triage: prioritize `critical` findings with exploitability `ACTIVE`, especially when network-accessible and reachable in repository code paths.

## Output contract

- Section A: Secrets summary (count, validated count, fail triggers)
- Section B: Vulnerabilities summary (severity counts, policy failures)
  - For top risks, include CVSS vector (if available), exploitability (`ACTIVE`/`LIKELY`/`NOT`), and reachability context.
- Section C: Dependency policy summary (license violations/unknowns and package-age
  status, configured threshold and unavailable age evidence)
- Section D: Malicious package summary
- Final verdict:
  - Explicit `INCOMPLETE`/`ERROR` qualification whenever a selected check could not
    complete, alongside any observed policy failures and the actual CLI exit code.
  - `PASS`/`FAIL` only for policy-gated checks.
  - `ADVISORY` when no policy is defined, with explicit risk judgment and recommendation.
- In advisory mode, include: `top critical vulnerabilities` and `top license risks` sections.

## Notes

- If one scanner cannot run (missing toolchain), continue remaining scans and clearly mark partial coverage.

## Heeler MCP context

MCP is optional stored context, not a prerequisite or substitute for this scan.
Discover current tools/schemas and resolve the project before using them; do not
assume legacy names. Indexed platform findings do not see uncommitted files. Keep
stored findings and local results separately labeled by scope and freshness.
Do not require an architecture/design review for an ordinary local scan.

## Execution and data boundary

| Check | Local work | Network / data leaving the machine |
| --- | --- | --- |
| Vulnerabilities | Build dependency inventory | Dependency/SBOM metadata sent to Heeler for assessment |
| Dependency policy / licenses | Build inventory and apply gates | Package metadata and policy/intelligence requests to Heeler |
| Malicious packages | Build inventory | Package coordinates sent for Heeler intelligence |
| Secrets | Embedded scanner reads local or staged content | Credential validation can contact credential providers |

Dependency discovery may invoke ecosystem tools with registry access. Configured
CLI usage telemetry can contact Heeler. Do not promise offline operation or no
egress from the word "local". If the request forbids these network operations,
pause before running and explain the boundary; do not invent an offline flag.
Reports and CLI logs may persist locally: follow the user's retention policy,
avoid unnecessary artifacts, and never copy raw credentials or sensitive snippets
into chat, MCP, tickets or uploaded reports. No source upload or zero-retention
guarantee is implied by this skill.
