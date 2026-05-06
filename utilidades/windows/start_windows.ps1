$PROJECT_DIR = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$VENV_PATH   = Join-Path $PROJECT_DIR "rag_venv\Scripts\Activate.ps1"
$LOG_DIR     = Join-Path $PROJECT_DIR "utilidades\logs"
$REQ_FILE    = Join-Path $PROJECT_DIR "utilidades\requirements.txt"
$DOCS_PATH   = Join-Path $PROJECT_DIR "docs" 

if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR | Out-Null }

Write-Host "`n--- Iniciando Sistema desde: $PROJECT_DIR ---" -ForegroundColor Cyan

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "  [!] Docker no encontrado. Por favor abre Docker Desktop." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $VENV_PATH)) {
    Write-Host "  Creando entorno virtual..." -ForegroundColor Yellow
    Set-Location $PROJECT_DIR
    python -m venv rag_venv
}
& "$VENV_PATH"
Write-Host "  Verificando dependencias..."
pip install -r "$REQ_FILE" --quiet

Write-Host "`nLevantando Qdrant..."
Set-Location $PROJECT_DIR
docker compose up -d --force-recreate
Start-Sleep -Seconds 5

$services = @(
    @{ name = "vector_service"; port = 5001 },
    @{ name = "llm_service";    port = 5002 },
    @{ name = "gateway";        port = 5000 }
)
$processIds = @()

foreach ($svc in $services) {
    Write-Host "Iniciando $($svc.name)..."
    $proc = Start-Process "python" -ArgumentList "app.py" `
        -WorkingDirectory (Join-Path $PROJECT_DIR $svc.name) `
        -RedirectStandardOutput (Join-Path $LOG_DIR "$($svc.name).log") `
        -RedirectStandardError (Join-Path $LOG_DIR "$($svc.name)_error.log") `
        -WindowStyle Hidden -PassThru
    
    $processIds += $proc.Id
    Start-Sleep -Seconds 3 # Pequeña pausa entre inicios
}

Write-Host "`nVerificando estabilidad del sistema..." -ForegroundColor Cyan
$maxRetries = 6
$ready = $false

for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        Write-Host "  Intento $i de $maxRetries... " -NoNewline
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:5000/health" -TimeoutSec 10
        if ($resp.status -eq "ok") {
            Write-Host "¡ONLINE!" -ForegroundColor Green
            $ready = $true
            break
        }
    } catch {
        Write-Host "esperando..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

Write-Host "`nIngestando documentos de $DOCS_PATH..."
if (Test-Path $DOCS_PATH) {
    Get-ChildItem -Path $DOCS_PATH -File | ForEach-Object {
        if (".txt", ".md", ".pdf" -contains $_.Extension.ToLower()) {
            # Usamos curl.exe nativo para evitar bloqueos de Invoke-RestMethod en archivos
            $result = curl.exe -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:5000/ingest -F "file=@$($_.FullName)"
            Write-Host "  [$result] $($_.Name)"
        }
    }
} else {
    Write-Host "  [!] Carpeta $DOCS_PATH no encontrada." -ForegroundColor Yellow
}

Write-Host "`n===================================================="
Write-Host "SISTEMA LISTO. Escribe 'salir' para terminar."
Write-Host "====================================================`n"

$MODEL = "fast"
while ($true) {
    $pregunta = Read-Host "Pregunta"
    
    if ($pregunta -eq "salir") { break }
    if ($pregunta -eq "fast" -or $pregunta -eq "quality") {
        $MODEL = $pregunta
        Write-Host "  Modelo cambiado a: $MODEL" -ForegroundColor Cyan
        continue
    }
    if ([string]::IsNullOrWhiteSpace($pregunta)) { continue }

    try {
        $body = @{ question = $pregunta; model = $MODEL } | ConvertTo-Json
        
        # TIMEOUT EXTENDIDO PARA OLLAMA (120 SEGUNDOS)
        $res = Invoke-RestMethod -Uri "http://127.0.0.1:5000/query" `
                                 -Method POST `
                                 -ContentType "application/json" `
                                 -Body $body `
                                 -TimeoutSec 120
        
        Write-Host "`nRespuesta: " -ForegroundColor Green -NoNewline; Write-Host $res.answer
        Write-Host "Fuentes: " -ForegroundColor Gray -NoNewline; Write-Host ($res.fuentes -join ", ") "`n"
    } catch {
        $msg = $_.Exception.Message
        if ($msg -like "*time out*") {
            Write-Host "`n[!] Error: El modelo está tardando mucho en cargar. Intenta de nuevo en 10 segundos." -ForegroundColor Yellow
        } else {
            Write-Host "`n[!] Error de Conexion: $msg" -ForegroundColor Red
            Write-Host "Tip: Revisa utilidades\logs\gateway_error.log" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

# 8. CIERRE DE SERVICIOS
Write-Host "`nCerrando servicios..." -ForegroundColor Yellow
foreach ($id in $processIds) { 
    Stop-Process -Id $id -ErrorAction SilentlyContinue 
}
docker compose down
Write-Host "Adios!" -ForegroundColor Cyan