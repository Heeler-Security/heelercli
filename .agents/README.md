# Heeler Agent Skills

This repository includes Heeler security skills in `.agents/skills/`.

## Included skills

- `heeler-secrets-scan`
- `heeler-vulnerabilities-scan`
- `heeler-license-check`
- `heeler-scan-all`
- `heeler-security-review`
- `heeler-recommended-version`

## Local use (from this repository)

Codex and compatible agent tooling can discover repository-local skills from `.agents/skills/`.

## Install via dotagents (for other repositories)

Install these skills into another project with dotagents:

```bash
npx @sentry/dotagents init
npx @sentry/dotagents add Heeler-Security/heelercli --all
npx @sentry/dotagents install
```

Install specific skills only:

```bash
npx @sentry/dotagents add Heeler-Security/heelercli heeler-security-review heeler-scan-all
```
