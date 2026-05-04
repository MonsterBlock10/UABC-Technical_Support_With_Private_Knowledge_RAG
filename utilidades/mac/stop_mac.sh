#!/bin/bash
# utilidades/mac/stop_macos.sh

PROJECT_DIR="$HOME/Documents/Tareas/Sistemas-Distribuidos/Proyecto"
LOG_DIR="$PROJECT_DIR/utilidades/logs"

echo "Deteniendo servicios Flask..."
for service in vector_service llm_service gateway; do
    PID_FILE="$LOG_DIR/$service.pid"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        kill "$PID" 2>/dev/null && echo "  $service detenido (PID $PID)"
        rm "$PID_FILE"
    else
        echo "  $service — no se encontro PID"
    fi
done

echo ""
echo "Deteniendo Qdrant..."
cd "$PROJECT_DIR"
docker compose down

echo ""
echo "Deteniendo Ollama..."
brew services stop ollama

echo ""
echo "Sistema RAG apagado."

