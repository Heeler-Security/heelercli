# Client setup and verification

Connect remote MCP for stored platform evidence; install skills separately for CLI workflows on selected local files. Neither proves sensor visibility or enforcement. Use the intended tenant and environment. The examples below target production; use a different endpoint only when explicitly intended. Never paste API keys into these files.

## Setup recipes

### Codex

Merge [codex.toml](clients/codex.toml) into the existing Codex configuration without replacing other settings, or use:

```bash
codex mcp add heeler --url https://app.heeler.com/mcp
```

Complete the OAuth sign-in shown by the client. If it does not start, use `codex mcp login heeler`; inspect `/mcp` in the agent session. Grant only the needed scopes. Configuration presence is not proof that a tool call works.

Copy only the selected, reviewed skill directory from the pinned bundle into the project's `.agents/skills/`. Preserve other installed skills. Confirm it appears in the client's skill selector; restart if needed. Then explicitly invoke that skill on an authorized fixture. [Official MCP configuration](https://developers.openai.com/codex/mcp) · [official skill discovery](https://developers.openai.com/codex/skills).

### Claude Code

From the intended project, use:

```bash
claude mcp add --transport http --scope project heeler https://app.heeler.com/mcp
```

Alternatively merge [claude-code.json](clients/claude-code.json) into `.mcp.json`. In Claude Code, use `/mcp` to authenticate and inspect the connection. Review shared project configuration before allowing it.

Copy a selected, reviewed skill directory into `.claude/skills/` and invoke `/heeler-<skill-name>` using its actual name. Do not assume copying into `.agents/skills/` alone installs it for every client. [Official MCP setup](https://code.claude.com/docs/en/mcp) · [official skills setup](https://code.claude.com/docs/en/skills).

### VS Code / GitHub Copilot

Merge [vscode.json](clients/vscode.json) into workspace `.vscode/mcp.json`. Use **MCP: List Servers**, start Heeler, and complete OAuth if prompted. Check that the agent can select and call an authorized read tool. This recipe does not establish skill, sensor or enforcement support. [Official configuration reference](https://code.visualstudio.com/docs/agents/reference/mcp-configuration).

## Evidence, not a single “supported client” count

| Client | Configuration check | MCP authentication + tool call | Skill discovery + task | Sensor activity | Enforcement |
| --- | --- | --- | --- | --- | --- |
| Codex CLI 0.157.1 | URL option/configuration checked locally, 2026-09-29 | Unverified in this release check | Unverified in this release check | Not tested | Not tested |
| Claude Code 2.1.284 | HTTP/project option checked locally, 2026-09-29 | Unverified in this release check | Unverified in this release check | Not tested | Not tested |
| VS Code / Copilot | JSON recipe checked against linked official docs, 2026-09-29; client version not tested | Unverified | Unverified | Not tested | Not tested |

These are setup recipes, not completed compatibility certifications. No live account is needed for the bundle's metadata/CLI-help checks. Real client acceptance needs authorized access and a fixture; no test may change a role, tenant, login, or product data merely to fill this table.

For each verified support level, retain client version, OS, validation date, bundle commit, CLI version, environment/role, exact action, and sanitized evidence. For MCP, confirm identity and make one advertised read call against a known fixture. For skills, verify discovery, invocation and the expected result, including a denied/error case. Heeler's agent-file skill uploads content and requires explicit consent. Sensor evidence must show the specific client/session; enforcement must name an intercepted event and demonstrate denial plus limitations. Leave missing levels unverified rather than infer them from another column.
