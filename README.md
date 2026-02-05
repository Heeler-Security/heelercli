# Heeler Security CLI (pre-commit hooks)

This repository hosts the release artifacts for `heelercli` and provides pre-commit hooks to block secrets before they land in git history. Today the CLI focuses on secret scanning with validation; dependency and SAST scanning are on the roadmap.

## Quick start (recommended)

Add the auto-install hook to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/Heeler-Security/heeler-cli
    rev: v0.0.0 # replace with a release tag
    hooks:
      - id: heelercli-auto
```

This hook downloads the correct `heelercli` binary for your OS/arch on first run and reuses the cached binary on subsequent runs. It scans all staged changes for secrets and fails the commit when a secret is detected.

## Using a locally installed CLI

If you already install `heelercli` separately, use the system hook:

```yaml
repos:
  - repo: https://github.com/Heeler-Security/heeler-cli
    rev: v0.0.0 # replace with a release tag
    hooks:
      - id: heelercli
```

This runs:

```bash
heelercli secrets --pre-commit
```

## CLI options

```text
heelercli secrets [flags]

  --exclude strings   (repeatable) directories to exclude as glob patterns (similar to .gitignore)
  --fail-on strings   comma-separated list of types to fail on
  --only-validated    filter to only show validated items
  --pre-commit        enable pre-commit mode
```

Exit behavior: `heelercli` returns `0` when no failing secrets are found, and non-zero otherwise. Failing secrets are determined by `--fail-on` and `--only-validated`.

## Examples

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

## Support

If you need help, reach out to Heeler Security support or open an issue in this repository.
