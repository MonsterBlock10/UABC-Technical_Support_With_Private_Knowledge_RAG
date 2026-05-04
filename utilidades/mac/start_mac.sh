#!/bin/bash
# utilidades/mac/start_macos.sh

PROJECT_DIR="$HOME/Documents/Tareas/Sistemas-Distribuidos/Proyecto"
VENV="$PROJECT_DIR/rag_venv/bin/activate"
LOG_DIR="$PROJECT_DIR/utilidades/logs"

mkdir -p "$LOG_DIR"

echo "Verificando dependencias Python..."
source "$VENV"

MISSING=false
while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    pkg=$(echo "$line" | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]')
    version=$(echo "$line" | cut -d'=' -f3)
    installed=$(pip show "$pkg" 2>/dev/null | grep "^Version:" | cut -d' ' -f2)

    if [ -z "$installed" ]; then
        echo "  Falta: $pkg"
        MISSING=true
    elif [ "$installed" != "$version" ]; then
        echo "  Version incorrecta: $pkg (instalado $installed, requerido $version)"
        MISSING=true
    fi
done < "$PROJECT_DIR/utilidades/requirements.txt"

if [ "$MISSING" = true ]; then
    echo "  Instalando dependencias faltantes..."
    pip install -r "$PROJECT_DIR/utilidades/requirements.txt"
    echo "  Dependencias instaladas"
else
    echo "  Todas las dependencias estan presentes"
fi

echo ""
echo "Verificando Ollama..."
if ! command -v ollama &>/dev/null; then
    echo "  Ollama no encontrado."
    echo "  Instala Ollama desde https://ollama.com/download o con: brew install ollama"
    exit 1
else
    echo "  Ollama ya esta instalado"
fi

echo "  Verificando modelo gemma2:2b..."
if ! ollama list | grep -q "gemma2:2b"; then
    echo "  Descargando gemma2:2b..."
    ollama pull gemma2:2b
    echo "  gemma2:2b descargado"
else
    echo "  gemma2:2b ya esta disponible"
fi

echo ""
echo "Iniciando Ollama..."
brew services start ollama
sleep 3

echo ""
echo "Levantando Qdrant..."
cd "$PROJECT_DIR"
docker compose up -d
sleep 2

echo ""
echo "Iniciando Vector Service..."
cd "$PROJECT_DIR/vector_service"
nohup python3 app.py > "$LOG_DIR/vector_service.log" 2>&1 &
echo $! > "$LOG_DIR/vector_service.pid"
sleep 4

echo "Iniciando LLM Service..."
cd "$PROJECT_DIR/llm_service"
nohup python3 app.py > "$LOG_DIR/llm_service.log" 2>&1 &
echo $! > "$LOG_DIR/llm_service.pid"
sleep 2

echo "Iniciando Gateway..."
cd "$PROJECT_DIR/gateway"
nohup python3 app.py > "$LOG_DIR/gateway.log" 2>&1 &
echo $! > "$LOG_DIR/gateway.pid"
sleep 3

echo ""
echo "Sistema RAG levantado. Verificando health..."
curl -s http://localhost:5000/health | python3 -m json.tool