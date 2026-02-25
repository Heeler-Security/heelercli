# Heeler Security CLI

This repository hosts release artifacts for `heelercli` and provides pre-commit hooks for local and CI security checks. The CLI currently supports secret scanning plus dependency vulnerability and SBOM workflows for Go and Java (Maven), with additional language support coming soon.

## Quick start (recommended)

Add the auto-install hook to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/Heeler-Security/heelercli
    rev: 1.0.0 # replace with a release tag
    hooks:
      - id: heelercli-auto
```

This hook downloads the correct `heelercli` binary for your OS/arch on first run and reuses the cached binary on subsequent runs. It scans all staged changes for secrets and fails the commit when a secret is detected.

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
    rev: 1.0.0 # replace with a release tag
    hooks:
      - id: heelercli
```

This runs:

```bash
heelercli secrets --pre-commit
```

## Secrets command options

```text
heelercli secrets [flags]

  --exclude strings   (repeatable) directories to exclude as glob patterns (similar to .gitignore)
  --fail-on strings   comma-separated list of types to fail on
  --only-validated    filter to only show validated items
  --pre-commit        enable pre-commit mode
```

Exit behavior: `heelercli` returns `0` when no failing secrets are found, and non-zero otherwise. Failing secrets are determined by `--fail-on` and `--only-validated`.

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

The Go `heeler-cli` includes dependency analysis commands that are now available in `heelercli` releases as well.

### Vulnerability scan

Use `vulnerabilities` to auto-discover dependency manifests, generate SBOMs, submit them to Heeler, and evaluate policy-based failures.

```bash
heelercli vulnerabilities [flags]
```

Important flags:

- `--fail-on-any`: fail if any vulnerability is found.
- `--fail-on-severity critical,high`: fail on selected severities.
- `--fail-on-id CVE-2024-1234,GHSA-xxxx-yyyy-zzzz`: fail on specific IDs.
- `--exclude-dir path/to/dir`: exclude directories from manifest/SBOM detection (repeatable).
- `--baseline <path>` and `--new-findings-only`: only fail on findings not present in a baseline report.
- `--format detailed|table|json|sarif` and `--output <path>`: control output format and destination.

Examples:

```bash
# fail on critical/high only
heelercli vulnerabilities --fail-on-severity critical,high

# regression mode in CI (new issues only)
heelercli vulnerabilities --baseline .heeler-baseline-vulns.json --new-findings-only
```

### SBOM assessment

Use `assess-sbom` to assess an existing CycloneDX JSON SBOM file.

```bash
heelercli assess-sbom --sbom ./sbom.json [flags]
```

Important flags:

- `--sbom <path>`: path to a CycloneDX JSON SBOM file.
- `--format detailed|table|json|sarif`: choose output format.
- `--output <path>`: write output to file.

Notes:

- `--sbom_file` is deprecated; use `--sbom`.

### SBOM download (platform SBOM)

```bash
# exactly one of the two flags is required
heelercli download-sbom --service_id <id>
heelercli download-sbom --application_id <id>
```

## Supported platforms

| OS | Architecture | Archive format |
|----|-------------|----------------|
| Linux | amd64, arm64 | `.tgz` |
| macOS | arm64 | `.tgz` |
| Windows | amd64 | `.zip` |

## Current limitations and prerequisites

- Dependency detection for vulnerability/SBOM workflows currently supports Go and Java (Maven projects).
- Go detection scans `go.mod` files and requires a working Go toolchain (`go`) on the machine running the CLI.
- Java detection scans `pom.xml` files and requires Maven (`mvn`) and a usable Java toolchain on the machine running the CLI.
- If required toolchains are missing, SBOM generation for that manifest fails and those results are incomplete.

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
  --certificate-identity "https://github.com/heelerai/heeler-cli/.github/workflows/release.yml@refs/tags/*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  heelercli-linux-amd64.tgz
```

Replace the file names with the archive and bundle for your platform. The `--certificate-identity` pattern matches the source repository workflow, confirming the binary was produced by an official release build.

## Support

If you need help, reach out to Heeler Security support or open an issue in this repository.
