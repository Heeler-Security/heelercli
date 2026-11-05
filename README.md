# Heeler Security CLI

This repository hosts release artifacts for `heelercli` and provides pre-commit hooks for local and CI security checks. The CLI supports secret scanning and source-code static analysis (SAST), plus dependency vulnerability, license, malicious-package and SBOM workflows that run as dependency scans in Heeler.

GitHub is the CLI's distribution location, not a repository-hosting requirement. `heelercli` works with local files and Git working trees from GitHub, GitLab, Bitbucket, and Azure DevOps.

For agent integrations, see the [versioned skill catalog and validation](.agents/README.md)
and [MCP client setup recipes](.agents/CLIENTS.md). Remote MCP, local skills, sensor
visibility and enforcement have separate verification status.

## Quick start (recommended)

Add the auto-install hook to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/Heeler-Security/heelercli
    rev: 2.0.0
    hooks:
      - id: heelercli-auto
```

Run `pre-commit autoupdate` to move `rev` to the newest release.

This hook downloads the correct `heelercli` binary for your OS/arch on first run and reuses the cached binary on subsequent runs. It scans all staged changes for secrets and fails the commit when a secret is detected.

macOS note: both `arm64` (Apple Silicon) and `amd64` (Intel, since 1.0.14) binaries are published. On Apple Silicon, run your terminal natively (not under Rosetta), or the hook will fail with a clear error.

Intel-Mac support in the auto-install hook requires both a `rev:` at a release tag that contains the hook's Intel support (the `rev` pins the hook script itself, so tags up to and including 1.0.17 still refuse to run on Intel) and a binary release of 1.0.14 or later. The latter only matters if you pin `HEELERCLI_VERSION` to an older tag, where the download simply fails with the hook's usual error.

### Windows support

The auto-install hook works on Windows when run inside [Git for Windows](https://gitforwindows.org/) (Git Bash). Git Bash provides the POSIX shell environment (`bash`, `curl`, `unzip`) that the hook requires.

Prerequisites:
- **Git for Windows** (includes Git Bash, which is also used by most `pre-commit` installations on Windows).

No additional configuration is needed. The hook detects Windows automatically and downloads the `.zip` release artifact.

## Using a locally installed CLI

If you already install `heelercli` separately, use the system hook:

```yaml
repos:
  - repo: https://github.com/Heeler-Security/heelercli
    rev: 2.0.0
    hooks:
      - id: heelercli
```

This runs:

```bash
heelercli secrets --pre-commit
```

The auto-install hook also supports these environment variables:

- `HEELERCLI_FULL_SECRETS_SCAN=1` forces full-repository scan mode.
- `HEELERCLI_SECRETS_ONLY_VALIDATED=1` adds `--only-validated` to the secrets scan.
- `HEELERCLI_SECRETS_MODE=pre-commit|full` selects scan mode explicitly.

## Installing a global pre-commit hook

Install `heelercli` on `PATH`, then download and run the installer to scan staged changes in every local Git repository:

```bash
curl -fsSL https://raw.githubusercontent.com/Heeler-Security/heelercli/main/install-heelercli-precommit.sh \
  -o install-heelercli-precommit.sh
chmod +x install-heelercli-precommit.sh
./install-heelercli-precommit.sh --global
```

The installed hook runs `heelercli secrets --pre-commit`. If a pre-commit hook already exists, the installer preserves and runs it before Heeler. Uninstall restores the previous hook and any global Git hooks configuration created by the installer.

```bash
./install-heelercli-precommit.sh --global --uninstall
```

Existing installations do not update automatically. Download the current installer and run it again to apply installer updates.

## Secrets command options

```text
heelercli secrets [flags]

  --exclude strings       (repeatable) directories to exclude as glob patterns (similar to .gitignore)
  --exclude-dir strings   (repeatable) directory paths to exclude from scanning
  --fail-on strings       comma-separated list of types to fail on
  --only-validated        filter to only show validated items
  --path string           directory to scan (defaults to the enclosing git repository, or the current directory outside git)
  --pre-commit            enable pre-commit mode
  --timeout duration      maximum runtime for secrets scan before timing out (default 5m0s)
