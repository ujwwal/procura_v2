param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$N8nArguments
)

$ErrorActionPreference = "Stop"

$nodeVersion = "24.21.0"
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$runtimePath = Join-Path $workspaceRoot ".tools\node-v$nodeVersion-win-x64"
$nodeExe = Join-Path $runtimePath "node.exe"
$n8nEntry = Join-Path $PSScriptRoot "node_modules\n8n\bin\n8n"

if (-not (Test-Path -LiteralPath $nodeExe) -or -not (Test-Path -LiteralPath $n8nEntry)) {
    throw "n8n is not set up. Run 'npm run n8n:setup' first."
}

$localEnvironmentFile = Join-Path $PSScriptRoot ".env"
if (Test-Path -LiteralPath $localEnvironmentFile) {
    foreach ($line in Get-Content -LiteralPath $localEnvironmentFile) {
        $trimmedLine = $line.Trim()
        if (-not $trimmedLine -or $trimmedLine.StartsWith("#")) {
            continue
        }

        $parts = $trimmedLine.Split("=", 2)
        if ($parts.Count -eq 2) {
            [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
        }
    }
}

function Set-DefaultProcessVariable([string]$Name, [string]$Value) {
    $currentValue = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($currentValue)) {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    }
}

$dataFolder = Join-Path $PSScriptRoot ".data"
New-Item -ItemType Directory -Path $dataFolder -Force | Out-Null

Set-DefaultProcessVariable "N8N_USER_FOLDER" $dataFolder
Set-DefaultProcessVariable "N8N_HOST" "127.0.0.1"
Set-DefaultProcessVariable "N8N_LISTEN_ADDRESS" "127.0.0.1"
Set-DefaultProcessVariable "N8N_PORT" "5678"
Set-DefaultProcessVariable "N8N_PROTOCOL" "http"
Set-DefaultProcessVariable "N8N_SECURE_COOKIE" "false"
Set-DefaultProcessVariable "GENERIC_TIMEZONE" "Asia/Kolkata"
Set-DefaultProcessVariable "TZ" "Asia/Kolkata"
Set-DefaultProcessVariable "N8N_DIAGNOSTICS_ENABLED" "false"
Set-DefaultProcessVariable "N8N_PERSONALIZATION_ENABLED" "false"
Set-DefaultProcessVariable "N8N_UNVERIFIED_PACKAGES_ENABLED" "false"
Set-DefaultProcessVariable "N8N_RUNNERS_TASK_TIMEOUT" "300"
Set-DefaultProcessVariable "N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES" "268435456"
Set-DefaultProcessVariable "N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES" "1000"
Set-DefaultProcessVariable "EXECUTIONS_DATA_PRUNE" "true"
Set-DefaultProcessVariable "EXECUTIONS_DATA_MAX_AGE" "168"

$env:PATH = "$runtimePath;$env:PATH"

Push-Location $PSScriptRoot
try {
    & $nodeExe $n8nEntry @N8nArguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
