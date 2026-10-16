AgentNest 0.4 (Windows x64)

Getting started
Extract the entire ZIP and double-click Agent-Assistant.cmd.
Use the top-right menu to switch between Simplified Chinese and English.
The assistant remembers your selection in preferences.json in its data directory.
English is the default on first use, regardless of the Windows display language.
Switching languages preserves unsaved fields and the selected client and provider.
The assistant translates its own interface, new messages and help. Existing log entries
keep their original language. Windows dialogs, installers and client apps use their own languages.

Choose a client and provider, enter a model ID and API key, then click Configure & install.
This saves an independent profile before installing the selected client. If installation
fails, use Check / install to retry. Already installed clients are skipped.
The online Codex installer downloads about 945 MB. Claude Code uses the official winget package.
Device policy may require help from a Windows administrator.

Supported combinations
Codex / ChatGPT desktop: DeepSeek, OpenAI and custom Responses providers.
Claude Code CLI: DeepSeek, Anthropic, Bailian Beijing/Singapore pay-as-you-go,
Bailian Beijing Coding Plan, Zhipu GLM Coding Plan and custom Messages providers.
OpenCode 1 CLI / Aider CLI: DeepSeek, OpenAI, Gemini, Bailian Beijing/Singapore
pay-as-you-go, Bailian Beijing Coding Plan, Kimi international API, Zhipu GLM
pay-as-you-go, SiliconFlow China, OpenRouter, Ollama, LM Studio and custom Chat Completions providers.
There are four clients and seventeen provider/region/plan/custom presets, not seventeen vendors.
The UI filters providers by Responses, Messages or Chat Completions compatibility.
Bailian keys must match the region and billing plan. The Kimi preset is the international
platform API, not a Kimi Code subscription. Use custom presets for other gateways or regions.
DeepSeek includes deepseek-flash and deepseek-v4-pro. For other providers, enter a model
ID available to your account. A custom Codex model requires a matching Codex models.json
containing its model slug. A generic OpenAI-compatible endpoint may not support Responses.
This version manages multiple clients and profiles. It does not schedule tasks across agents.

Configuration and credentials
Default data directory: %LOCALAPPDATA%\AgentSetupAssistant
preferences.json: assistant language preference, separate from client profiles.
profiles/<id>/profile.json: metadata without secrets.
profiles/<id>/key.dpapi: API key encrypted with Windows DPAPI for this user and machine.
profiles/<id>/codex and claude: independent client configuration and session directories.
profiles/<id>/opencode: configuration and per-profile XDG data, state and cache directories.
profiles/<id>/aider: configuration, input history and chat history.
tools/aider/venv: a shared Python 3.12 environment managed by uv, without profile credentials.
backups: managed configuration and encrypted keys, excluding sessions and project files.
jobs: background results, without API keys or response bodies.
Existing global .codex and .claude settings and user/system environment variables are preserved.
Keys are decrypted in memory and supplied through child process environments, not command lines.
Protect the data directory. Programs running as your account may still access keys.
Backups containing encrypted keys are not shareable configuration packages.

Launching and switching profiles
Use Launch client in this assistant to apply the selected profile.
Fully quit existing ChatGPT / Codex processes, including the tray icon, before switching.
The assistant launches the installed executable with CODEX_HOME; verify this behavior again
if an app update changes it. Claude Code opens an interactive terminal in the working directory.
Project configuration and organization policy can override some settings.
Client trust and permission prompts still apply. The assistant does not bypass UAC or client approval.

OpenCode and Aider run in interactive terminals. OpenCode uses winget package SST.opencode.
This adapter targets OpenCode 1.x. OpenCode 1 and 2 share a command name; version 2 is unverified.
Aider uses a dedicated uv-created Python 3.12 environment with aider-chat and python-dotenv>=1.2.0.
An existing global Aider installation is not reused, so dependency isolation can be enforced.
If uv is missing, it is installed through winget. Both new clients require online installation,
including when using a ZIP that bundles Codex.
Aider launches with dotenv loading disabled so home/project .env files cannot override
the selected key and endpoint. Those files are preserved. Non-secret command-line settings
also select the model, base URL, configuration file and per-profile history paths.
Project rules and organization policies can still affect client behavior.

Backup and restore
Updating an existing profile creates a backup. Restoring also backs up the current state.
Restore a backup lets you select a version and verifies its file hashes before restoring.
Leave the key blank to reuse a saved key. Re-enter it when changing the provider or endpoint.
Use a new profile ID to change the client. Close the client before restoring its profile.
Only managed configuration files are restored; session files are preserved.