```

Exit behavior: `heelercli` returns `0` when no failing secrets are found, and non-zero otherwise. Failing secrets are determined by `--fail-on` and `--only-validated`.

Git is optional: outside a git repository the current directory is scanned as-is (SVN checkouts, exported tarballs, plain directories), and the resolved scan root is printed to stderr. Scans cover the whole resolved root even when run from a subdirectory, so use `--path` to target a specific directory. `--pre-commit` still requires a git repository, since staged-file scanning has no meaning without one. Requires `heelercli` 1.0.17 or newer.

## Secrets examples

Scan the repo but exclude build output and vendored code:

```bash
heelercli secrets --exclude "dist/**" --exclude "vendor/**"
```

Fail the scan only for specific secret types:

```bash
heelercli secrets --fail-on aws,github,slack
```

Show only validated findings (reduces noise):

```bash
heelercli secrets --only-validated
```

## Dependency security commands (vulnerability + SBOM)

`vulnerabilities`, `licenses`, `dependency-policy`, `detect-malicious-packages`, `assess-sbom` and the dependency checks in `ci` run as a dependency scan in Heeler. Requires `heelercli` 2.0.0 or later.

How a dependency scan works:

1. The CLI captures the source in scope: the directory you run the command from and everything below it.
2. It uploads that source to Heeler. Credential files are never uploaded (see [What is sent to Heeler](#what-is-sent-to-heeler)).
3. Heeler finds the dependency roots, resolves them and evaluates findings.
4. The CLI receives the findings, scan coverage and, on request, a CycloneDX SBOM per root, then applies your gates.

Package-manager toolchains (`npm`, `mvn`, `go`, `dotnet` and others) are not needed on the machine that runs the CLI. Configure private registry credentials in Heeler. Supported ecosystems are the [package ecosystems Heeler supports for SCA](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/supported-technologies#package-ecosystems-sca).

### Vulnerability scan

```bash
heelercli vulnerabilities [flags]
heelercli vulnerabilities submit [flags]
heelercli vulnerabilities fetch <scan-id> [flags]
```

Policy flags:

| Flag | Description |
| --- | --- |
| `--fail-on-any` | Fail if any vulnerability is found. |
| `--fail-on-severity critical,high` | Fail on the listed severities. |
| `--fail-on-id CVE-2024-1234,GHSA-xxxx-yyyy-zzzz` | Fail on specific IDs. |
| `--new-findings-only` | Gate only on new findings. Without `--baseline`, "new" means not in the latest scan of the repository's monitored branch. |
| `--baseline <path>` | Compare against a baseline report file instead. |
| `--allow-incomplete` | Report partial resolution or an incomplete SBOM export as a warning instead of exit `10`. Gates still apply. |

Source flags (pick one):

| Flag | What is sent | Default |
| --- | --- | --- |
| `--working-tree` | Tracked and untracked files, plus ignored files that are dependency inputs such as a generated lockfile | Outside hooks |
| `--staged` | The staged (index) content | In hooks |
| `--commit` | The repository identity and the pushed `HEAD` SHA, no file contents | Never |
| `--sbom <path>` | A CycloneDX SBOM, unchanged | Never |

Other flags:

| Flag | Description |
| --- | --- |
| `--exclude-dir <path>` | Exclude a directory, relative to the invocation directory. Directory-prefix match, not a glob. Repeat or comma-separate. |
| `--timeout <duration>` | How long to wait for the scan. Default `30m`, or `60s` in hooks. |
| `--strict` | In a hook, fail when the scan cannot complete instead of warning. |
| `--sbom-out <dir>` | Write the CycloneDX SBOM for each root, plus `sboms.json`, to a directory. Add `--overwrite` to replace existing files. |
| `--repository`, `--branch`, `--pr` | Override the identity reported with the scan. `--pr` does not select the PR source or run PR guardrails. |
| `--format detailed\|table\|json\|llm\|sarif`, `--output <path>` | Output format and destination. |

`submit` uploads the input, prints the scan ID and exits. `fetch <scan-id>` waits for that scan and reports it with the same formats and gates. If the wait ends before the scan finishes, the scan keeps running in Heeler and the CLI prints the `fetch` command to collect it.

Examples:

```bash
# fail on critical/high only
heelercli vulnerabilities --fail-on-severity critical,high

# scan only staged changes
heelercli vulnerabilities --staged --fail-on-any

# regression mode in CI (new issues only)
heelercli vulnerabilities --baseline .heeler-baseline-vulns.json --new-findings-only

