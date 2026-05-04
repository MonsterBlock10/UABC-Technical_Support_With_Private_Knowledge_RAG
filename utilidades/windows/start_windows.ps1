# utilidades/windows/start_windows.ps1

$PROJECT_DIR = "$env:USERPROFILE\Documents\Tareas\Sistemas-Distribuidos\Proyecto"
$VENV        = "$PROJECT_DIR\rag_venv\Scripts\Activate.ps1"
$LOG_DIR     = "$PROJECT_DIR\utilidades\logs"

New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null

Write-Host "Verificando dependencias Python..."
& "$VENV"

$requirements = Get-Content "$PROJECT_DIR\utilidades\requirements.txt"
$missing = $false

foreach ($line in $requirements) {
    if ($line -match "^#" -or [string]::IsNullOrWhiteSpace($line)) { continue }
    $pkg     = ($line -split "==")[0].ToLower()
    $version = ($line -split "==")[1]
    $info    = pip show $pkg 2>&1
    $installedLine = $info | Where-Object { $_ -match "^Version:" }
    $installed = if ($installedLine) { ($installedLine -split " ")[1] } else { $null }

    if (-not $installed) {
        Write-Host "  Falta: $pkg"
        $missing = $true
    } elseif ($installed -ne $version) {
        Write-Host "  Version incorrecta: $pkg (instalado $installed, requerido $version)"
        $missing = $true
    }
}

if ($missing) {
    Write-Host "  Instalando dependencias faltantes..."
    pip install -r "$PROJECT_DIR\utilidades\requirements.txt"
    Write-Host "  Dependencias instaladas"
} else {
    Write-Host "  Todas las dependencias estan presentes"
}

Write-Host ""
Write-Host "Verificando Ollama..."
$ollamaPath = Get-Command ollama -ErrorAction SilentlyContinue

if (-not $ollamaPath) {
    Write-Host "  Ollama no encontrado."
    Write-Host "  Descarga e instala Ollama desde: https://ollama.com/download"
    Write-Host "  Luego vuelve a ejecutar este script."
    exit 1
} else {
    Write-Host "  Ollama ya esta instalado"
}

$models = ollama list
if ($models -notmatch "gemma2:2b") {
    Write-Host "  Descargando gemma2:2b..."
    ollama pull gemma2:2b
    Write-Host "  gemma2:2b descargado"
} else {
    Write-Host "  gemma2:2b ya esta disponible"
}

Write-Host ""
Write-Host "Iniciando Ollama..."
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Levantando Qdrant..."
Set-Location $PROJECT_DIR
docker compose up -d
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Iniciando Vector Service..."
$vs = Start-Process "python" -ArgumentList "app.py" `
    -WorkingDirectory "$PROJECT_DIR\vector_service" `
    -RedirectStandardOutput "$LOG_DIR\vector_service.log" `
    -WindowStyle Hidden -PassThru
$vs.Id | Out-File "$LOG_DIR\vector_service.pid"
Start-Sleep -Seconds 4

Write-Host "Iniciando LLM Service..."
$llm = Start-Process "python" -ArgumentList "app.py" `
    -WorkingDirectory "$PROJECT_DIR\llm_service" `
    -RedirectStandardOutput "$LOG_DIR\llm_service.log" `
    -WindowStyle Hidden -PassThru
$llm.Id | Out-File "$LOG_DIR\llm_service.pid"
Start-Sleep -Seconds 2

Write-Host "Iniciando Gateway..."
$gw = Start-Process "python" -ArgumentList "app.py" `
    -WorkingDirectory "$PROJECT_DIR\gateway" `
    -RedirectStandardOutput "$LOG_DIR\gateway.log" `
    -WindowStyle Hidden -PassThru
$gw.Id | Out-File "$LOG_DIR\gateway.pid"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Sistema RAG levantado. Verificando health..."
$response = Invoke-RestMethod -Uri "http://localhost:5000/health"
$response | ConvertTo-Json