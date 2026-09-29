# Heeler Agent Skills

This repository includes Heeler security skills in `.agents/skills/`. The generated
[discovery catalog](skills.json) lists every skill, its entrypoint, CLI contract and
SHA-256 hashes for its bundled files. It is repository-hosted discovery, not a new
MCP tool or hosted `.well-known` endpoint.

## Included skills

- `heeler-secrets-scan`
- `heeler-vulnerabilities-scan`
- `heeler-license-check`
- `heeler-scan-all`
- `heeler-security-review`
- `heeler-recommended-version`
- `heeler-malicious-package-scan`
- `heeler-threat-modeling`
- `heeler-agent-file-scan` — selected-file upload assessment; requires explicit consent

## Local use (from this repository)

Codex can discover repository-local skills from `.agents/skills/`. See the
[client recipes and separate verification levels](CLIENTS.md); installation in one
client does not establish compatibility with every other client.

## Reproducible installation

Select a reviewed release tag or full commit containing the catalog; do not use a
moving `main` reference when reproducibility matters. Clone/check out that exact
revision, record its commit, and review the selected skills before installing them.
The catalog hashes detect changes relative to that checkout; they are not signatures
or independent proof of publisher trust. Do not overwrite existing skills silently.

Use a CLI version at least as new as `minimum_cli_version` in the catalog. The bundle
and binary have separate identities: a bundle commit is not automatically the CLI
release tag. This new catalog is not retroactively present in older tags.

## Maintainer conformance

```bash
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p 'test_*.py'
python scripts/check_skills.py
python scripts/check_skills.py --cli /path/to/heelercli --expected-version 1.0.24
```

After intentional skill edits, update the command contract as needed and regenerate
the catalog with `python scripts/check_skills.py --write`, then rerun the checks.
The checker parses YAML, verifies names/local links/resources, requires every skill
in the catalog, and checks declared commands/flags against the exact trusted binary's
help. It never executes scans or skill instructions. A passing help check does not
prove auth, model behavior, network results or native-client workflow completion.
Keep CLI examples as separate invocations with literal command paths; use angle-bracket
placeholders for positional values. Compound invocations fail closed in this checker.

The **Skill bundle conformance** workflow validates each relevant `main` push and
supports an explicit public CLI release input. It retains the catalog, source commit
and conformance result together as a CI artifact, without publishing a release or
changing a tag. Run it for each target CLI version before distributing the bundle.
Behavioral cases for the upload skill are in `tests/agent-file-skill-cases.json`;
they require independent, side-effect-free evaluation, not just JSON validation.

## Install via dotagents (for other repositories)

The existing dotagents recipe below follows repository state and is not a pinned
release or a verified client-support claim. For a controlled rollout use the pinned
checkout procedure above and install only the needed skills.

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
