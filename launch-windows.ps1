# Procura Windows Launcher
# Starts the Procura Express app and the local n8n workflow engine together.
# n8n runs in the background and is checked for readiness before its browser tab opens.

param(
    [switch]$NoN8n,
    [switch]$NoBrowser,
    [int]$Port = 0,
    [int]$N8nPort = 0
)

$ErrorActionPreference = "Stop"

if ($PSScriptRoot) {
    Set-Location -Path $PSScriptRoot
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "       Procura Procurement Sandbox       " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Helper: pause without closing the host window
# ---------------------------------------------------------------------------
function Safe-Pause([string]$Prompt = "Press Enter to close...") {
    Write-Host ""
    try {
        Read-Host $Prompt
    } catch {
        # Non-interactive host; just return
    }
}

# ---------------------------------------------------------------------------
# Helper: test whether a TCP port is already bound
# ---------------------------------------------------------------------------
function Test-PortInUse([int]$CheckPort) {
    $conn = Get-NetTCPConnection -LocalPort $CheckPort -State Listen -ErrorAction SilentlyContinue
    return ($null -ne $conn -and @($conn).Count -gt 0)
}

function Test-N8nReady([int]$CheckPort) {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:$CheckPort/healthz/readiness" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}


# ---------------------------------------------------------------------------
# Main launcher body
# ---------------------------------------------------------------------------
try {
    # 1. Check Node.js and npm (for the Procura app itself)
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: Node.js 18+ and npm are required to run Procura." -ForegroundColor Red
        Write-Host "       Download and install Node.js from https://nodejs.org/" -ForegroundColor Yellow
        Safe-Pause
        return
    }

    # 2. Install Procura dependencies if node_modules is missing
    if (-not (Test-Path "node_modules")) {
        Write-Host "Installing Node.js dependencies..." -ForegroundColor Yellow
        npm install
        if ($LASTEXITCODE -ne 0) {
            Write-Host "npm install encountered an error." -ForegroundColor Red
            Safe-Pause
            return
        }
    }

    # 3. Load .env file if present
    if (Test-Path ".env") {
        Write-Host "Loading configuration from .env..." -ForegroundColor DarkGray
        $envLines = Get-Content ".env"
        foreach ($line in $envLines) {
            $trimmed = $line.Trim()
            if ($trimmed -and -not $trimmed.StartsWith("#") -and $trimmed.Contains("=")) {
                $parts = $trimmed.Split("=", 2)
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                    $val = $val.Substring(1, $val.Length - 2)
                }
                if (-not [string]::IsNullOrWhiteSpace($key) -and [string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable($key))) {
                    [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
                }
            }
        }
    }

    # 4. Check or configure DATABASE_URL
    if ([string]::IsNullOrWhiteSpace($env:DATABASE_URL)) {
        $defaultDbUrl = "postgres://postgres:postgres@localhost:5432/procura"
        Write-Host "DATABASE_URL is not configured." -ForegroundColor Yellow
        Write-Host "Default: $defaultDbUrl" -ForegroundColor DarkGray

        $inputUrl = ""
        try {
            $inputUrl = Read-Host "Enter PostgreSQL connection URL [Press Enter to use default]"
        } catch {
            $inputUrl = ""
        }

        if ([string]::IsNullOrWhiteSpace($inputUrl)) {
            $env:DATABASE_URL = $defaultDbUrl
        } else {
            $env:DATABASE_URL = $inputUrl.Trim()
        }

        if (-not (Test-Path ".env")) {
            try {
                $envContent = "DATABASE_URL=" + $env:DATABASE_URL + "`r`nPORT=3000`r`n"
                [System.IO.File]::WriteAllText((Join-Path (Get-Location) ".env"), $envContent)
                Write-Host "Created .env configuration file." -ForegroundColor Green
            } catch {
                # Ignore file write error
            }
        }
    }

    # 5. Determine effective ports
    $procuraPort = if ($Port -gt 0) { $Port } elseif ($env:PORT) { [int]$env:PORT } else { 3000 }
    $n8nPort     = if ($N8nPort -gt 0) { $N8nPort } else { 5678 }

    # 6. Apply database schema and seed data
    Write-Host "Applying PostgreSQL schema and seed data..." -ForegroundColor Yellow
    $dbOk = $true
    try {
        node db/setup.js
        if ($LASTEXITCODE -ne 0) { $dbOk = $false }
    } catch {
        $dbOk = $false
    }

    if (-not $dbOk) {
        Write-Host ""
        Write-Host "Could not connect to PostgreSQL at:" -ForegroundColor Yellow
        Write-Host "  $env:DATABASE_URL" -ForegroundColor White
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor DarkGray
        Write-Host " - Make sure PostgreSQL service is running." -ForegroundColor DarkGray
        Write-Host " - Verify the username, password, host, port, and database in .env" -ForegroundColor DarkGray
        Write-Host " - Refer to docs/setup-and-architecture.md for setup instructions." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Starting the web server anyway so you can view the interface..." -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host "Database ready." -ForegroundColor Green
    }

    # -----------------------------------------------------------------------
    # 7. Launch n8n in the background (unless -NoN8n)
    # -----------------------------------------------------------------------
    $n8nNodeExe  = Join-Path $PSScriptRoot ".tools\node-v24.21.0-win-x64\node.exe"
    $n8nEntry    = Join-Path $PSScriptRoot "automation\n8n\node_modules\n8n\bin\n8n"
    $n8nStartPs1 = Join-Path $PSScriptRoot "automation\n8n\start.ps1"
    $n8nSetupPs1 = Join-Path $PSScriptRoot "automation\n8n\setup.ps1"

    if (-not $NoN8n) {
        Write-Host ""
        Write-Host "--- n8n Workflow Engine ---" -ForegroundColor Magenta

        if (Test-PortInUse $n8nPort) {
            if (Test-N8nReady $n8nPort) {
                Write-Host "n8n is already running at http://127.0.0.1:$n8nPort" -ForegroundColor Green
            } else {
                Write-Host "Port $n8nPort is occupied, but n8n is not ready. Check the process using that port." -ForegroundColor Red
                $NoN8n = $true
            }
        } else {
            # Auto-setup n8n if runtime or packages are missing
            if (-not (Test-Path -LiteralPath $n8nNodeExe) -or -not (Test-Path -LiteralPath $n8nEntry)) {
                Write-Host "n8n runtime or packages not found - running setup..." -ForegroundColor Yellow
                try {
                    & powershell -NoProfile -ExecutionPolicy Bypass -File $n8nSetupPs1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "n8n setup failed (exit $LASTEXITCODE). Skipping n8n launch." -ForegroundColor Red
                        $NoN8n = $true
                    }
                } catch {
                    Write-Host "n8n setup error: $($_.Exception.Message)" -ForegroundColor Red
                    $NoN8n = $true
                }
            }

            if (-not $NoN8n) {
                Write-Host "Starting n8n at http://127.0.0.1:$n8nPort in the background..." -ForegroundColor Magenta

                $n8nLogFolder = Join-Path $PSScriptRoot "automation\n8n\.data"
                $n8nOutputLog = Join-Path $n8nLogFolder "n8n-server.log"
                $n8nErrorLog = Join-Path $n8nLogFolder "n8n-server-error.log"
                $n8nArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$n8nStartPs1`""

                try {
                    New-Item -ItemType Directory -Path $n8nLogFolder -Force | Out-Null
                    $n8nProcess = Start-Process powershell -ArgumentList $n8nArgs -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $n8nOutputLog -RedirectStandardError $n8nErrorLog -PassThru
                    $n8nDeadline = [DateTime]::UtcNow.AddSeconds(120)
                    $n8nReady = $false
                    do {
                        if ($n8nProcess.HasExited) {
                            throw "n8n exited with code $($n8nProcess.ExitCode)."
                        }
                        $n8nReady = Test-N8nReady $n8nPort
                        if (-not $n8nReady) { Start-Sleep -Milliseconds 500 }
                    } while (-not $n8nReady -and [DateTime]::UtcNow -lt $n8nDeadline)
                    if (-not $n8nReady) { throw "n8n did not become ready within 120 seconds." }
                    Write-Host "n8n is ready at http://127.0.0.1:$n8nPort" -ForegroundColor Green
                } catch {
                    $NoN8n = $true
                    Write-Host "Could not start n8n: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "Startup logs: $n8nOutputLog and $n8nErrorLog" -ForegroundColor Yellow
                }
            }
        }
    }

    # -----------------------------------------------------------------------
    # 8. Open browser tabs
    # -----------------------------------------------------------------------
    if (-not $NoBrowser) {
        try { Start-Process "http://localhost:$procuraPort" } catch { }
        if (-not $NoN8n) {
            Start-Sleep -Milliseconds 600
            try { Start-Process "http://127.0.0.1:$n8nPort" } catch { }
        }
    }

    # -----------------------------------------------------------------------
    # 9. Start Procura
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- Procura App ---" -ForegroundColor Cyan

    if (Test-PortInUse $procuraPort) {
        Write-Host "Procura is already running at http://localhost:$procuraPort" -ForegroundColor Green
        Write-Host ""
        Write-Host "Active endpoints:" -ForegroundColor DarkGray
        Write-Host "  Procura  ->  http://localhost:$procuraPort" -ForegroundColor White
        if (-not $NoN8n) {
            Write-Host "  n8n      ->  http://127.0.0.1:$n8nPort" -ForegroundColor White
        }
        Write-Host ""
        Safe-Pause "Press Enter to exit this launcher (services keep running)..."
    } else {
        Write-Host "Starting Procura at http://localhost:$procuraPort" -ForegroundColor Green
        Write-Host "Press Ctrl+C to stop the server." -ForegroundColor DarkGray
        Write-Host ""

        if ($Port -gt 0) { $env:PORT = "$procuraPort" }

        npm run dev
    }

} catch {
    Write-Host ""
    Write-Host "An error occurred while launching Procura:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Safe-Pause
} finally {
    Write-Host ""
    Write-Host "Procura session ended." -ForegroundColor Yellow
    Safe-Pause "Press Enter to close this window..."
}
