#!/bin/bash

# Relative Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"

VENV="$PROJECT_DIR/rag_venv/bin/activate"
LOG_DIR="$PROJECT_DIR/utilidades/logs"
DOCS_DIR="$PROJECT_DIR/docs"
REQ_FILE="$PROJECT_DIR/utilidades/requirements.txt"

mkdir -p "$LOG_DIR"

echo "--- Starting RAG System (macOS) ---"

if [ -f "$VENV" ]; then
    source "$VENV"
else
    echo "Error: venv not found at $VENV"
    exit 1
fi

echo "Checking dependencies..."
pip install -r "$REQ_FILE" --quiet

echo "Ensuring Ollama..."
# On Mac, Ollama is usually a standalone App or brew service
if command -v brew &>/dev/null && brew services list | grep -q "ollama"; then
    brew services start ollama
else
    # Fallback: try to open the App if brew service isn't used
    open -a Ollama 2>/dev/null
fi

if ! ollama list | grep -q "gemma2:2b"; then
    ollama pull gemma2:2b
fi

echo "Starting Qdrant..."
cd "$PROJECT_DIR"
docker compose up -d --force-recreate
sleep 5

pids=()
for svc in "vector_service" "llm_service" "gateway"; do
    echo "Starting $svc..."
    cd "$PROJECT_DIR/$svc"
    nohup python3 app.py > "$LOG_DIR/$svc.log" 2>&1 &
    pids+=($!)
    sleep 4
done

echo "Health Check..."
READY=false
for i in {1..6}; do
    echo -n "Attempt $i... "
    HEALTH=$(curl -s -m 5 http://127.0.0.1:5000/health)
    if [[ "$HEALTH" == *'"status":"ok"'* ]]; then
        echo "ONLINE"
        READY=true
        break
    fi
    echo "waiting..."
    sleep 10
done

echo "Ingesting docs..."
if [ -d "$DOCS_DIR" ]; then
    for file in "$DOCS_DIR"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            status=$(curl -s -o /dev/null -w "%{http_code}" \
                -X POST http://127.0.0.1:5000/ingest \
                -F "file=@$file")
            echo " [$status] $filename"
        fi
    done
fi

echo "========================================"
echo "READY. Type 'salir' to quit."
echo "========================================"

MODEL="fast"
while true; do
    read -p "Query: " input
    [[ "$input" == "salir" ]] && break
    [[ "$input" == "fast" || "$input" == "quality" ]] && MODEL="$input" && echo "Model: $MODEL" && continue
    [[ -z "$input" ]] && continue

    echo -n "Thinking..."
    RESPONSE=$(curl -s -X POST http://127.0.0.1:5000/query \
        -H "Content-Type: application/json" \
        -d "{\"question\": \"$input\", \"model\": \"$MODEL\"}" \
        --max-time 120)

    if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
        echo -e "\rError: No response."
    else
        echo -e "\r"
        echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('Answer:', data.get('answer'))
    print('Sources:', ', '.join(data.get('fuentes', [])))
except:
    print('JSON Error')
"
    fi
    echo ""
done

echo "Stopping services..."
for pid in "${pids[@]}"; do kill $pid 2>/dev/null; done
cd "$PROJECT_DIR" && docker compose down
echo "Done!"