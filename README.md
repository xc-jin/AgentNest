# AgentNest · 智巢

**一键配置，让 AI 助手即刻就位。**

[English](README.en.md) · 简体中文

AgentNest 是 Windows 上用于安装 AI 编程客户端、配置模型服务商和管理独立配置方案的中英文双语助手（0.4）。

双击 [Agent-Assistant.cmd](Agent-Assistant.cmd) 打开界面。
填写方案后点击“一键配置并安装”，再按需检查连接和启动。首次使用请阅读 [说明](assistant/README.txt)。

右上角切换“中文 (简体)”／“English”，会记住上次选择。切换保留未保存的输入，
界面、助手自身的提示及帮助文档随语言切换。Windows 安装器及客户端自身的语言由其设置决定。
English instructions: [README.en.txt](assistant/README.en.txt).

| 客户端 | 支持配置的服务商 |
| --- | --- |
| Codex / ChatGPT 桌面版 | DeepSeek、OpenAI、自定义 Responses |
| Claude Code CLI | DeepSeek、Anthropic、百炼北京/新加坡按量、百炼北京 Coding Plan、智谱 GLM Coding Plan、自定义 Messages |
| OpenCode 1 CLI | DeepSeek、OpenAI、Gemini、百炼北京/新加坡按量、百炼北京 Coding Plan、Kimi 国际 API、智谱 GLM 按量、硅基流动中国、OpenRouter、Ollama、LM Studio、自定义 Chat Completions |
| Aider CLI | 与 OpenCode 相同，使用 Chat Completions 协议 |

共 4 个客户端、17 个服务商/地区/套餐/自定义预设（并非 17 家不同厂商）。
服务商按协议筛选；新增服务商不会自动出现在仅支持 Responses 的 Codex 选项中。
除 DeepSeek 的原有模型预设外，模型 ID 请按对应账户可用模型手动填写。
百炼不同地区、按量和 Coding Plan 的 Key 必须与对应地址匹配；Kimi 预设为国际按量 API，
不等同于 Kimi Code 订阅。其他地区或网关使用自定义预设。

每个方案使用独立配置目录，Key 使用 Windows DPAPI 保存，启动时注入子进程。
既有全局客户端配置不改动。自动协作调度不在第一版范围内。

OpenCode 通过 winget 的 `SST.opencode` 包安装，适配 OpenCode 1；会使用方案自己的
XDG 配置、数据、状态和缓存目录，保留原有工具权限确认。
Aider 使用 uv 创建助手数据目录下的 Python 3.12 环境，并要求 `python-dotenv>=1.2.0`，
启动时禁用 `.env` 自动加载、显式选择模型/地址/配置及方案历史目录。
已有全局 Aider 不直接复用，以确保隔离依赖；缺少 uv 时通过 winget 安装。
这两个客户端均需联网安装，即使使用含 Codex 安装包的 ZIP。

## 项目结构

- `assistant/`：双语界面和语言资源、客户端适配、配置方案、安装、连接检测及备份恢复。
- `tests/`：使用临时目录和模拟接口的测试。
- `Build-Assistant.ps1`：构建在线版和包含 Codex 安装文件的离线版 ZIP。
- `distribution/`：保留上一版 Codex + DeepSeek 安装脚本。
- `lab/`：本机实验和测试输出目录，不上传至仓库；助手不依赖或启动虚拟机。

运行测试：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Assistant.ps1
```

指定本次界面语言（界面切换才会保存偏好）：

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\assistant\AgentSetup.ps1 -Language en-US
```

构建：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Assistant.ps1
```

默认构建在线版，无需预先准备安装文件。输出为 `dist/Agent-Setup-Assistant-0.4.0-Windows-x64-online.zip`。

如需构建含 Codex 安装包的版本，先在本机 `lab/payload/` 中准备脚本指定版本及哈希的
`Codex-x64.msix` 和 `Codex-License.xml`，再运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Assistant.ps1 -IncludeCodexInstaller
```

在线版缺少客户端时访问官方安装源；含 Codex 安装文件的版本仍需联网安装 Claude Code。
两种包都不包含用户配置、Key、虚拟机或账户修复工具。
仓库只发布源代码、语言资源与非密钥模型元数据，不包含第三方客户端安装包。

已由用户验证的是此前 Codex + DeepSeek 实验流程。新助手的真实客户端与 API 端到端验证待完成；
自动测试不安装客户端、不启动虚拟机，不调用真实付费接口。


## 无 Key 方案分享（0.4）

保存方案后点击“导出无 Key 方案”，生成 `.agent-profile.json`。文件只包含格式版本、
方案名称、客户端、服务商、模型和接口地址，不包含 Key、加密 Key、原始配置、会话、
模型目录、工作目录或本机文件路径。接口地址公开可见，请先确认地址本身适合分享。

接收方点击“导入分享方案”，先载入草稿；不会安装软件或覆盖已有方案，重名自动加后缀。
核对接口地址，输入自己的 Key，再点击“仅保存方案”或“一键配置并安装”。
自定义 Codex 方案需要另外选择可信的 `models.json`。

## 本地模型（0.4）

先安装并启动 Ollama 或 LM Studio，下载/加载模型并开启本地 API 服务。
助手连接已有服务，不安装本地模型服务器、不自动下载模型，不启动虚拟机。

1. 选择 OpenCode 1 或 Aider，再选择 Ollama（本地）或 LM Studio（本地）。
2. 使用默认地址，或修改本机端口。只接受 `localhost`、`127.0.0.1` 或 `::1`。
3. 点击“读取本地模型”，或手动输入模型 ID。认证服务需要先在 Key 框填写 Token。
4. 点击“仅保存方案”，再按需安装客户端、检查连接和启动。

| 服务 | 默认 API 地址 |
| --- | --- |
| Ollama | `http://127.0.0.1:11434/v1` |
| LM Studio | `http://127.0.0.1:1234/v1` |

本地 Key 留空会保存为免认证方案，并移除该方案原有 Token；修改前自动备份。
云端方案仍可留空沿用已有 Key。读取模型只使用刚输入的 Token，不读取已有方案中的 Token。
免 Key 启动使用非密钥 SDK 占位值；连接检查不发送认证头。

本地预设目前支持 OpenCode/Aider，Codex/Claude 的本地模型适配尚未提供。
工具调用能力取决于模型和服务，基础对话检查不保证工具调用兼容。
本地服务也可能暴露云模型；选择实际下载的本地模型才能本地推理。
接口依据 [Ollama 文档](https://docs.ollama.com/api/openai-compatibility)、
[LM Studio 文档](https://lmstudio.ai/docs/developer/openai-compat) 和
[LM Studio 认证文档](https://lmstudio.ai/docs/developer/core/authentication)。
