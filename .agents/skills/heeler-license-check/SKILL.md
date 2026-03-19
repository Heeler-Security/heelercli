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
heelercli licenses valid [flags]
```

Important flags:

- `--format detailed|table|json|sarif|llm`
- `-q, --quiet`
- `licenses valid --llm-output`

## Heelercli preflight (required)

Before running license commands:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm authentication context is available:
   - valid stored login (`heelercli login <base-url> <HEELER_API_KEY>`), or
   - `HEELER_API_KEY` environment variable.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## Workflow
1. Run `heelercli licenses --format llm -q` from the repository root.
2. Get explicit valid-license set:
   - run `heelercli licenses valid --llm-output -q [--config <path>] [--profile <name>]`.
   - treat this as the canonical `allowed_licenses` set for recommendation decisions.
3. Compare against effective allow/deny policy and the `allowed_licenses` set.
4. Determine failing licenses:
   - treat licenses outside the valid-license set as failing (invalid)
   - do not fail on unknown licenses; report them separately for review
5. For failing packages, propose remediation in this order:
   - provide 1-3 functionally similar package alternatives in the same ecosystem with likely compliant licenses.
6. Report package-to-license mapping, policy violations, and recommended compliant alternatives.

## Policy and decision rules

- If a license policy is explicitly defined (allowlist/denylist/restricted list), enforce it for pass/fail.
- Without policy, prefer stronger OSS license posture by prioritizing permissive licenses (for example MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC).
- Without policy, call out license risks explicitly, including:
  - strong copyleft and network copyleft (GPL-*, AGPL-*)
  - unknown/custom/no-license entries
  - ambiguous or conflicting license metadata
- Without policy, provide an agent judgment: compliance risk level, licenses needing legal review, and recommended action.

## Policy defaults (if user does not provide one)

- Fail on licenses not in the valid-license set (invalid) when policy is defined.
- Do not fail on unknown/no-license entries; flag for review.
- Prioritize remediation in this order: invalid licenses first, then AGPL/GPL, then other restricted licenses.

## Centralized policy integration

- Prefer policy from config files provided through global flags: `--config` and `--profile`.
- The `licenses` command supports direct policy inputs (`--ok`, `--fail-on`, `--unknown-license-policy`) when no central config is present.
- Use `heelercli licenses valid --llm-output` to fetch the effective valid-license list directly in LLM-friendly form.
- Use `heelercli policy explain` for broader policy context; use `licenses valid` as source of truth for allowed-license checks.

## Output style

- Provide: package, version, detected license, source of truth, confidence.
- Separate "confirmed violations" (invalid) from "unknown or needs review".
- Include a short remediation list (alternative package, exception, legal review).
- Explicitly label result as either `policy-gated` or `advisory`.
- In advisory mode, include a "preferred alternatives" note when risky licenses are present.
- When proposing alternatives, include: package ecosystem, similarity rationale (one line), and compliance status against `allowed_licenses`.
