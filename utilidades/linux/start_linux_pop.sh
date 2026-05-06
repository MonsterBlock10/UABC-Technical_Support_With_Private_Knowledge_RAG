#!/bin/bash
# utilidades/linux/start_linux_pop.sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"

VENV="$PROJECT_DIR/rag_venv/bin/activate"
LOG_DIR="$PROJECT_DIR/utilidades/logs"
DOCS_DIR="$PROJECT_DIR/docs"
REQ_FILE="$PROJECT_DIR/utilidades/requirements.txt"

mkdir -p "$LOG_DIR"

echo "--- Iniciando Sistema RAG (Portable Linux) ---"
echo "Carpeta Raíz: $PROJECT_DIR"

if [ -f "$VENV" ]; then
    source "$VENV"
else
    echo " [!] No se encontró el entorno virtual en $VENV"
    echo " Intentando crear uno..."
    python3 -m venv "$PROJECT_DIR/rag_venv"
    source "$VENV"
fi

echo "Verificando dependencias..."
pip install -r "$REQ_FILE" --quiet

echo "Asegurando Ollama..."
sudo systemctl start ollama
if ! ollama list | grep -q "gemma2:2b"; then
    echo " Descargando gemma2:2b..."
    ollama pull gemma2:2b
fi


echo "Levantando Infraestructura..."
cd "$PROJECT_DIR"
docker compose up -d --force-recreate
sleep 5

declare -A services=( ["vector_service"]=5001 ["llm_service"]=5002 ["gateway"]=5000 )
pids=()

for svc in "vector_service" "llm_service" "gateway"; do
    echo "Iniciando $svc..."
    cd "$PROJECT_DIR/$svc"

    nohup python3 app.py > "$LOG_DIR/$svc.log" 2>&1 &
    pid=$!
    pids+=($pid)
    sleep 4
done

echo ""
echo "Esperando estabilidad (Health Check)..."
READY=false
for i in {1..6}; do
    echo -n "  Intento $i... "
    HEALTH=$(curl -s -m 5 http://127.0.0.1:5000/health)
    if [[ "$HEALTH" == *'"status":"ok"'* ]]; then
        echo "¡ONLINE!"
        READY=true
        break
    fi
    echo "reintentando en 10s..."
    sleep 10
done

echo ""
echo "Ingestando desde: $DOCS_DIR"
if [ -d "$DOCS_DIR" ]; then
    for file in "$DOCS_DIR"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            status=$(curl -s -o /dev/null -w "%{http_code}" \
                -X POST http://127.0.0.1:5000/ingest \
                -F "file=@$file")
            echo "  [$status] $filename"
        fi
    done
fi

echo ""
echo "===================================================="
echo "SISTEMA LISTO. 'salir' para terminar."
echo "===================================================="

MODEL="fast"
while true; do
    read -p "Pregunta: " input
    [[ "$input" == "salir" ]] && break
    [[ "$input" == "fast" || "$input" == "quality" ]] && MODEL="$input" && echo "Modelo: $MODEL" && continue
    [[ -z "$input" ]] && continue

    echo -ne "\rPensando..."
    RESPONSE=$(curl -s -X POST http://127.0.0.1:5000/query \
        -H "Content-Type: application/json" \
        -d "{\"question\": \"$input\", \"model\": \"$MODEL\"}" \
        --max-time 120)

    if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
        echo -e "\r[!] Error: Sin respuesta del servidor."
    else
        echo -e "\r"
        echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('\033[92mRespuesta:\033[0m', data.get('answer'))
    print('\033[90mFuentes:\033[0m', ', '.join(data.get('fuentes', [])))
except:
    print('Error en JSON')
"
    fi
    echo ""
done

echo "Apagando servicios..."
for pid in "${pids[@]}"; do kill $pid 2>/dev/null; done
cd "$PROJECT_DIR" && docker compose down
