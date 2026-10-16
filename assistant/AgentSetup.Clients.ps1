# Additional Windows terminal clients. This file runs inside the core module.
function Find-AssistantTool {
    param([string]$Name, [string]$PackagePrefix, [string[]]$Candidates = @())
    foreach ($taskCandidate in $Candidates) {
        if (Test-Path -LiteralPath $taskCandidate -PathType Leaf) { return $taskCandidate }
    }
    $taskCommand = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($taskCommand) { return $taskCommand.Source }
    $taskLinks = Join-Path $env:LOCALAPPDATA ('Microsoft/WinGet/Links/' + $Name)
    if (Test-Path -LiteralPath $taskLinks -PathType Leaf) { return $taskLinks }
    # An installer can add a PATH entry that this already-running process has not inherited.
    $taskPackages = Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Packages'
    if ($PackagePrefix -and (Test-Path -LiteralPath $taskPackages)) {
        foreach ($taskFolder in Get-ChildItem -LiteralPath $taskPackages -Directory -Filter ($PackagePrefix + '_*')) {
            $taskFound = Get-ChildItem -LiteralPath $taskFolder.FullName -Filter $Name -File -Recurse | Select-Object -First 1
            if ($taskFound) { return $taskFound.FullName }
        }
    }
}

function Get-AssistantManagedAider {
    param([string]$DataRoot)
    Join-Path (Get-AssistantDataRoot $DataRoot) 'tools/aider/venv/Scripts/aider.exe'
}

function Test-AssistantManagedAider {
    param([string]$DataRoot)
    if (-not (Test-Path -LiteralPath (Get-AssistantManagedAider $DataRoot) -PathType Leaf)) { return $false }
    $taskMarker = Join-Path (Get-AssistantDataRoot $DataRoot) 'tools/aider/install.json'
    try {
        $taskInstalled = Get-Content -LiteralPath $taskMarker -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        return ($taskInstalled.Format -eq 1 -and $taskInstalled.DotenvMinimum -eq '1.2.0')
    } catch { return $false }
}

function Invoke-AssistantWinget {
    param([string]$PackageId)
    $taskWinget = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $taskWinget) { throw (Get-AssistantText '请先从 Microsoft Store 安装或更新“应用安装程序”，以提供 winget。') }
    & $taskWinget.Source install --id $PackageId --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
    if ($LASTEXITCODE -ne 0) { throw ((Get-AssistantText '软件包安装失败：') + $PackageId) }
}

function ConvertTo-AssistantProcessArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows CommandLineToArgvW quoting. No shell is used and secrets are never arguments.
    '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function New-AssistantProcessInfo {
    param([string]$Executable, [string[]]$Arguments = @(), [string]$WorkingDirectory, [hashtable]$Environment = @{})
    $taskInfo = [Diagnostics.ProcessStartInfo]::new()
    $taskInfo.FileName = $Executable
    $taskInfo.Arguments = (@($Arguments | ForEach-Object { ConvertTo-AssistantProcessArgument $_ }) -join ' ')
    $taskInfo.UseShellExecute = $false
    if ($WorkingDirectory) { $taskInfo.WorkingDirectory = $WorkingDirectory }
    foreach ($taskName in $Environment.Keys) {
        if ($null -eq $Environment[$taskName]) { $taskInfo.EnvironmentVariables.Remove($taskName) }
        else { $taskInfo.EnvironmentVariables[$taskName] = $Environment[$taskName] }
    }
    $taskInfo
}

function Invoke-AssistantNativeProcess {
    param([string]$Executable, [string[]]$Arguments, [hashtable]$Environment = @{})
    $taskInfo = New-AssistantProcessInfo -Executable $Executable -Arguments $Arguments -Environment $Environment
    $taskProcess = [Diagnostics.Process]::Start($taskInfo)
    try {
        $taskProcess.WaitForExit()
        if ($taskProcess.ExitCode -ne 0) { throw (Get-AssistantText '安装依赖失败，请查看安装窗口输出。') }
    } finally { $taskProcess.Dispose() }
}

function Install-AssistantAider {
    param([string]$DataRoot)
    $taskUv = Find-AssistantTool -Name uv.exe -PackagePrefix astral-sh.uv -Candidates @((Join-Path $env:USERPROFILE '.local/bin/uv.exe'))
    if (-not $taskUv) {
        Invoke-AssistantWinget astral-sh.uv
        $taskUv = Find-AssistantTool -Name uv.exe -PackagePrefix astral-sh.uv -Candidates @((Join-Path $env:USERPROFILE '.local/bin/uv.exe'))
    }
    if (-not $taskUv) { throw (Get-AssistantText '未找到 uv，请重新打开助手后重试。') }
    $taskVenv = Join-Path (Get-AssistantDataRoot $DataRoot) 'tools/aider/venv'
    New-Item -ItemType Directory -Path (Split-Path -Parent $taskVenv) -Force | Out-Null
    $taskMarker = Join-Path (Split-Path -Parent $taskVenv) 'install.json'
    if (Test-Path -LiteralPath $taskMarker) { Remove-Item -LiteralPath $taskMarker -Force }
    Invoke-AssistantNativeProcess -Executable $taskUv -Arguments @('venv','--python','3.12',$taskVenv)
    # Require dotenv's documented opt-out to prevent project/home .env from rerouting the key.
    Invoke-AssistantNativeProcess -Executable $taskUv -Arguments @('pip','install','--python',(Join-Path $taskVenv 'Scripts/python.exe'),'aider-chat','python-dotenv>=1.2.0')
    Write-AssistantText $taskMarker (@{ Format = 1; Python = '3.12'; DotenvMinimum = '1.2.0' } | ConvertTo-Json)
}

function Get-AssistantTerminalArguments {
    param($Profile, [string]$ProfilePath)
    switch ($Profile.ClientId) {
        'opencode' { @('--model', ('assistant/' + $Profile.Model)) }
        'aider' {
            @('--config',(Join-Path $ProfilePath 'aider/config.yml'),
                '--model',('openai/' + $Profile.Model),'--openai-api-base',$Profile.BaseUrl,
                '--input-history-file',(Join-Path $ProfilePath 'aider/input.history'),
                '--chat-history-file',(Join-Path $ProfilePath 'aider/chat.history.md'))
        }
    }
}
