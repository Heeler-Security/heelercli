---
name: heeler-threat-modeling
description: Resolve a service id, gather threat model context, and build a concrete prompt for threat modeling workflows.
---

# Heeler Threat Modeling

Use this skill when a user asks to gather threat model context and produce a concrete prompt for PASTA or STRIDE analysis.

## Trigger cues

- User asks for threat modeling context export from Heeler APIs.
- User asks to gather threat model context for a service.
- User asks for an LLM-ready threat modeling prompt.

## Preflight

Before running any command:

1. Confirm CLI is available: `heelercli --version`
2. Confirm auth context is available:
   - `HEELER_API_KEY` environment variable, or
   - valid local login config.

If authentication fails, return clear login instructions and stop.

## Required command workflow

Always execute these steps in order unless the user explicitly narrows scope:

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

## Command defaults

- Framework default: `PASTA`.
- Keep `--redact-secrets` enabled unless user requests otherwise.
- If no service id mapping is found, ask for `--service-id` and include exact config snippet needed.

## Missing service_id handling

If `service_id` is not explicitly provided and `heelercli threat-model resolve-service-id` cannot resolve one from repository context, the skill must pause and ask the user for a service id.

Required behavior:

1. Report that service id resolution failed.
2. Ask one targeted question requesting a concrete `service_id` value.
3. Include a ready-to-run command example using the provided value:
   - `heelercli threat-model prompt --service-id <service-id> --framework <PASTA|STRIDE> --format markdown --output .heeler/tm-prompt.md -q`
4. Do not continue threat-model context/prompt generation until the user provides a service id.

## Expected outputs

- `tm-context.json`: raw context export for auditability.
- `tm-prompt.md`: structured prompt ready for an LLM.

## Prompt quality requirements

The generated prompt should include:

1. Service summary and deployment scope.
2. Trust boundaries and service connections.
3. Prioritized vulnerabilities, SAST, and secret signal summaries.
4. Framework-specific instructions (PASTA or STRIDE).
5. Required output format with threat register table and top actions.

## Model-generation requirement

- The generated threat model must be based on the prompt produced by `heelercli threat-model prompt`.
- Treat CLI prompt generation as the source of truth for context assembly and redaction.

## Analyst follow-up requirement

After producing the initial threat model, ask the user one targeted follow-up question:

- `Do you want me to validate the top findings against repository evidence to confirm/deny likely false positives?`

Recommended default if user is unsure:

- Validate the top 5 highest-impact findings first.

If user says yes, perform a second pass that:

1. Confirms each finding with concrete entry point and evidence path.
2. Marks findings as `confirmed`, `likely`, or `not supported`.
3. Revises priority based on confirmation status.

## Failure behavior

- 404: report missing service id or unavailable context for the service/deployment.
- 422: report invalid framework/deployment input.
- Any API failure: include command and concise remediation hint.

Never claim success if context export or prompt generation failed.
