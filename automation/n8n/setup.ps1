param()

$ErrorActionPreference = "Stop"

$nodeVersion = "24.21.0"
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$toolsRoot = Join-Path $workspaceRoot ".tools"
$runtimeName = "node-v$nodeVersion-win-x64"
$runtimePath = Join-Path $toolsRoot $runtimeName
$nodeExe = Join-Path $runtimePath "node.exe"
$npmCmd = Join-Path $runtimePath "npm.cmd"

if (-not (Test-Path -LiteralPath $nodeExe)) {
    New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null

    $archivePath = Join-Path $toolsRoot "$runtimeName.zip"
    $downloadBase = "https://nodejs.org/dist/v$nodeVersion"

    Write-Host "Downloading Node.js $nodeVersion for n8n..."
    Invoke-WebRequest -Uri "$downloadBase/$runtimeName.zip" -OutFile $archivePath

    $checksums = (Invoke-WebRequest -Uri "$downloadBase/SHASUMS256.txt").Content
    $checksumLine = ($checksums -split "`n" | Where-Object {
        $_ -match "$([regex]::Escape($runtimeName)).zip$"
    } | Select-Object -First 1).Trim()

    if (-not $checksumLine) {
        throw "Could not find the checksum for $runtimeName.zip."
    }

    $expectedHash = ($checksumLine -split "\s+")[0].ToUpperInvariant()
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToUpperInvariant()

    if ($actualHash -ne $expectedHash) {
        throw "Node.js archive checksum mismatch."
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $toolsRoot -Force
    Remove-Item -LiteralPath $archivePath -Force
}

$env:PATH = "$runtimePath;$env:PATH"

Write-Host "Using $(& $nodeExe --version) for n8n."
Push-Location $PSScriptRoot
try {
    & $npmCmd install
    if ($LASTEXITCODE -ne 0) {
        throw "n8n dependency installation failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Write-Host "n8n is ready. Start it with: npm run n8n:start"