# export the SBOM Heeler built for each root
heelercli vulnerabilities --sbom-out sboms
```

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Complete scan, no gate failure; or `submit` accepted |
| `1` | Gate failure; invalid option, configuration, baseline or report; conflicting source flags |
| `2` | Invalid `--timeout` |
| `3` | Heeler rejected the API key or access (HTTP 401 or 403); no report is written |
| `4` | CI scanning is not enabled for your organization |
| `10` | Scan failed, not scanned, no dependency roots, incomplete resolution, network failure, or the wait ended before the scan finished |

A gate failure (`1`) takes precedence over incomplete coverage (`10`). In a hook, a scan that cannot complete warns and exits `0` unless `--strict` is set. See [Dependency scan exit codes](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/reference/cli-command-reference#dependency-scan-exit-codes).

### What is sent to Heeler

- **Working-tree and staged scans** upload the selected files in scope. Run below the repository root to limit the upload to that subtree.
- **Credential files are never uploaded**: `.npmrc`, `.pypirc`, `settings.xml`, `settings-security.xml`, `.netrc`, `_netrc`, `.env*`, cloud credential stores (`.aws`, `.azure`, `gcloud`), SSH and GnuPG stores, credential and service-account JSON files, private keys (`id_rsa*`, `id_dsa*`, `id_ecdsa*`, `id_ed25519*`) and key stores (`.pem`, `.key`, `.p12`, `.pfx`, `.jks`, `.keystore`), at any depth. For tracked credential files, only a content fingerprint (the Git blob hash) is sent.
- `.git`, `.hg` and `.svn` are not uploaded. Ignored files that are not dependency inputs, such as build output, are left out with a warning.
- Symbolic links inside the repository are sent as links, never followed. Links that leave the repository are left out with a warning.
- Populated submodules are included. A submodule that is not checked out makes the scan incomplete.
- **Commit scans** send only the repository identity and commit SHA.
- **SBOM scans** upload the SBOM file unchanged.

A working-tree or staged scan started in a Gradle subdirectory uploads the repository's files, not only the subdirectory, so parent settings, wrappers, build logic and sibling projects resolve. Only roots in the requested scope are reported.

See [Dependency scans](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/reference/cli-command-reference#dependency-scans) for scope, exclusions and SBOM export details.

### SBOM assessment

Use `assess-sbom` to assess an existing CycloneDX JSON SBOM file. It reports findings and does not apply vulnerability gates; to gate on an SBOM, use `heelercli vulnerabilities --sbom <path>` with a policy flag.

```bash
heelercli assess-sbom --sbom ./sbom.json [flags]
```

Important flags:

- `--sbom <path>`: path to a CycloneDX JSON SBOM file.
- `--format detailed|table|json|llm|sarif`: choose output format.
- `--output <path>`: write output to file.
- `--timeout`, `--allow-incomplete`, `--strict`, and the `submit` and `fetch <scan-id>` subcommands work as for `vulnerabilities`.

Notes:

- `--sbom_file` is deprecated; use `--sbom`.

### License checks

Use `licenses` to scan dependencies for license risk and policy violations. It runs the same dependency scan in Heeler and uses your organization's directory exclusions.

```bash
heelercli licenses --format llm -q
```

Use `licenses valid` to print the effective allowed SPDX license set (config/profile first, backend defaults fallback):

```bash
heelercli licenses valid --llm-output -q
```

### SBOM download (platform SBOM)

```bash
# exactly one of the two flags is required
heelercli download-sbom --service_id <id>
heelercli download-sbom --application_id <id>
```

## Source code scanning (SAST)

Use `sast` to run Heeler's static analysis over the current repository or directory locally and report code-security findings (injection, taint data-flows, insecure configuration, and more). The scan engine is downloaded on demand for a logged-in user, checksum- and signature-verified, then cached; new engine versions roll out without a CLI upgrade.

```bash
heelercli sast [flags]
```

Important flags:

- `--fail-on critical,high,medium,low,info`: severities that fail the command (empty fails on any finding).
- `--repo-profile`: include repository profiling in the scan.
- `--exclude "<glob>"` / `--exclude-dir <path>`: exclude directories (glob patterns or paths, repeatable).
- `--path <dir>`: directory to scan (defaults to the enclosing git repository, or the current directory outside git).
- `--timeout <duration>`: maximum scan runtime before timing out (default `10m`).
- `--format detailed|table|json|sarif` and `--output <path>`: control output format and destination.

Exit behavior: `heelercli` returns `0` when no failing findings are found, and non-zero otherwise. Findings are ordered most-severe-first; failing findings are determined by `--fail-on`.

Git is optional: outside a git repository the current directory is scanned as-is, and the resolved scan root is printed to stderr. Use `--path` to target a specific directory. Requires `heelercli` 1.0.17 or newer.

Examples:

```bash
# fail the build on critical/high code findings
heelercli sast --fail-on critical,high

