---
name: heeler-threat-modeling
description: Threat-model with Heeler. Start a design-model build from design documents, import an existing threat model, check an implementation plan against a system's model, list what applies to the code you're changing, report review status with the web-app link, or build a local threat-modeling prompt from service context. Never approves or applies anything.
---

# Heeler Threat Modeling

Use this skill to start design threat-modeling work in Heeler, report its state, and hand off the
web-app link where a person decides. It can also build a local PASTA or STRIDE prompt from service
context (Flow E). Every decision on a design model is made by a person in the Heeler web app.

## Choose a flow

| The user asks… | Flow |
|---|---|
| "model this design", "threat model this design doc/spec/RFC", "build a threat model from these docs", "start a design review" | A. Model this design |
| "import my existing threat model", "import this .tm7 / Threat Dragon / pytm file" | A2. Import a threat model |
| "check my plan", "threat-model this plan / this change", "what threats does this plan introduce", "review my implementation plan against the threat model" | B. Check my plan |
| "what applies to this code", "what threat-model requirements apply here", "what should I watch for before changing this", "open claims / violated requirements for this service" | C. What applies to this code |
| "status of my threat model review", "is the build done", "what happened to review `<id>`" | D. Status reporting |
| "gather threat model context for a service", "threat modeling context export from Heeler APIs", "an LLM-ready threat modeling prompt" | E. Local context and prompt |

- When a request matches more than one flow, ask one question to choose.
- Never run A or B for an ambiguous request such as "threat model this repo". Run E, as before, and
  offer A in one line: "I can also start a design-model build in Heeler from your design documents."
- Flow D runs automatically after A, A2 and B.

### Interface

- Use the CLI when `heelercli` is installed at the minimum version or newer (Preflight). It supports
  files and PDFs, `--application` targeting and `--wait`.
- Otherwise, use the Heeler MCP tools when they are listed.
- With neither available, say what to install (`heelercli`, see the repository README) or connect
  (the Heeler MCP server), and stop.

### Targets (A, A2, B, D)

- Accept a system (`--system <design-model-id>`), an application (`--application <application-id>`),
  or a Heeler link the id can be read from:
  - `/threat-model/systems/<id>` gives a system;
  - `/threat-model/design-models/<m>/reviews/<r>` gives a system and a review.
- If the user supplies no target, ask for one. Never guess, never use a Service id or
  `.heeler.yaml`, and never swap one kind of id for the other.
- MCP writes take a `design_model_id` (or `new_system` on a build), never an `application_id`.

## Preflight

For every flow:

1. Confirm the CLI is available: `heelercli --version`. Parse the `X.Y.Z` version.
2. Confirm auth context is available: the `HEELER_API_KEY` environment variable, or a valid local
   login. On exit 3, say "Log in with `heelercli login`, or set `HEELER_API_KEY`." and stop.

For Flows A–D, also:

3. **Version:** these flows need heelercli `1.0.30` or newer. Below it, say "Flows A–D need
   heelercli `1.0.30` or newer; you have `<version>`.", give the install or upgrade line from the
   repository README, and fall back to MCP if its tools are listed. Flow E still works. A
   `development` build, or a version that doesn't parse, gets a warning, and the flow continues.
4. **Feature and role**, learned from the first call. There is no extra probe.
   - Exit 4 whose detail contains `THREAT_MODEL feature is not enabled`: "Design threat modeling
     isn't enabled for this Heeler tenant. An administrator can enable it." Stop, and offer Flow E.
   - Exit 4 with "Run `heelercli login` again to grant threat-model write access.": relay it and stop.
   - Any other exit 4: "You need contributor access on this system." For a read: "You need read
     access on this system." Give the system link if known. Stop.
   - MCP tools absent from `tools/list`: "This Heeler connection doesn't offer design threat
     modeling: the feature is off, or the server is older." Stop.
   - MCP `not_found`: "Not found, or the feature is off." Stop.

## Flow A. Model this design

Inputs:

- a target;
- documents: `.txt`, `.md`, `.markdown` or `.pdf` files (at most 10), or text the user pastes,
  which the skill writes to `.heeler/tm-design-<n>.md` and sends as a text document;
- optional lenses: `stride`, `pasta`, `linddun`, `maestro` or `none`.

**Consent:** the upload leaves the machine. Before sending anything, list the files and the target
that will be sent, and wait for a yes.

CLI (an existing system):

- `heelercli threat-model build --system <design-model-id> --file <path> --text <path> --lens <lens>`
- `heelercli threat-model build --application <application-id> --file <path>`

Repeat `--file`, `--text` and `--lens` as needed. Never add `--wait` to the build call, so it
returns quickly; Flow D follows.

