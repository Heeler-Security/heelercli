---
name: heeler-malicious-package-scan
description: Detect suspicious or malicious dependencies using Heeler package-risk intelligence. Use when a new dependency is installed or users ask about typosquatting, malware in dependencies, or supply-chain package risk.
---

# Heeler Malicious Package Scan

Use this skill to detect potentially malicious packages in repository dependencies.

## When to use

- User asks for malicious package detection.
- User asks about typosquatting, dependency hijacking, or package reputation risk.
- Dependency additions/upgrades are detected and supply-chain risk needs review.

## Trigger cues

- New dependency was added to a manifest/lockfile.
- Existing dependency version changed in a PR.
- User asks for release-readiness supply-chain checks.

## Help format (reference)

```text
heelercli detect-malicious-packages [flags]
```

Important flags:

- `--format detailed|table|json|llm|sarif`
- `-q, --quiet`

## Heelercli preflight (required)

Before running malicious-package commands:

1. Confirm `heelercli` is installed and executable (for example `heelercli --version`).
2. Confirm authentication context is available:
   - valid stored login (`heelercli login <base-url> <HEELER_API_KEY>`), or
   - `HEELER_API_KEY` environment variable.
3. If command output indicates auth is missing/expired/invalid, stop and return auth fix instructions before retrying.

## Workflow

1. Run `heelercli detect-malicious-packages --format llm -q` from repository root.
2. Capture flagged packages and risk signals from output.
3. Classify each flagged package:
   - `high confidence`: clear malicious indicators from scanner output.
   - `needs verification`: suspicious signal with incomplete evidence.
4. For high-confidence findings, provide package name, version, evidence signal, and immediate remediation.
5. For medium-confidence items, provide concrete verification steps before removal/blocking.
6. If no package is flagged, report clean result and any coverage limitations.

## Policy and decision rules

- If an organization policy defines malicious-package gating, use it for pass/fail.
- If no explicit policy is defined, report in advisory mode.
- Treat high-confidence malicious findings as release blockers unless user explicitly accepts risk.
- Do not auto-fail on low-confidence suspicion without scanner evidence.

## Output style

- Include exact command used and whether output is `policy-gated` or `advisory`.
- Provide counts: total packages assessed, flagged packages, high-confidence findings.
- Separate `confirmed/likely malicious` from `needs verification`.
- For each flagged package, include remediation path (remove, replace, pin safe version, blocklist, or quarantine).
