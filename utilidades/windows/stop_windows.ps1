# utilidades/windows/stop_windows.ps1
$PROJECT_DIR = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$LOG_DIR = Join-Path $PROJECT_DIR "utilidades\logs"

Write-Host "Deteniendo servicios Flask..."
foreach ($service in @("vector_service", "llm_service", "gateway")) {
    $pidFile = "$LOG_DIR\$service.pid"
    if (Test-Path $pidFile) {
        $processPid = Get-Content $pidFile
        Stop-Process -Id $processPid -Force -ErrorAction SilentlyContinue
        Write-Host "  $service detenido (PID $processPid)"
        Remove-Item $pidFile
    } else {
        Write-Host "  $service - no se encontro PID"
    }
}

Write-Host ""
Write-Host "Deteniendo Qdrant..."
Set-Location $PROJECT_DIR
docker compose down

Write-Host ""
Write-Host "Deteniendo Ollama..."
Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue
Write-Host "  Ollama detenido"

Write-Host ""
Write-Host "Sistema RAG apagado."