# SARIF for code-scanning upload, excluding generated code
heelercli sast --format sarif --output sast.sarif --exclude-dir generated
```

Requires a logged-in user (`heelercli login`); the scan engine is fetched from Heeler on first use.

## More commands

Each command needs a logged-in user (`heelercli login`) or `HEELER_API_KEY`. `secrets revoke`, `pentest import`, `iac export` and `dependency-check --fail-on` need `heelercli` 1.0.30 or later. Run `heelercli <command> --help` for every flag.

- `heelercli dependency-check <package> <exact-version> --package-ecosystem <ecosystem> [--fail-on reject,review,error]`: assess one exact package version before you add it. `--fail-on` lists the outcomes that exit `1` (default `reject`). See the [reference](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/reference/cli-command-reference#heelercli-dependency-check).
- `heelercli secrets revoke <finding-id>`: revoke a credential that Heeler validated as active, at its provider, through Heeler. Asks you to confirm unless you pass `--yes`. See the [reference](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/reference/cli-command-reference#heelercli-secrets-revoke).
- `heelercli pentest import <file>`: import a penetration test export (CSV, DefectDojo JSON or Heeler JSON) into an engagement. Use `--dry-run` to inspect the file first. See the [reference](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/reference/cli-command-reference#heelercli-pentest-import).
- `heelercli iac export`: after `terraform apply`, send the root's Terraform state manifest (resource addresses and identifiers only) to Heeler. Use `--dry-run` to print it without sending. See the [reference](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/reference/cli-command-reference#heelercli-iac-export).

## Supported platforms

| OS | Architecture | Archive format |
|----|-------------|----------------|
| Linux | amd64, arm64 | `.tgz` |
| macOS | amd64, arm64 | `.tgz` |
| Windows | amd64 | `.zip` |

## Current limitations and prerequisites

- Dependency scans of source need a Git repository. Outside Git, scan a CycloneDX SBOM with `--sbom <path>`.
- `--commit` needs `HEAD` to be pushed: reachable from a remote-tracking branch, or equal to `FETCH_HEAD`.
- `--exclude-dir` applies to `vulnerabilities`. `licenses`, `dependency-policy`, `detect-malicious-packages` and the dependency checks in `ci` use your organization's exclusions in Heeler.
- A scan that finds no dependency roots in scope exits `10`.

## Login and API key flow

`heelercli` authenticates to Heeler using a Heeler API key (Bearer token).

```bash
# save base URL only
heelercli login https://app.heeler.com

