function Show-AssistantWindow {
    param([string]$DataRoot, [switch]$SmokeTest, [string]$PreviewPath)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()
    $taskCatalog = Get-AssistantCatalog
    $taskState = @{ Busy = $false; Process = $null; ResultPath = $null; DataRoot = $DataRoot; Loading = $false; Translating = $false }
    $taskForm = New-Object Windows.Forms.Form
    $taskForm.Text = (Get-AssistantText 'AgentNest 智巢 · 0.4')
    $taskForm.ClientSize = New-Object Drawing.Size(780, 830)
    $taskForm.MinimumSize = $taskForm.Size
    $taskForm.MaximumSize = $taskForm.Size
    $taskForm.StartPosition = 'CenterScreen'
    $taskForm.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10)
    $taskForm.BackColor = [Drawing.Color]::FromArgb(245,247,250)
    function Add-Label([string]$Text,[int]$X,[int]$Y,[int]$Width=180) {
        $taskLabel = New-Object Windows.Forms.Label
        $taskLabel.Text = Get-AssistantText $Text; $taskLabel.Tag = 'i18n:' + $Text; $taskLabel.SetBounds($X,$Y,$Width,26); $taskForm.Controls.Add($taskLabel)
        $taskLabel
    }
    function Add-Text([int]$X,[int]$Y,[int]$Width=550) {
        $taskText = New-Object Windows.Forms.TextBox
        $taskText.SetBounds($X,$Y,$Width,30); $taskForm.Controls.Add($taskText); $taskText
    }
    function Add-Combo([int]$X,[int]$Y,[int]$Width=550) {
        $taskCombo = New-Object Windows.Forms.ComboBox
        $taskCombo.DropDownStyle = 'DropDownList'; $taskCombo.SetBounds($X,$Y,$Width,30)
        $taskForm.Controls.Add($taskCombo); $taskCombo
    }
    function Add-Button([string]$Text,[int]$X,[int]$Y,[int]$Width=170) {
        $taskButton = New-Object Windows.Forms.Button
        $taskButton.UseMnemonic = $false
        $taskButton.Text = Get-AssistantText $Text; $taskButton.Tag = 'i18n:' + $Text; $taskButton.SetBounds($X,$Y,$Width,38); $taskForm.Controls.Add($taskButton); $taskButton
    }
    $taskTitle = Add-Label '安装与配置你的 AI 编程助手' 24 20 565
    $taskTitle.Font = New-Object Drawing.Font('Microsoft YaHei UI',17,[Drawing.FontStyle]::Bold)
    $taskTitle.Height = 40
    $taskLanguage = Add-Combo 612 24 140
    $null = $taskLanguage.Items.Add('中文 (简体)')
    $null = $taskLanguage.Items.Add('English')
    $taskLanguage.SelectedIndex = if ((Get-AssistantLanguage) -eq 'zh-CN') { 0 } else { 1 }
    $null = Add-Label '每个方案独立保存配置；通过本助手启动，切换客户端和服务商。' 26 68 730
    $null = Add-Label '已有方案' 26 110
    $taskSaved = Add-Combo 190 106 410
    $taskNew = Add-Button '新建方案' 612 104 140
    $null = Add-Label '方案名称（英文）' 26 157
    $taskId = Add-Text 190 153
    $taskId.Text = 'my-codex-deepseek'
    $null = Add-Label 'Agent 客户端' 26 201
    $taskClients = Add-Combo 190 197
    foreach ($taskClient in $taskCatalog.clients) { $null = $taskClients.Items.Add((Get-AssistantText $taskClient.name)) }
    $null = Add-Label '模型服务商' 26 245
    $taskProviders = Add-Combo 190 241
    $null = Add-Label '模型 ID' 26 289
    $taskModels = Add-Combo 190 285
    $taskModels.DropDownStyle = 'DropDown'
    $null = Add-Label 'API 基础地址' 26 333
    $taskEndpoint = Add-Text 190 329
    $null = Add-Label 'API Key' 26 377
    $taskKey = Add-Text 190 373
    $taskKey.UseSystemPasswordChar = $true
    $taskKeyNote = Add-Label '保存已有方案时留空可沿用 Key。Key 由当前 Windows 账户加密。' 190 409 565
    $taskKeyNote.Font = New-Object Drawing.Font('Microsoft YaHei UI',9)
    $null = Add-Label 'Codex 模型目录' 26 448
    $taskModelCatalog = Add-Text 190 444 410
    $taskBrowse = Add-Button '选择 JSON' 612 440 140
    $null = Add-Label '工作目录' 26 492
    $taskWorkdir = Add-Text 190 488 410
    $taskWorkdir.Text = $env:USERPROFILE
    $taskWorkBrowse = Add-Button '选择目录' 612 484 140
    $taskSave = Add-Button '1. 一键配置并安装' 26 540
    $taskInstall = Add-Button '2. 检测 / 安装' 210 540
    $taskTest = Add-Button '3. 检查连接' 394 540
    $taskLaunch = Add-Button '4. 启动客户端' 578 540
    $taskBackup = Add-Button '备份当前方案' 26 590
    $taskRestore = Add-Button '选择备份并恢复' 210 590
    $taskOpen = Add-Button '打开方案目录' 394 590
    $taskInfo = Add-Button '使用说明' 578 590
    $taskExport = Add-Button '导出无 Key 方案' 26 636
    $taskImport = Add-Button '导入分享方案' 210 636
    $taskLocalModels = Add-Button '读取本地模型' 394 636
    $taskLocalModels.Enabled = $false
    $taskSaveOnly = Add-Button '仅保存方案' 578 636
    $taskLog = New-Object Windows.Forms.TextBox
    $taskLog.Multiline = $true; $taskLog.ReadOnly = $true; $taskLog.ScrollBars = 'Vertical'
    $taskLog.SetBounds(26,686,726,120); $taskForm.Controls.Add($taskLog)
    function Write-UiLog([string]$Message) { $taskLog.AppendText(('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $Message + "`r`n")) }
    function Show-UiError($ErrorRecord) {
        if ($SmokeTest) { throw $ErrorRecord }
        Write-UiLog ((Get-AssistantText '失败：') + $ErrorRecord.Exception.Message)
        $null = [Windows.Forms.MessageBox]::Show($ErrorRecord.Exception.Message,(Get-AssistantText '操作未完成'),'OK','Warning')
    }
    function Get-UiClient { $taskCatalog.clients[$taskClients.SelectedIndex] }
    function Get-UiProvider {
        $taskClient = Get-UiClient
        @($taskCatalog.providers | Where-Object { $_.routes.PSObject.Properties[$taskClient.protocol] })[$taskProviders.SelectedIndex]
    }
    function Update-UiProviders {
        $taskClient = Get-UiClient
        $taskProviders.Items.Clear()
        foreach ($taskProvider in $taskCatalog.providers) {
            if ($taskProvider.routes.PSObject.Properties[$taskClient.protocol]) { $null = $taskProviders.Items.Add((Get-AssistantText $taskProvider.name)) }
        }
        if ($taskProviders.Items.Count) { $taskProviders.SelectedIndex = 0 }
    }
    function Update-UiProviderFields {
        if ($taskProviders.SelectedIndex -lt 0) { return }
        $taskProvider = Get-UiProvider
        $taskClient = Get-UiClient
        $taskKey.Clear()
        $taskEndpoint.Text = $taskProvider.routes.PSObject.Properties[$taskClient.protocol].Value
        $taskEndpoint.ReadOnly = -not ($taskProvider.id.StartsWith('custom-') -or $taskProvider.id -in @('ollama','lmstudio'))
        Update-UiLocalHint
        $taskModels.Items.Clear(); $taskModels.Text = ''
        foreach ($taskModel in $taskProvider.models) { $null = $taskModels.Items.Add($taskModel) }
        if ($taskModels.Items.Count) { $taskModels.SelectedIndex = 0 }
        $taskModelCatalog.Enabled = $taskClient.id -eq 'codex-desktop' -and $taskProvider.id -ne 'deepseek'
        $taskBrowse.Enabled = $taskModelCatalog.Enabled
        $taskModelCatalog.Text = ''
    }
    function Update-UiLocalHint {
        $taskIsLocal = (Get-UiProvider).id -in @('ollama','lmstudio')
        $taskLocalModels.Enabled = $taskIsLocal -and -not $taskState.Busy
        $taskKeyNote.Tag = 'i18n:' + $(if ($taskIsLocal) { '本地 Key 可留空；留空保存为免 Key 方案。启用认证时请填写 Token。' } else { '保存已有方案时留空可沿用 Key。Key 由当前 Windows 账户加密。' })
        $taskKeyNote.Text = Get-AssistantText $taskKeyNote.Tag.Substring(5)
    }
    function Import-UiDraft([string]$Path) {
        $taskDraft = Read-AssistantSharedProfile -Path $Path -DataRoot $DataRoot
        $taskSaved.SelectedIndex = -1
        $taskClients.SelectedItem = Get-AssistantText (@($taskCatalog.clients | Where-Object id -eq $taskDraft.ClientId)[0].name)
        $taskProviders.SelectedItem = Get-AssistantText (@($taskCatalog.providers | Where-Object id -eq $taskDraft.ProviderId)[0].name)
        $taskCandidate = $taskDraft.Id
        $taskCounter = 1
        while (Test-Path -LiteralPath (Get-AssistantProfilePath $taskCandidate $DataRoot)) {
            $taskCandidate = $taskDraft.Id.Substring(0,[Math]::Min(36,$taskDraft.Id.Length)) + '-import-' + $taskCounter
            $taskCounter++
        }
        $taskId.Text = $taskCandidate; $taskModels.Text = $taskDraft.Model; $taskEndpoint.Text = $taskDraft.BaseUrl
        $taskKey.Clear(); $taskModelCatalog.Clear()
        Write-UiLog (Get-AssistantText '已导入为草稿。请核对接口地址，填写自己的 Key 后保存；本地方案可免 Key。')
    }
    function Refresh-UiProfiles {
        $taskPrevious = [string]$taskSaved.SelectedItem
        $taskState.Loading = $true
        try {
            $taskSaved.Items.Clear()
            foreach ($taskProfile in @(Get-AssistantProfiles $DataRoot)) { $null = $taskSaved.Items.Add($taskProfile.Id) }
            if ($taskPrevious -and $taskSaved.Items.Contains($taskPrevious)) { $taskSaved.SelectedItem = $taskPrevious }
        } finally { $taskState.Loading = $false }
    }
    function Load-UiProfile([string]$Id) {
        $taskProfile = Get-AssistantProfile $Id $DataRoot
        $taskId.Text = $taskProfile.Id
        $taskClient = @($taskCatalog.clients | Where-Object id -eq $taskProfile.ClientId)[0]
        $taskClients.SelectedItem = Get-AssistantText $taskClient.name
        $taskProvider = @($taskCatalog.providers | Where-Object id -eq $taskProfile.ProviderId)[0]
        $taskProviders.SelectedItem = Get-AssistantText $taskProvider.name
        $taskEndpoint.Text = $taskProfile.BaseUrl; $taskModels.Text = $taskProfile.Model; $taskKey.Clear()
        if ($taskProfile.ProviderId -eq 'custom-responses') {
            $taskModelCatalog.Text = Join-Path (Get-AssistantProfilePath $Id $DataRoot) 'codex/models.json'
        }
        Write-UiLog ((Get-AssistantText '已载入方案：') + $Id)
    }
    function Assert-UiSaved {
        $taskProfile = Get-AssistantProfile $taskId.Text $DataRoot
        $taskClient = Get-UiClient; $taskProvider = Get-UiProvider
        if ($taskProfile.ClientId -ne $taskClient.id -or $taskProfile.ProviderId -ne $taskProvider.id -or
            $taskProfile.Model -ne $taskModels.Text -or $taskProfile.BaseUrl.TrimEnd('/') -ne $taskEndpoint.Text.TrimEnd('/') -or $taskKey.Text) {
            throw (Get-AssistantText '当前界面有未保存的更改。请先保存方案，再执行该操作。')
        }
        $taskProfile
    }
    $taskMutable = @($taskLanguage,$taskNew,$taskId,$taskClients,$taskProviders,$taskModels,$taskEndpoint,$taskKey,$taskModelCatalog,
        $taskBrowse,$taskWorkdir,$taskWorkBrowse,$taskSave,$taskInstall,$taskTest,$taskLaunch,$taskBackup,$taskRestore,$taskSaved,$taskExport,$taskImport,$taskLocalModels,$taskSaveOnly)
    function Start-UiWorker([string]$WorkerAction) {
        $null = Assert-UiSaved
        if ($taskState.Busy) { throw (Get-AssistantText '请等待当前操作结束。') }
        $taskJobs = Join-Path $DataRoot 'jobs'; New-Item -ItemType Directory -Path $taskJobs -Force | Out-Null
        $taskState.ResultPath = Join-Path $taskJobs ([guid]::NewGuid().ToString('N') + '.json')
        $taskScript = Join-Path $PSScriptRoot 'AgentSetup.ps1'
        $taskCommandText = '& ' + (ConvertTo-UiLiteral $taskScript) + ' -Action ' + (ConvertTo-UiLiteral $WorkerAction) +
            ' -ProfileId ' + (ConvertTo-UiLiteral $taskId.Text) + ' -Language ' + (ConvertTo-UiLiteral (Get-AssistantLanguage)) + ' -DataRoot ' + (ConvertTo-UiLiteral $DataRoot) + ' -ResultPath ' + (ConvertTo-UiLiteral $taskState.ResultPath)
        $taskArguments = '-NoProfile -STA -ExecutionPolicy Bypass -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($taskCommandText))
        $taskState.Process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $taskArguments -WindowStyle Hidden -PassThru
        $taskState.Busy = $true
        foreach ($taskControl in $taskMutable) { $taskControl.Enabled = $false }
        Write-UiLog ((Get-AssistantText '正在执行：') + (Get-AssistantText $WorkerAction) + (Get-AssistantText '。安装时可能需要等待下载。'))
    }
    function ConvertTo-UiLiteral([string]$Value) { "'" + $Value.Replace("'", "''") + "'" }
    $taskClients.Add_SelectedIndexChanged({ if (-not $taskState.Translating) { Update-UiProviders } })
    $taskProviders.Add_SelectedIndexChanged({ if (-not $taskState.Translating) { Update-UiProviderFields } })
    $taskSaved.Add_SelectedIndexChanged({
        if (-not $taskState.Loading -and $taskSaved.SelectedIndex -ge 0) { try { Load-UiProfile ([string]$taskSaved.SelectedItem) } catch { Show-UiError $_ } }
    })
    $taskNew.Add_Click({ $taskId.Clear(); $taskKey.Clear(); $taskModels.Text = ''; $taskSaved.SelectedIndex = -1; Write-UiLog (Get-AssistantText '填写新的英文方案名称，再选择客户端和服务商。') })
    $taskBrowse.Add_Click({
        $taskDialog = New-Object Windows.Forms.OpenFileDialog; $taskDialog.Filter = (Get-AssistantText 'Codex 模型目录 (*.json)|*.json')
        if ($taskDialog.ShowDialog() -eq 'OK') { $taskModelCatalog.Text = $taskDialog.FileName }; $taskDialog.Dispose()
    })
    $taskWorkBrowse.Add_Click({
        $taskDialog = New-Object Windows.Forms.FolderBrowserDialog
        if ($taskDialog.ShowDialog() -eq 'OK') { $taskWorkdir.Text = $taskDialog.SelectedPath }; $taskDialog.Dispose()
    })
    function Save-UiProfile([bool]$InstallAfterSave) {
        $taskSecure = $null
        try {
            $taskClient = Get-UiClient; $taskProvider = Get-UiProvider
            $taskPlan = New-AssistantPlan -Id $taskId.Text -ClientId $taskClient.id -ProviderId $taskProvider.id -Model $taskModels.Text -BaseUrl $taskEndpoint.Text -DataRoot $DataRoot -ModelCatalogPath $taskModelCatalog.Text
            if ($taskProvider.id.StartsWith('custom-')) {
                if ([Windows.Forms.MessageBox]::Show(((Get-AssistantText '该方案的 Key 将发送到：') + $taskPlan.BaseUrl + ("`r`n" + (Get-AssistantText '请确认这是你信任的接口。'))),(Get-AssistantText '确认自定义服务商'),'OKCancel','Information') -ne 'OK') { return }
            }
            if ($taskKey.Text) { $taskSecure = ConvertTo-SecureString $taskKey.Text -AsPlainText -Force }
            elseif ($taskProvider.id -notin @('ollama','lmstudio')) {
                $taskSecretPath = Join-Path $taskPlan.ProfilePath 'key.dpapi'
                if (-not (Test-Path -LiteralPath $taskSecretPath)) { throw (Get-AssistantText '新方案必须输入 API Key。') }
                $taskExistingProfile = Get-AssistantProfile $taskId.Text $DataRoot
                if ($taskExistingProfile.ProviderId -ne $taskProvider.id -or $taskExistingProfile.BaseUrl -ne $taskPlan.BaseUrl) { throw (Get-AssistantText '更换服务商或地址时必须重新输入 Key。') }
                $taskSecure = ConvertTo-SecureString ([IO.File]::ReadAllText($taskSecretPath))
            }
            if ($SmokeTest) { $taskState.SmokeSaved = $true; $taskSavedResult = [pscustomobject]@{ Id = $taskPlan.Id } }
            else { $taskSavedResult = Save-AssistantProfile $taskPlan $taskSecure }
            $taskKey.Clear(); Refresh-UiProfiles
            Write-UiLog ((Get-AssistantText '保存成功：') + $taskSavedResult.Id + (Get-AssistantText '。原有全局客户端配置未改动。'))
            if (-not $SmokeTest -and $InstallAfterSave) { Start-UiWorker 'Install' }
        } catch { Show-UiError $_ } finally { if ($taskSecure) { $taskSecure.Dispose() } }
    }
    $taskSave.Add_Click({ Save-UiProfile $true })
    $taskSaveOnly.Add_Click({ Save-UiProfile $false })
    $taskInstall.Add_Click({ try { Start-UiWorker 'Install' } catch { Show-UiError $_ } })
    $taskTest.Add_Click({
        try {
            $taskProfile = Assert-UiSaved
            if ([Windows.Forms.MessageBox]::Show(((Get-AssistantText '向 ') + $taskProfile.BaseUrl + ("`r`n" + (Get-AssistantText '发送一条短消息检查连接，可能产生少量 API 费用。'))),(Get-AssistantText '检查基础对话'),'OKCancel','Information') -eq 'OK') { Start-UiWorker 'Test' }
        } catch { Show-UiError $_ }
    })
    $taskLaunch.Add_Click({
        try {
            $null = Assert-UiSaved
            $taskResolvedWorkdir = (Resolve-Path -LiteralPath $taskWorkdir.Text).Path
            $taskScript = Join-Path $PSScriptRoot 'AgentSetup.ps1'
            $taskCommandText = '& ' + (ConvertTo-UiLiteral $taskScript) + ' -Action Launch -ProfileId ' + (ConvertTo-UiLiteral $taskId.Text) +
                ' -Language ' + (ConvertTo-UiLiteral (Get-AssistantLanguage)) + ' -DataRoot ' + (ConvertTo-UiLiteral $DataRoot) + ' -WorkingDirectory ' + (ConvertTo-UiLiteral $taskResolvedWorkdir)
            $taskArguments = '-NoProfile -STA -ExecutionPolicy Bypass -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($taskCommandText))
            $null = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $taskArguments -WindowStyle Normal
            Write-UiLog (Get-AssistantText '已打开启动窗口；若客户端未打开，请查看该窗口提示。')
        } catch { Show-UiError $_ }
    })
    $taskBackup.Add_Click({ try { $null = Assert-UiSaved; Write-UiLog ((Get-AssistantText '备份成功：') + (Backup-AssistantProfile $taskId.Text $DataRoot)) } catch { Show-UiError $_ } })
    $taskRestore.Add_Click({
        try {
            $null = Assert-UiSaved
            $taskBackups = @(Get-AssistantBackups $taskId.Text $DataRoot)
            if (-not $taskBackups.Count) { throw (Get-AssistantText '该方案还没有备份。') }
            $taskPicker = New-Object Windows.Forms.Form; $taskPicker.Text = (Get-AssistantText '选择要恢复的备份'); $taskPicker.ClientSize = New-Object Drawing.Size(500,280)
            $taskPicker.StartPosition = 'CenterParent'; $taskPicker.Font = $taskForm.Font
            $taskList = New-Object Windows.Forms.ListBox; $taskList.SetBounds(15,15,470,195)
            foreach ($taskBackupName in $taskBackups) { $null = $taskList.Items.Add($taskBackupName) }; $taskList.SelectedIndex = 0
            $taskOk = New-Object Windows.Forms.Button; $taskOk.Text = (Get-AssistantText '恢复选中备份'); $taskOk.SetBounds(310,225,175,35); $taskOk.DialogResult = 'OK'
            $taskPicker.Controls.Add($taskList); $taskPicker.Controls.Add($taskOk)
            if ($taskPicker.ShowDialog($taskForm) -eq 'OK') {
                Restore-AssistantProfile $taskId.Text ([string]$taskList.SelectedItem) $DataRoot
                Load-UiProfile $taskId.Text; Write-UiLog (Get-AssistantText '恢复成功，恢复前的状态已另行备份。')
            }; $taskPicker.Dispose()
        } catch { Show-UiError $_ }
    })
    $taskOpen.Add_Click({ try { $null = Assert-UiSaved; Start-Process explorer.exe -ArgumentList ('"' + (Get-AssistantProfilePath $taskId.Text $DataRoot) + '"') } catch { Show-UiError $_ } })
    $taskInfo.Add_Click({ Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $PSScriptRoot $(if ((Get-AssistantLanguage) -eq 'en-US') { 'README.en.txt' } else { 'README.txt' })) + '"') })
    $taskExport.Add_Click({
        $taskDialog = $null
        try {
            $null = Assert-UiSaved
            $taskDialog = New-Object Windows.Forms.SaveFileDialog
            $taskDialog.Filter = 'Agent profile (*.agent-profile.json)|*.agent-profile.json'
            $taskDialog.FileName = $taskId.Text + '.agent-profile.json'; $taskDialog.DefaultExt = 'agent-profile.json'
            if ($taskDialog.ShowDialog() -eq 'OK') {
                $taskSharedPath = Export-AssistantProfile -Id $taskId.Text -Path $taskDialog.FileName -DataRoot $DataRoot -Force
                Write-UiLog ((Get-AssistantText '已导出无 Key 方案：') + $taskSharedPath)
            }
        } catch { Show-UiError $_ } finally { if ($taskDialog) { $taskDialog.Dispose() } }
    })
    $taskImport.Add_Click({
        $taskDialog = New-Object Windows.Forms.OpenFileDialog
        $taskDialog.Filter = 'Agent profile (*.agent-profile.json)|*.agent-profile.json'
        try { if ($taskDialog.ShowDialog() -eq 'OK') { Import-UiDraft $taskDialog.FileName } }
        catch { Show-UiError $_ } finally { $taskDialog.Dispose() }
    })
    $taskLocalModels.Add_Click({
        $taskSecure = $null
        try {
            if ($taskKey.Text) { $taskSecure = ConvertTo-SecureString $taskKey.Text -AsPlainText -Force }
            $taskForm.UseWaitCursor = $true; $taskLocalModels.Enabled = $false
            $taskFoundModels = @(Get-AssistantLocalModels -ProviderId (Get-UiProvider).id -BaseUrl $taskEndpoint.Text -ApiKey $taskSecure)
            $taskPreviousModel = $taskModels.Text; $taskModels.Items.Clear()
            foreach ($taskModel in $taskFoundModels) { $null = $taskModels.Items.Add($taskModel) }
            if ($taskPreviousModel) { $taskModels.Text = $taskPreviousModel } else { $taskModels.SelectedIndex = 0 }
            Write-UiLog ((Get-AssistantText '已读取本地模型数量：') + $taskFoundModels.Count)
        } catch { Show-UiError $_ }
        finally { $taskForm.UseWaitCursor = $false; Update-UiLocalHint; if ($taskSecure) { $taskSecure.Dispose() } }
    })
    $taskTimer = New-Object Windows.Forms.Timer; $taskTimer.Interval = 500
    $taskTimer.Add_Tick({
        if ($taskState.Busy -and $taskState.Process.HasExited) {
            try {
                if (-not (Test-Path -LiteralPath $taskState.ResultPath)) { throw (Get-AssistantText '后台操作意外退出，未写出结果。') }
                $taskResult = Get-Content -LiteralPath $taskState.ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
                Write-UiLog $taskResult.Message
            } catch { Show-UiError $_ }
            finally {
                $taskState.Busy = $false
                foreach ($taskControl in $taskMutable) { $taskControl.Enabled = $true }
                $taskProvider = Get-UiProvider; $taskClient = Get-UiClient
                $taskModelCatalog.Enabled = $taskClient.id -eq 'codex-desktop' -and $taskProvider.id -ne 'deepseek'
                $taskBrowse.Enabled = $taskModelCatalog.Enabled
                Update-UiLocalHint
            }
        }
    })
    $taskForm.Add_FormClosing({
        param($sender,$eventArgs)
        if ($taskState.Busy) { $eventArgs.Cancel = $true; Write-UiLog (Get-AssistantText '请等待后台操作结束再关闭。') }
    })
    $taskLanguage.Add_SelectedIndexChanged({
        if ($taskLanguage.SelectedIndex -lt 0) { return }
        $taskChosenLanguage = if ($taskLanguage.SelectedIndex -eq 0) { 'zh-CN' } else { 'en-US' }
        Set-AssistantLanguage -Language $taskChosenLanguage
        $taskState.Translating = $true
        $taskClientIndex = $taskClients.SelectedIndex
        $taskProviderIndex = $taskProviders.SelectedIndex
        try {
            $taskForm.SuspendLayout()
            $taskForm.Text = Get-AssistantText 'AgentNest 智巢 · 0.4'
            foreach ($taskControl in $taskForm.Controls) {
                if ($taskControl.Tag -is [string] -and $taskControl.Tag.StartsWith('i18n:')) { $taskControl.Text = Get-AssistantText $taskControl.Tag.Substring(5) }
            }
            $taskClients.Items.Clear()
            foreach ($taskClient in $taskCatalog.clients) { $null = $taskClients.Items.Add((Get-AssistantText $taskClient.name)) }
            $taskClients.SelectedIndex = $taskClientIndex
            $taskProviders.Items.Clear()
            foreach ($taskProvider in $taskCatalog.providers) {
                if ($taskProvider.routes.PSObject.Properties[(Get-UiClient).protocol]) { $null = $taskProviders.Items.Add((Get-AssistantText $taskProvider.name)) }
            }
            $taskProviders.SelectedIndex = $taskProviderIndex
            Update-UiLocalHint
        } finally { $taskForm.ResumeLayout(); $taskState.Translating = $false }
        if (-not $SmokeTest) {
            try { Save-AssistantLanguagePreference $taskChosenLanguage $DataRoot }
            catch { Write-UiLog ((Get-AssistantText '无法保存语言偏好：') + $_.Exception.Message) }
        }
        Write-UiLog (Get-AssistantText '语言已切换。')
    })
    $taskClients.SelectedIndex = 0
    Refresh-UiProfiles
    Write-UiLog (Get-AssistantText '先保存方案，再安装、检查连接或启动。OpenAI / Anthropic 模型 ID 请按你的账户可用模型填写。')
    if ($SmokeTest) {
        New-Item -ItemType Directory -Path $DataRoot -Force | Out-Null
        $taskForm.ShowInTaskbar = $false
        $taskForm.StartPosition = 'Manual'
        $taskForm.Location = New-Object Drawing.Point(-20000,-20000)
        $taskForm.Show()
        [Windows.Forms.Application]::DoEvents()
        if ($taskProviders.Items.Count -ne 3) { throw 'Codex 可选服务商过滤失败。' }
        $taskClients.SelectedIndex = 1
        if ($taskProviders.Items.Count -ne @($taskCatalog.providers | Where-Object { $_.routes.PSObject.Properties['messages'] }).Count) { throw 'Claude 可选服务商过滤失败。' }
        foreach ($taskClientIndex in @(2,3)) {
            $taskClients.SelectedIndex = $taskClientIndex
            if ($taskProviders.Items.Count -ne @($taskCatalog.providers | Where-Object { $_.routes.PSObject.Properties['chat'] }).Count) { throw 'Chat provider filtering failed.' }
            $taskProviders.SelectedItem = Get-AssistantText 'Google Gemini API'
            if ($taskEndpoint.Text -ne 'https://generativelanguage.googleapis.com/v1beta/openai') { throw 'Gemini endpoint not shown.' }
            if ($taskModelCatalog.Enabled) { throw 'Codex catalog should be disabled for terminal clients.' }
        }
        # Offline fixtures exercise the new controls without contacting a real local server.
        function Get-AssistantLocalModels { param($ProviderId,$BaseUrl,$ApiKey) @('fixture-model:7b','fixture-model:14b') }
        $taskProviders.SelectedItem = Get-AssistantText 'Ollama（本地）'
        if (-not $taskLocalModels.Enabled -or $taskEndpoint.ReadOnly -or $taskKey.Text) { throw 'Local provider controls are not ready.' }
        $taskLocalModels.PerformClick()
        if ($taskModels.Text -ne 'fixture-model:7b' -or $taskModels.Items.Count -ne 2) { throw 'Local model list did not update the selector.' }
        $taskId.Text = 'local-smoke'
        $taskSaveOnly.PerformClick()
        if (-not $taskState.SmokeSaved -or (Test-Path -LiteralPath (Join-Path (Join-Path $DataRoot 'profiles') 'local-smoke'))) { throw 'Keyless save-only button smoke failed.' }
        $taskDraftPath = Join-Path $DataRoot 'ui-draft.agent-profile.json'
        $taskDraftFixture = @{Format='agent-setup-profile';Version=1;Id='sample';ClientId='opencode';ProviderId='lmstudio';Model='fixture-import';BaseUrl='http://127.0.0.1:1234/v1'}
        [IO.File]::WriteAllText($taskDraftPath,($taskDraftFixture | ConvertTo-Json))
        $taskHadProfile = Test-Path -LiteralPath (Get-AssistantProfilePath sample $DataRoot)
        $taskKey.Text = 'previous-unsaved-key'
        Import-UiDraft $taskDraftPath
        if ((Get-UiClient).id -ne 'opencode' -or (Get-UiProvider).id -ne 'lmstudio' -or $taskModels.Text -ne 'fixture-import' -or
            $taskKey.Text -or $taskModelCatalog.Text -or ($taskHadProfile -and $taskId.Text -eq 'sample')) { throw 'Imported draft failed to select fields, clear secrets, or protect an existing ID.' }
        if (-not $taskHadProfile -and (Test-Path -LiteralPath (Get-AssistantProfilePath sample $DataRoot))) { throw 'Draft import unexpectedly saved a profile.' }
        $taskState.SmokeSaved = $false
        $taskClients.SelectedIndex = 0
        if ($taskModels.Text -ne 'deepseek-flash') { throw '默认模型未显示。' }
        $taskClients.SelectedIndex = 1
        $taskProviders.SelectedItem = Get-AssistantText '自定义 Messages 服务商'
        $taskId.Text = 'bilingual-smoke'
        $taskModels.Text = 'unsaved-model'
        $taskEndpoint.Text = 'https://example.com/v1'
        $taskKey.Text = 'ui-test-only-invalid-key'
        $taskModelCatalog.Text = 'unsaved-catalog.json'
        $taskWorkdir.Text = $DataRoot
        $taskOriginalLanguage = $taskLanguage.SelectedIndex
        foreach ($taskLanguageIndex in @(1,0,1,$taskOriginalLanguage)) {
            $taskLanguage.SelectedIndex = $taskLanguageIndex
            if ((Get-UiClient).id -ne 'claude-code' -or (Get-UiProvider).id -ne 'custom-messages' -or
                $taskId.Text -ne 'bilingual-smoke' -or $taskModels.Text -ne 'unsaved-model' -or
                $taskEndpoint.Text -ne 'https://example.com/v1' -or $taskKey.Text -ne 'ui-test-only-invalid-key' -or
                $taskModelCatalog.Text -ne 'unsaved-catalog.json' -or $taskWorkdir.Text -ne $DataRoot) { throw 'Language switching lost unsaved input or selected IDs.' }
            if ($taskSave.Text -ne (Get-AssistantText '1. 一键配置并安装')) { throw 'Button translation did not update.' }
            $taskExpectedClient = if ($taskLanguageIndex -eq 0) { 'Agent 客户端' } else { 'Agent client' }
            $taskClientLabel = @($taskForm.Controls | Where-Object Tag -eq 'i18n:Agent 客户端')[0]
            if ($taskClientLabel.Text -ne $taskExpectedClient) { throw 'Field label translation did not update.' }
        }
        $taskKey.Clear()
        $taskClients.SelectedIndex = 0
        $taskWorkdir.Text = $env:USERPROFILE
        $taskId.Text = 'gui-smoke'
        $taskKey.Text = 'ui-test-only-invalid-key'
        $taskSave.PerformClick()
        if (-not $taskState.SmokeSaved -or $taskKey.Text) { throw '保存按钮事件或 Key 清空检查失败。' }
        if (Test-Path -LiteralPath (Join-Path (Join-Path $DataRoot 'profiles') 'gui-smoke')) { throw '界面冒烟测试不应写入方案。' }
        $taskId.Text = 'my-codex-deepseek'
        if ($PreviewPath) {
            $taskBitmap = New-Object Drawing.Bitmap($taskForm.Width,$taskForm.Height)
            try { $taskForm.DrawToBitmap($taskBitmap,[Drawing.Rectangle]::new(0,0,$taskForm.Width,$taskForm.Height)); $taskBitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png) }
            finally { $taskBitmap.Dispose() }
        }
        $taskForm.Hide(); $taskTimer.Dispose(); $taskForm.Dispose()
        Write-Output 'UI smoke test passed; no profile or credential was written.'
        return
    }
    $taskTimer.Start()
    try { $null = $taskForm.ShowDialog() } finally { $taskTimer.Dispose(); $taskKey.Clear(); $taskForm.Dispose() }
}
