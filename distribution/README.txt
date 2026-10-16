Codex + DeepSeek Windows x64 安装配置包

使用方法
1. 将整个 ZIP 解压到本机文件夹，不能直接在压缩包预览中运行 CMD。
2. 使用你日常使用软件的 Windows 账户。若应用已运行，请完全退出。
3. 双击 Setup-Codex-DeepSeek.cmd。
4. 等待安装，按提示输入自己的 DeepSeek API Key，输入字符不会显示。
5. 官方菜单选择 1（DeepSeek-Flash）或 2（DeepSeek-V4-Pro）。
6. 看到 SETUP COMPLETED 后，双击 Start-Codex.cmd 或桌面 ChatGPT (Codex) 快捷方式。
7. 发送一条消息验证连接；配置成功本身不代表 API 已连通。

适用范围
本包包含 Windows x64 安装文件，不适用于 ARM64。推荐 Windows 11 x64；
脚本最低检查 Windows build 19041。其他电脑的完整安装流程尚未验证。
安装不依赖实验机名称、实验账户、VirtualBox 或共享目录。
这是按提示完成安装和配置的工具，需要用户输入 Key 并选择模型。
界面中文切换尚未集成到此包。

已有安装与配置
已经安装同版本或更新版本时跳过安装，较旧版本尝试更新。
现有 config.toml 由 DeepSeek 官方脚本备份后调整为 DeepSeek 配置。
默认配置目录为 %USERPROFILE%\.codex；若已设置绝对路径 CODEX_HOME，则使用该路径。
备份位于配置目录的 backup-deepseek。遇到官方脚本提示备份冲突时，按错误说明处理，
不要随意删除备份。如果在官方菜单选择 9 恢复，本工具不会报告 DeepSeek 配置成功。
新建配置默认使用 unelevated Windows 沙箱；已有沙箱设置由官方脚本按其规则处理。

权限与错误处理
请先普通双击运行。工具不自动切换到其他管理员账户，配置写入当前用户的目录。
若安装受 Windows 或单位策略限制，需要管理员协助；不保证所有电脑均免管理员安装。
管理员提示只有“否”时，请联系该电脑的管理员处理账户权限，本包不会修改账户组或 UAC。
安装失败时停止，不继续填写 Key。日志：%LOCALAPPDATA%\CodexDeepSeekSetup\codex-install.log。
只反馈失败步骤和错误文字，不要发送 Key、config.toml 或配置备份。

Key 与文件
ZIP 不包含任何预填 Key、用户配置、登录凭据、虚拟机或账户修复工具。
Key 不写入本工具的安装日志；官方脚本会把 Key 保存在本机 config.toml 中。
不要分享含 Key 的配置或备份。所有附带文件请保持在同一文件夹。
本包校验各文件 SHA256 和官方 MSIX 签名；校验清单不等同于此工具的代码签名。
Codex-License.xml 随官方安装文件附带；本工具的当前用户安装使用 Add-AppxPackage。

来源与版本
Codex 安装包：26.1007.9446.0，Windows x64。
OpenAI：https://persistent.oaistatic.com/codex-app-prod/ChatGPT-x64.msix
许可：https://persistent.oaistatic.com/codex-app-prod/ChatGPT-License.xml
部署文档：https://learn.chatgpt.com/docs/enterprise/windows-deployment
DeepSeek 官方配置脚本：https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.ps1
DeepSeek 使用说明：https://api-docs.deepseek.com/quick_start/agent_integrations/codex/