# save base URL and validate/save API key
heelercli login https://app.heeler.com <HEELER_API_KEY>
```

What this does:

- Saves config to your user config path (for example `~/.config/heeler/config.json` on Linux/macOS, or `%AppData%\heeler\config.json` on Windows).
- Stores the Heeler base URL and optional API key in that config file.
- When an API key is provided to `login`, the CLI validates it before saving.

Environment override:

- `HEELER_API_KEY` can be set in the environment and takes precedence over the config-file API key.

## Configuration

The auto-install hook supports a few environment variables:

- `HEELERCLI_VERSION`: Pin a specific release (for example `v1.0.0`). Defaults to `latest`.
- `HEELERCLI_CACHE_DIR`: Override the cache directory for the downloaded binary.
- `XDG_CACHE_HOME`: Used when `HEELERCLI_CACHE_DIR` is not set.

## Agent skills

This repository includes security-focused agent skills under `.agents/skills/` for workflows like:

- secrets scanning
- vulnerability scanning
- license checks
- malicious package scanning
- full scan orchestration
- repository security review
- task-specific security context and local policy guidance via [heeler-security-context](.agents/skills/heeler-security-context/SKILL.md)
- threat modeling: design builds, plan checks and review status, with decisions in the web app, via [heeler-threat-modeling](.agents/skills/heeler-threat-modeling/SKILL.md)

### Use skills from this repository directly

If you are running an agent from within this repository, skills are discovered from `.agents/skills/`.

### Install skills into another repository with dotagents

You can install these skills into other projects using [dotagents](https://github.com/getsentry/dotagents):

```bash
npx @sentry/dotagents init
npx @sentry/dotagents add Heeler-Security/heelercli --all
npx @sentry/dotagents install
```

Install selected skills only:

```bash
npx @sentry/dotagents add Heeler-Security/heelercli heeler-security-review heeler-scan-all
```

For reproducible installs in CI, use `npx @sentry/dotagents install --frozen`.

## Agent hooks

Agent hooks connect `heelercli` to the hook system of an AI coding agent. Before the agent installs a package or edits a dependency manifest, Heeler checks the exact version. With the secret check turned on, Heeler also scans for secrets when the agent commits or pushes. Notify is the default. In Block mode, only a complete, positive finding denies the action. When Heeler cannot check, the action runs with a notice, so the agent is never blocked.

Supported agents: Claude Code (`claude`), Codex CLI (`codex`), GitHub Copilot CLI (`copilot`), Cursor (`cursor`), Gemini CLI (`gemini`), Cline (`cline`), Augment Auggie (`auggie`), Kiro (`kiro`), Factory Droid (`droid`), JetBrains Junie CLI (`junie`), Antigravity CLI (`antigravity`), Devin CLI and Devin Local (`devin`), Amp (`amp`), OpenCode (`opencode`) and goose (`goose`).

Requires `heelercli` 1.0.30 or later.

```bash
heelercli hook <agent> install            # add the Heeler hook (Notify)
heelercli hook claude install --block     # deny known-bad packages
heelercli hook <agent> doctor             # check the installed hook
heelercli hook preflight                  # before an unattended run, check that hooks will check anything
heelercli hook codex trust                # trust the Heeler entries in Codex without /hooks
```

- `--block` denies a known-bad install or manifest edit. It is available for every supported agent, including Claude Code and Codex.
- `--use-path` writes the hook command as `heelercli` on `PATH` instead of this binary's absolute path, for hook files committed to a repository or built into an image. Available for Claude Code, Codex CLI, GitHub Copilot CLI, Cursor and Gemini CLI, not for native Windows hooks. The first `heelercli` on the agent's `PATH` runs.
- `heelercli hook codex trust` supports Codex 0.164.x and is not available on native Windows; there, open `/hooks` in Codex and trust the entries.
- After you upgrade `heelercli`, run `heelercli hook <agent> install` again with your usual options.

See [Agent Hooks](https://docs.heeler.com/mrecEO40m5D6bt7Pq5pE/prevent/agent-hooks) for scopes, options and per-agent behavior.

## What it scans

The secret scanner inspects staged diffs, common secret formats, and validates where possible to reduce false positives. Support is growing quickly; the list below reflects current coverage.

<details>
<summary>Supported secret types (current)</summary>

- adafruitio
- adobe
- age
- ai21
- airbrake
- airtable
- aiven
- alchemy
- algolia
- alibaba
- anthropic
- anypoint
- apify
- apollo
- artifactory
- asana
- assemblyai
- atlassian
- auth0
- authress
- aws
- azure
- azuredevops
- azureopenai
- azuresearchquery
- azurestorage
- baremetrics
- baseten
- beamer
- bitbucket
- bitly
- blynk
- buildkite
- cerebras
- circleci
- ciscomeraki
- clarifai
- clay
- clearbit
- clickhouse
- clojars
- cloudflare
- cloudsight
- codacy
- codeclimate
- codecov
- coderabbit
- cohere
- coinbase
- confluent
- contentful
- coveralls
- coze
- crates.io
- credentials
- curl
- cursor
- customerio
- databricks
- datadog
- datagov
- deepgram
- deepseek
- definednetworking
- dependency_track
- diffbot
- digitalocean
- discord
- disqus
- django
- docker
- dockerhub
- doppler
- droneci
- dropbox
- duffel
- dynatrace
- easypost
- elevenlabs
- endorlabs
- eraserio
- eventbrite
- exaai
- facebook
- fastly
- figma
- fileio
- filezilla
- finicity
- finnhub
- firecrawl
- fireworksai
- fleetbase
- flickr
- flyio
- foursquare
- frameio
- freshbooks
- freshdesk
- friendli
- gcp
- generic
- gitalk
- github
- gitlab
- gitter
- gocardless
- google
- googleoauth2
- gradle
- grafana
- groq
- guardian
- gumroad
- harness
- hashes
- hashicorp
- hereapi
- heroku
- honeycomb
- http
- hubspot
- huggingface
- ibm
- imagekit
- infracost
- infura
- instantly
- intercom
- intra42
- ionic
- ipstack
- jdbc
- jenkins
- jina
- jira
- jotform
- jumpcloud
- jwt
- kagi
- kickbox
- klaviyo
- klingai
- langchain
- lark
- launchdarkly
- line
- linear
- linkedin
- lob
- looker
- mailchimp
- mailgun
- mailjet
- mandrill
- mapbox
- mattermost
- maxmind
- mergify
- messagebird
- microsoft_teams
- microsoftteamswebhook
- mistral
- monday
- mongodb
- mysql
- nasa
- netlify
- netrc
- newrelic
- ngrok
- notion
- npm
- nuget
- nvidia
- nylas
- nytimes
- odbc
- okta
- ollama
- onepassword
- openai
- openrouter
- openweathermap
- opsgenie
- optimizely
- owlbot
- packagecloud
- pagerdutyapikey
- particle.io
- pastebin
- paypal
- paystack
- pdflayer
- pem
- perplexity
- phpmailer
- plaid
- planetscale
- postgres
- posthog
- postman
- postmark
- prefect
- privkey
- psexec
- pubnub
- pulumi
- pypi
- rabbitmq
- rapidapi
- react
- readme
- recaptcha
- replicate
- resend
- retellai
- riot
- rubygems
- runway
- salesforce
- sauce
- scale
- scalingo
- scraperapi
- segment
- sendbird
- sendgrid
- sendinblue
- sentry
- shippo
- shodan
- shopify
- slack
- snyk
- sonarcloud
- sonarqube
- sourcegraph
- square
- sslmate
- stabilityai
- stackhawk
- statuspage
- stripe
- supabase
- tailscale
- tavily
- teamcity
- telegram
- thingsboard
- togetherai
- travisci
- truenas
- twilio
- twitch
- twitter
- typeform
- uri
- vastai
- vercel
- vmware
- voyageai
- weightsandbiases
- wireguard
- xAI
- yandex
- yelp
- youtube
- zhipu
- zohocrm
- zuplo

</details>

## Releases

Release artifacts are published on GitHub Releases for the `heelercli` project. The auto-install hook fetches the correct archive from:

```
https://github.com/Heeler-Security/heelercli/releases
```

The hook verifies each downloaded archive against its published `.sha256` sidecar before installing it, and refuses to install on a mismatch.

## Verifying downloaded binaries

Each release includes `.sha256` checksum files and `.bundle` cosign signature files alongside every binary archive. You can use these to verify that your download is authentic and untampered.

### Checksum verification

Download the archive and its matching `.sha256` file, then run:

**Linux:**

```bash
sha256sum -c heelercli-linux-amd64.tgz.sha256
```

**macOS:**

```bash
shasum -a 256 -c heelercli-darwin-arm64.tgz.sha256
```

**Windows (Git Bash):**

```bash
sha256sum -c heelercli-windows-amd64.zip.sha256
```

**Windows (PowerShell):**

```powershell
$expected = (Get-Content heelercli-windows-amd64.zip.sha256).Split(" ")[0]
$actual = (Get-FileHash heelercli-windows-amd64.zip -Algorithm SHA256).Hash.ToLower()
if ($actual -eq $expected) { "OK" } else { "MISMATCH" }
```

### Signature verification

Signature verification uses [cosign](https://docs.sigstore.dev/cosign/system_config/installation/) and confirms the binary was built by the official CI pipeline. Download the archive and its matching `.bundle` file, then run:

```bash
cosign verify-blob \
  --bundle heelercli-linux-amd64.tgz.bundle \
  --certificate-identity-regexp '^https://github\.com/heelerai/heeler-cli/\.github/workflows/release\.yml@refs/tags/.*$' \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  heelercli-linux-amd64.tgz
```

Replace the file names with the archive and bundle for your platform. The `--certificate-identity-regexp` pattern matches the source repository workflow for any release tag, confirming the binary was produced by an official release build.

The regexp form above is the recommended one. To pin verification to one exact release instead, use `--certificate-identity` with the full tag. It is an exact string match, not a pattern, so no wildcard is accepted. Set `TAG` to the version you downloaded:

```bash
TAG=2.0.0   # the version you downloaded
cosign verify-blob \
  --bundle heelercli-linux-amd64.tgz.bundle \
  --certificate-identity "https://github.com/heelerai/heeler-cli/.github/workflows/release.yml@refs/tags/${TAG}" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  heelercli-linux-amd64.tgz
```

## Support

If you need help, reach out to Heeler Security support or open an issue in this repository.