MCP: `threat_model_build` with `design_model_id`, `documents` (each file's `title` and `text`),
optional `lenses`, and an `idempotency_key` made once per request: `skill-` followed by 32
hexadecimal characters. PDFs can't be sent over MCP: say "Use the CLI for PDFs." and don't extract
the text yourself.

**No target system yet:** call `threat_model_build` over MCP with `new_system {name, owner_team_id}`,
only when the user names both. The CLI has no new-system option. A 403 there means the user's role
can't create systems: report that and point to the web app (Threat Model → Systems). Without MCP,
say "Create the system in Heeler, then give me its link."

**Report** the review id, the state, and the workspace link exactly as the CLI or tool printed it
(never a link the skill builds), then this line: "A person reviews and decides the proposed model in
Heeler at that link." Then run Flow D.

## Flow A2. Import a threat model

Inputs: a target and one file: a Microsoft Threat Modeling Tool `.tm7` file, or a Threat Dragon,
pytm, OWASP TML or components `.json` or `.csv` file. A Heeler JSON export can't be imported.

**Consent:** as in Flow A, name the file and the target, and wait for a yes.

CLI:

- `heelercli threat-model import <path> --system <design-model-id>`
- `heelercli threat-model import <path> --application <application-id> --input-format <format>`

Without `--input-format` the server detects the format. When the CLI reports the format as
ambiguous or mismatched, ask the user which format it is (`tm7`, `threat-dragon`, `pytm`,
`owasp-tml` or `components`) and re-run with `--input-format`, reusing the operation id the CLI
printed if it printed one.

The import opens a review holding the change set; nothing is queued. **Report** the review id and
the workspace link as printed, then: "A person reviews and applies the import in Heeler at that
link." There is no MCP import tool.

## Flow B. Check my plan

Inputs:

- a target;
- the plan: a file the user names, or the agent's current plan written to `.heeler/tm-plan.md`.
  **Show the plan text to the user and wait for a yes before sending it.** At most 200,000
  characters.

CLI:

- `heelercli threat-model propose --system <design-model-id> --plan <path>`
- `heelercli threat-model propose --application <application-id> --plan <path> --lens <lens>`

`--plan -` reads the plan from stdin.

MCP: `threat_model_propose_change` with `design_model_id`, `plan` and an `idempotency_key` made as
in Flow A.

**Report** as in Flow A, then run Flow D. When generation finishes, report the counts and threat
titles that `status` and `show --draft` print:

- `heelercli threat-model show --system <design-model-id> --draft`

Don't rate them, and never say the plan is "safe" or "approved".

## Flow C. What applies to this code

Inputs: a target path (default `.`); an optional one-line task description (MCP only).

CLI:

- `heelercli threat-model claims --path <target-path> --format json -q`
- `heelercli threat-model assertions --path <target-path> --status violated --format json -q`
- Only when the user gives a system: `heelercli threat-model show --system <design-model-id> --requirements`

`claims` and `assertions` resolve a Service from the path. Exit 1 **with a JSON body on stdout** is
the advisory "matches found" result (an open high or critical claim, or a violated requirement),
not a failure. Exit 1 with no body is a failure.

If the Service can't be resolved, use the missing service_id handling under Flow E and re-run with
the value the user gives:

- `heelercli threat-model claims --service-id <service-id> --format json -q`
- `heelercli threat-model assertions --service-id <service-id> --status violated --format json -q`

MCP: the `secure_development_checklist` prompt with the repository and `task`, then
`threat_model_claims` and `security_assertions` for detail.

**Report** design requirements, open claims and violated requirements, with their ids, labelled
"current". Never mark a claim accepted or dismissed. Disputes go to the web app.

## Flow D. Status reporting

Inputs: a review id plus its target, from the earlier output or from a review link.

CLI:

- `heelercli threat-model status <review-id> --system <design-model-id>`
- To follow progress: `heelercli threat-model status <review-id> --system <design-model-id> --wait --timeout <duration>`,
  with a timeout that fits your own command limit (for example `2m`). `--wait` waits for
  generation, never for a person's decision.
- For the model as a whole: `heelercli threat-model show --system <design-model-id>`
- With an application target: `heelercli threat-model status <review-id> --application <application-id>`

On exit 6, say "Still generating." and re-run only if the user wants to keep waiting.

MCP: `threat_model_job_status` with `review_id`; `threat_model_get` for the model summary.

| State | Message |
|---|---|
| `queued` | Still generating. |
| `open` | Ready for a person to review at the link. |
| `needs_mapping` | A person must map elements at the link. |
| `unavailable` | Generation failed: `<failure_reason>`. |
| `approved` / `rejected` | Decided by `<a person>` in Heeler (reported, never inferred). |
| `superseded` / `cancelled` | Closed without a decision. |

Report any other state verbatim, and add "Update heelercli to read this state."

## Flow E. Local context and prompt

Flow E needs only the CLI and a Service mapping; it doesn't need the THREAT_MODEL feature or the
Flow A–D minimum version. Use it when the user asks for threat model context or an LLM-ready PASTA
or STRIDE prompt.

### Flow E steps

Execute these steps in order unless the user explicitly narrows scope:

1. Resolve service id for target path:
   - `heelercli threat-model resolve-service-id --path <target-path> -q`
2. Fetch context export:
   - `heelercli threat-model context --path <target-path> --format json --output .heeler/tm-context.json -q`
3. Build prompt artifact:
   - `heelercli threat-model prompt --path <target-path> --framework <PASTA|STRIDE> --format markdown --output .heeler/tm-prompt.md -q`

4. Generate the threat model from that prompt file:
   - Use `.heeler/tm-prompt.md` as the authoritative prompt input.
   - Do not reconstruct or paraphrase the prompt from memory.
   - If the runtime model/tool cannot read files directly, copy the prompt content exactly.

### Command defaults

- Framework default: `PASTA`.
- Keep `--redact-secrets` enabled unless user requests otherwise.
- If no service id mapping is found, ask for `--service-id` and include exact config snippet needed.

### Missing service_id handling

If `service_id` is not explicitly provided and `heelercli threat-model resolve-service-id` cannot resolve one from repository context, the skill must pause and ask the user for a service id.

Required behavior:

1. Report that service id resolution failed.
2. Ask one targeted question requesting a concrete `service_id` value.
3. Include a ready-to-run command example using the provided value:
   - `heelercli threat-model prompt --service-id <service-id> --framework <PASTA|STRIDE> --format markdown --output .heeler/tm-prompt.md -q`
4. Do not continue threat-model context/prompt generation until the user provides a service id.

### Expected outputs

- `tm-context.json`: raw context export for auditability.
- `tm-prompt.md`: structured prompt ready for an LLM.

### Prompt quality requirements

The generated prompt should include:

1. Service summary and deployment scope.
2. Trust boundaries and service connections.
3. Prioritized vulnerabilities, SAST, and secret signal summaries.
4. Framework-specific instructions (PASTA or STRIDE).
5. Required output format with threat register table and top actions.

### Model-generation requirement

- The generated threat model must be based on the prompt produced by `heelercli threat-model prompt`.
- Treat CLI prompt generation as the source of truth for context assembly and redaction.

### Analyst follow-up requirement

After producing the initial threat model, ask the user one targeted follow-up question:

- `Do you want me to validate the top findings against repository evidence to confirm/deny likely false positives?`

Recommended default if user is unsure:

- Validate the top 5 highest-impact findings first.

If user says yes, perform a second pass that:

1. Confirms each finding with concrete entry point and evidence path.
2. Marks findings as `confirmed`, `likely`, or `not supported`.
3. Revises priority based on confirmation status.

### Failure behavior

- 404: report missing service id or unavailable context for the service/deployment.
- 422: report invalid framework/deployment input.
- Any API failure: include command and concise remediation hint.

Never claim success if context export or prompt generation failed.

## Exit codes and messages (A–D)

| Exit | Message | Action |
|---|---|---|
| 0 | the result | Report it. |
| 1 with "already used for a different request" | "That operation id was used for a different request." | Stop. Never retry with a new id silently. |
| 1, other | the CLI's message | Stop (but see Flow C for advisory exit 1). |
| 2 | the CLI's usage message, which names any limit | Fix the input when the cause is obvious (a placeholder left in, a wrong flag); otherwise ask. |
| 3 / 4 | the Preflight messages | Stop. |
| 5 | "Generation failed: `<failure_reason>`." | Stop; offer to start a new build. |
| 6 | "Still generating." | Ask whether to keep waiting. |
| 7 | "Network error." | Follow the retry rule. |
| 8 | "Not found, or no version yet." | Stop; check the id with the user. |
| 9 | "Heeler is busy; retry later." | Stop; retry only when the user asks. |

**Retry rule (writes only: build, import, propose):**

- When stderr says the request "used operation id `<id>`" (exit 7, or exit 1 after an HTTP 5xx),
  re-run the **identical** command once, adding `--operation-id <id>`. For example:
  `heelercli threat-model build --system <design-model-id> --file <path> --operation-id <operation-id>`
- A second ambiguous failure is reported with the id, so the user can retry later.
- Never re-run a write without that id: a fresh run starts a second review.
- MCP: after a transport error, a timeout or an unconfirmed outcome, call once more with the
  **same** `idempotency_key` and identical arguments.

## What this skill never does

- It never approves, rejects, applies, rebases, requires, defers, dismisses or rates anything. No
  such command or tool exists for it.
- It never says a design or plan is safe or approved, unless it is reporting a decision a person
  made.
- It always hands off the web link the CLI or tool returned.
- It never builds or guesses ids or links, and never falls back to a Service id for A, A2, B or D.
- It never retries a write without the original operation id or idempotency key.
- It never generates its own threat model in A–D. That is Flow E only.

## Heeler MCP context

If the Heeler MCP server is connected, pair this skill with stored platform context: pull `get_endpoint_security_context_for_project` for existing auth patterns, `get_vulnerabilities_for_project` for active dependency findings, and the `secure_development_checklist` prompt before writing new code. MCP tools reflect the last platform scan of committed code; this skill covers the working tree that scan cannot see.

The design threat-model tools are `threat_model_get`, `threat_model_job_status`,
`threat_model_report`, `threat_model_build` and `threat_model_propose_change`. The
`secure_development_checklist` prompt also takes a `task` argument, a one-line description of the
change, to list the design requirements that apply to it.
