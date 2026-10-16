AgentNest 智巢 0.4（Windows x64）

入口：解压整个包，双击 Agent-Assistant.cmd，打开图形界面。
右上角可切换“中文 (简体)”和“English”，界面、后续提示及使用说明随之切换。
语言偏好保存在数据目录的 preferences.json，下次打开自动沿用。
首次使用跟随 Windows 显示语言：中文系统使用中文，其他语言系统使用英文。
切换时保留当前方案、服务商和未保存的输入；已有日志保留原语言。
Windows 系统对话框、安装器和 Codex / Claude 软件自身的语言由其各自设置决定。
命令行可用 -Language zh-CN 或 -Language en-US 覆盖本次运行的语言。
流程：选择客户端/服务商 → 填模型和 Key → 一键配置并安装 → 检查连接 → 启动。
“一键配置并安装”先保存独立方案，再安装客户端；失败后可用“检测/安装”重试。
已有客户端会跳过安装；Codex 在线版约需下载 945 MB，Claude Code 使用官方支持的 winget 包。
安装按钮仅安装选中的客户端。单位设备或 Windows 策略可能要求管理员协助。

当前兼容性
Codex / ChatGPT 桌面版：DeepSeek、OpenAI、自定义 Responses 服务商。
Claude Code CLI：DeepSeek、Anthropic、百炼北京/新加坡按量、百炼北京 Coding Plan、智谱 GLM Coding Plan、自定义 Messages。
OpenCode 1 CLI / Aider CLI：DeepSeek、OpenAI、Gemini、百炼北京/新加坡按量、百炼北京 Coding Plan、Kimi 国际 API、智谱 GLM 按量、硅基流动中国、OpenRouter、Ollama、LM Studio、自定义 Chat Completions。
共 4 个客户端、17 个服务商/地区/套餐/自定义预设，不代表 17 家不同厂商。
服务商下拉框按 Responses、Messages、Chat Completions 协议过滤；不是任意组合都可用。
百炼不同地区及按量/Coding Plan 的 Key 必须与所选地址匹配。Kimi 预设为国际按量 API，不是 Kimi Code 订阅。
其他地区、套餐或网关可选择对应协议的自定义服务商，仔细核对接口地址。
DeepSeek 内置 deepseek-flash / deepseek-v4-pro；其他服务商请填写账户可用的完整模型 ID。
自定义 Codex 模型必须提供适配当前客户端版本的 Codex models.json，且包含模型 slug。
提供商下拉框过滤协议不匹配的组合，不能把任意“OpenAI 兼容”接口当作 Responses 使用。
该版本管理多个客户端和配置方案；自动分派任务、跨客户端协作调度尚未实现。

配置与 Key
数据默认保存在 %LOCALAPPDATA%\AgentSetupAssistant。
profiles/<方案>/profile.json：非密钥元数据。
profiles/<方案>/key.dpapi：Windows DPAPI 加密 Key，通常只能由同机同账户解密。
profiles/<方案>/codex 和 claude：各方案独立的客户端配置与会话目录。
profiles/<方案>/opencode：OpenCode 配置及独立的 XDG 数据、状态和缓存目录。
profiles/<方案>/aider：Aider 配置、输入历史与聊天历史。
tools/aider/venv：由 uv 创建的共享 Python 3.12 独立安装环境，不包含方案 Key。
backups：仅备份助手管理的配置和加密 Key，不备份会话、项目文件或软件本体。
jobs：后台操作结果，不记录 Key 或接口返回正文。
不会改写既有 %USERPROFILE%\.codex / .claude，也不修改系统/用户级环境变量。
Key 在启动或测试时解密至进程内存，通过子进程环境传给客户端，不写入命令行参数。
保护数据目录；有权限控制当前账户的程序仍可能访问 Key。备份不是可分享的配置包。

启动与切换
请使用助手的“启动客户端”，否则客户端不会自动选用助手的独立方案。
Codex 桌面进程有复用行为：先完全退出已有 ChatGPT/Codex（包括托盘），再启动另一方案。
通过直接启动已安装的应用程序并传入 CODEX_HOME；若应用升级改变该行为，需要重新验证。
Claude Code 启动窗口为交互终端；工作目录决定它处理哪个项目。
OpenCode / Aider 也在交互终端启动。OpenCode 适配 1.x，通过 winget 的 SST.opencode 包安装。
OpenCode 1 与 2 共用命令名；本版本未验证 OpenCode 2，若已有 2.x 请勿当作已兼容。
Aider 不复用已有全局安装：助手用 uv 创建自己的 Python 环境，安装 aider-chat 和 python-dotenv>=1.2.0。
启动 Aider 时禁用 .env 自动加载，避免项目或用户目录中的地址/Key 覆盖当前方案；不会修改那些文件。
模型与地址还通过不含 Key 的启动参数固定。项目规则和组织策略依然可能影响工具行为。
新增客户端均需联网安装；缺少 uv 时会通过 winget 安装依赖。含 Codex 的 ZIP 不包含它们的安装文件。
项目配置和组织管理策略可能覆盖部分设置。首次启动的信任/权限确认仍由客户端完成。
不会跳过客户端审批，不会自动提升权限，也不关闭 UAC。