Connection checks
Test connection asks for confirmation before sending one short message, which may incur an API charge.
It refuses redirects and does not display response bodies. It tests basic non-streaming chat only.
Verify tool calls, streaming and multi-turn conversations in the client.
Saving a profile does not call the API. Installation may contact official download sources.
Check custom HTTPS destinations before sending keys. URLs with credentials or query strings are rejected.

Command line
powershell -NoProfile -STA -ExecutionPolicy Bypass -File assistant\AgentSetup.ps1 -Language en-US
Supported language values: zh-CN, en-US. An explicit value overrides the saved preference for
that run. Changing the language through the interface saves it for future runs.

Validation scope
The earlier standalone Codex + DeepSeek flow was tested by the user in the lab VM.
This assistant uses temporary directories, fake keys and mocked endpoints for automated tests.
Real installation, client launch and provider API checks still need end-to-end user testing.
The VM is not started. No translation patch for Codex or Claude is included.

Official references
https://learn.chatgpt.com/docs/enterprise/windows-deployment
https://learn.chatgpt.com/docs/enterprise/connect-to-a-gateway
https://learn.chatgpt.com/docs/enterprise/gateway-compatibility
https://learn.chatgpt.com/docs/config-file/environment-variables
https://code.claude.com/docs/en/setup
https://code.claude.com/docs/en/settings
https://api-docs.deepseek.com/quick_start/agent_integrations/codex/
https://api-docs.deepseek.com/quick_start/agent_integrations/claude_code/
https://opencode.ai/docs/providers/
https://opencode.ai/docs/config/
https://github.com/microsoft/winget-pkgs/tree/master/manifests/s/SST/opencode
https://aider.chat/docs/install.html
https://aider.chat/docs/llms/openai-compat.html
https://aider.chat/docs/config/options.html
https://docs.astral.sh/uv/getting-started/installation/
https://bbc2.github.io/python-dotenv/#disable-load_dotenv
https://ai.google.dev/gemini-api/docs/openai
https://help.aliyun.com/zh/model-studio/base-url
https://github.com/MoonshotAI/kimi-code/blob/main/docs/en/configuration/providers.md
https://docs.bigmodel.cn/cn/guide/develop/openai/introduction
https://docs.bigmodel.cn/cn/coding-plan/tool/claude
https://docs.siliconflow.cn/docs/api/chat-completions-post
https://openrouter.ai/docs/quickstart

The DeepSeek model catalog was extracted from the verified official setup script 1.4.0.
Source script SHA256: 816D5970C0535D20E3F7CC2E6C6F3F41F57194FDE26A58ED8103E6C012756ADF
The assistant treats model instructions as metadata. Revalidate after model or client updates.


Sharing without credentials (0.4)
Save a profile, then click Export without key to create an .agent-profile.json file.
Only the profile ID, client, provider, model, endpoint and format version are exported.
Keys, encrypted keys, raw configuration, model catalogs, sessions, working directories
and local file paths are excluded. The endpoint itself is visible; review it before sharing.
Import profile loads a draft only. It does not install anything or overwrite profiles;
existing IDs receive a new suffix. Review the endpoint and enter your own key, then use
Save profile only or Configure & install. Custom Codex profiles need a trusted models.json
selected separately after import. Sharing files do not contain model catalogs.
Cloud profiles retain their existing blank-key behavior. For local profiles, blank means
no authentication and removes any saved token for that profile, with an automatic backup.

Local models (Ollama / LM Studio)
Install and start Ollama or LM Studio yourself, download/load a model and enable its API server.
The assistant connects to existing servers. It does not install model servers, download
models or start a VM. Select OpenCode 1 or Aider, then Ollama (local) or LM Studio (local).
Defaults: http://127.0.0.1:11434/v1 and http://127.0.0.1:1234/v1 respectively.
Ports are editable. Local presets accept only localhost, 127.0.0.1 or ::1, not LAN hosts.
Click List local models to read /models (5 second timeout), or enter a model ID manually.
Leave the key blank for unauthenticated services; enter a token when server auth is enabled.
Model discovery uses only a token entered in the UI, not an existing saved token;
re-enter it before listing models from an authenticated server.
Launching without a key supplies a fixed non-secret placeholder required by client SDKs;
connection checks omit the Authorization header when no token is saved.
Save profile only does not install software. Install the client, test and launch when ready.
Tool use depends on model and server capabilities. A basic chat check does not verify tools.
Select a downloaded local model for local inference. Servers may also expose cloud models;
a loopback address alone does not guarantee offline inference.
Local presets currently support OpenCode/Aider. Local Codex/Claude adapters are not included.
https://docs.ollama.com/api/openai-compatibility
https://lmstudio.ai/docs/developer/openai-compat
https://lmstudio.ai/docs/developer/core/authentication
