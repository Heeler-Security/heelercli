---
name: heeler-license-check
description: Perform dependency license checks and fetch missing license data for packages. Use when users ask for OSS license compliance, prohibited license detection, or license inventory generation.
---

# Heeler License Check

Use this skill for license discovery and compliance-oriented reporting.

## When to use

- User asks for dependency license inventory.
- User asks to identify copyleft/prohibited licenses.
- User asks to fetch unknown licenses for specific packages.

## Trigger cues

- Dependency changes are detected (manifest/lockfile edits, added package, upgraded package).
- User asks whether a new dependency is license-safe.
- User asks for OSS compliance readiness before merge/release.

## Help format (reference)

```text
heelercli licenses [flags]
```

Important flags:

- `--format detailed|table|json|sarif|llm`
- `-q, --quiet`

## Heelercli preflight (required)

Before running license commands:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm authentication context is available:
   - valid stored login (`heelercli login <base-url> <HEELER_API_KEY>`), or
   - `HEELER_API_KEY` environment variable.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## Workflow

1. Run `heelercli licenses --format llm -q` from the repository root.
2. If license metadata is missing, use available license-fetch options from `heelercli licenses --help` and rerun with `--format llm -q`.
3. Build a package list with name + version + license.
4. Normalize licenses to SPDX-style identifiers where possible.
5. Compare against allow/deny policy (if provided).
6. Report package-to-license mapping and policy violations.

## Policy and decision rules

- If a license policy is explicitly defined (allowlist/denylist/restricted list), enforce it for pass/fail.
- If no policy is defined, do not treat "no obvious issue" as a hard pass/fail gate.
- Without policy, prefer stronger OSS license posture by prioritizing permissive licenses (for example MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC).
- Without policy, call out license risks explicitly, including:
  - strong copyleft and network copyleft (GPL-*, AGPL-*)
  - unknown/custom/no-license entries
  - ambiguous or conflicting license metadata
- Without policy, provide an agent judgment: compliance risk level, licenses needing legal review, and recommended action.

## Policy defaults (if user does not provide one)

- Flag strong copyleft for manual review (AGPL-3.0, GPL-3.0).
- Flag unknown/no-license entries.
- Do not auto-fail permissive licenses (MIT, Apache-2.0, BSD-*).
- Prioritize remediation in this order: unknown/no-license first, then AGPL/GPL, then other restricted licenses.

## Output style

- Provide: package, version, detected license, source of truth, confidence.
- Separate "confirmed violations" from "unknown or needs review".
- Include a short remediation list (replace, exception, legal review).
- Explicitly label result as either `policy-gated` or `advisory`.
- In advisory mode, include a "preferred alternatives" note when risky licenses are present.
