# AgentNest · 智巢

**Set up your AI coding assistants in a few clicks.**

English · [简体中文](README.md)

AgentNest is a bilingual Windows configuration assistant for AI coding clients and model providers.
It installs supported clients, keeps separate configuration profiles, and launches the selected profile.
Current version: 0.4.0. Requires Windows x64 and Windows PowerShell 5.1 for the launcher.

## Quick start

1. Download the repository ZIP and extract the entire folder.
2. Double-click `Agent-Assistant.cmd`.
3. Choose a client and provider, enter a model ID and your own API key, then select **Configure & install**.
4. Use **Test connection** and **Launch client** when ready.

Use **Save profile only** to save settings without installing software. Switch between English and
Simplified Chinese in the top-right menu. Detailed instructions: [English help](assistant/README.en.txt).

## Supported clients

| Client | Provider protocol |
| --- | --- |
| Codex / ChatGPT desktop | Responses: DeepSeek, OpenAI, custom endpoints |
| Claude Code CLI | Messages: DeepSeek, Anthropic, supported Bailian / Zhipu presets, custom endpoints |
| OpenCode 1 CLI | Chat Completions: supported cloud providers, Ollama, LM Studio, custom endpoints |
| Aider CLI | Chat Completions: same provider presets as OpenCode |

The catalog includes four clients and seventeen provider, region, plan, local-server and custom presets.
Providers are filtered by protocol. Model availability and client compatibility depend on the selected
service; a basic chat check does not validate tool calls, streaming or multi-turn conversations.

## Share profiles without credentials

**Export without key** creates an `.agent-profile.json` file containing only format version, profile ID,
client, provider, model and endpoint. It excludes plaintext and encrypted keys, raw client configuration,
model catalogs, sessions and local file paths. Review the endpoint itself before sharing.

**Import profile** loads a draft without installing software or overwriting an existing profile.
Existing profile IDs receive a suffix. The recipient reviews the endpoint and enters their own key.
Custom Codex profiles require a trusted `models.json` selected separately after import.

## Local models

Start Ollama or LM Studio yourself, download/load a model and enable its local API server. Select
OpenCode or Aider, choose the local provider, then click **List local models** or enter the model ID.

| Server | Default endpoint |
| --- | --- |
| Ollama | `http://127.0.0.1:11434/v1` |
| LM Studio | `http://127.0.0.1:1234/v1` |

Ports are editable. Local presets accept `localhost`, `127.0.0.1` and `::1` only.
Leave the key blank for unauthenticated servers; enter a token when server authentication is enabled.
For local profiles, saving a blank key removes a previously saved token, with an automatic backup.
Model discovery uses the token currently entered in the UI, not a previously saved token.

AgentNest connects to existing servers; it does not install model servers or download models.
Local presets currently support OpenCode/Aider. Select a downloaded local model for local inference;
a local server can also expose cloud models.

## Profiles and credentials

Profiles are stored under `%LOCALAPPDATA%\AgentSetupAssistant` by default. Credentials use Windows DPAPI
and are supplied to child processes at runtime. Existing global client configuration and system/user
environment variables are preserved. Launch clients through AgentNest to select the profile.
Backups include encrypted credentials and are intended for local recovery, not sharing.

Installer and device policies can still require administrator assistance. AgentNest does not bypass UAC
or client tool permissions. It manages client configuration rather than scheduling work across agents.

## Development

Run the isolated test suite in Windows PowerShell:

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Test-Assistant.ps1
```

Build the online distribution:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Assistant.ps1
```

The optional `-IncludeCodexInstaller` build requires the exact verified `Codex-x64.msix` and
`Codex-License.xml` in local `lab/payload/`. These third-party installer files are not included in the
repository. The `distribution/` directory contains the older Codex + DeepSeek scripts for reference.

Automated tests use temporary evidence directories, fake credentials, mocked HTTP and fixture
executables. They do not start a VM, install real clients or call paid APIs. Real client/server
end-to-end compatibility still needs manual verification.

## References

- [Ollama OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility)
- [LM Studio OpenAI compatibility](https://lmstudio.ai/docs/developer/openai-compat)
- [LM Studio authentication](https://lmstudio.ai/docs/developer/core/authentication)
- [Client/provider source references](assistant/catalog.json)