备份与恢复
同名方案更新前自动备份；恢复前再备份当前版本。
“选择备份并恢复”可选择一个旧版本，会校验文件哈希后恢复助手管理的文件。
保存已有方案时 Key 留空可沿用；更换服务商或地址时要求重新输入 Key。
同名方案不能更换客户端。请用新名称保留两套独立配置。
恢复会覆盖该方案配置；请先退出使用该方案的客户端。会话文件不会删除。

检查连接
仅当点击并确认“检查连接”时，发送一条短消息，可能产生少量 API 费用。
不跟随重定向，不显示接口响应正文。只验证基础非流式对话，不证明工具调用/流式/多轮兼容。
保存配置不会发 API 请求；“一键配置并安装”及安装按钮可能访问官方下载/软件包分发服务。
HTTPS 地址可自定义，发送 Key 前务必核对；不支持把带 Key 的查询参数放在 URL 中。

验证范围
原 Codex + DeepSeek 单独安装流程已由用户在实验机跑通。
本助手的自动测试使用临时目录、模拟接口和本地测试程序，未使用真实 Key。
新助手对真实客户端启动、首次安装、各服务商 API 的端到端验证仍需用户测试。
未启动实验虚拟机；不包含汉化补丁、模型代理服务或多 Agent 任务编排器。

官方资料
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

DeepSeek models.json 从此前已验证的官方配置脚本 1.4.0 提取，源脚本 SHA256：
816D5970C0535D20E3F7CC2E6C6F3F41F57194FDE26A58ED8103E6C012756ADF
该目录属于模型行为元数据，助手不执行其中的提示词。模型/客户端升级后需更新验证。


无 Key 方案分享（0.4）
先保存方案，再点击“导出无 Key 方案”，生成 .agent-profile.json。
只导出方案名称、客户端、服务商、模型和接口地址，以及文件格式版本。
不会导出 Key、加密 Key、原始配置、模型目录、会话、工作目录或本机文件路径。
接口地址会出现在分享文件中，请先确认地址本身适合分享。
接收方点击“导入分享方案”，仅载入草稿，不安装、不覆盖已有方案；重名会自动加后缀。
接收方核对地址，输入自己的 Key，再点击“仅保存方案”或“一键配置并安装”。
自定义 Codex 方案导入后需要另选可信的 models.json；分享文件不携带模型目录。
云端方案保存时 Key 留空沿用的规则不变。本地方案留空表示免 Key，会移除该方案原有认证 Token；修改前自动备份。

本地模型（Ollama / LM Studio）
先安装并启动 Ollama 或 LM Studio，在软件中下载/加载需要的模型并开启本地 API 服务。
助手只连接已有服务，不安装本地模型服务器，不自动下载模型，也不启动虚拟机。
选择 OpenCode 1 或 Aider，再选择 Ollama（本地）或 LM Studio（本地）。
默认地址分别为 http://127.0.0.1:11434/v1 和 http://127.0.0.1:1234/v1。
可以修改本机端口；本地预设仅接受 localhost、127.0.0.1 或 ::1，不接受局域网地址。
点击“读取本地模型”读取 /models 列表，或手动输入模型 ID；读取最多等待 5 秒。
本地服务未启用认证时 Key 留空；LM Studio 等启用认证时填写其 Token。
读取模型只使用界面刚填写的 Token，不会读取已有方案里保存的 Token；认证服务需重新填写。
启动免 Key 方案时给客户端 SDK 注入固定非密钥占位值，连接检查则不发送认证头。
点击“仅保存方案”不会执行安装；再按需安装客户端、检查连接并启动。
模型是否支持工具调用取决于模型和服务；基础对话检查不保证工具调用兼容。
选择本地实际下载的模型才能本地推理；本地服务也可能提供云模型，不能仅凭地址判断离线。
本版本本地预设支持 OpenCode/Aider；Codex/Claude 的本地模型适配尚未提供。
参考：https://docs.ollama.com/api/openai-compatibility
参考：https://lmstudio.ai/docs/developer/openai-compat
认证：https://lmstudio.ai/docs/developer/core/authentication
