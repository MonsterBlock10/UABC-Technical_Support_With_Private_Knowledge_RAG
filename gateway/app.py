from flask import Flask, request, jsonify
import requests
import os

app = Flask(__name__)

VECTOR_SERVICE = os.getenv("VECTOR_SERVICE_URL", "http://localhost:5001")
LLM_SERVICE    = os.getenv("LLM_SERVICE_URL",    "http://localhost:5002")


def build_prompt(question: str, chunks: list[dict]) -> str:

    #Construye el prompt RAG con el contexto recuperado.
    
    context = "\n\n".join(
        f"[Fuente: {c['source']}]\n{c['text']}"
        for c in chunks
    )
    return (
        f"Eres un asistente de soporte técnico. "
        f"Responde ÚNICAMENTE basándote en el siguiente contexto. "
        f"Si la respuesta no está en el contexto, di que no tienes información al respecto.\n\n"
        f"CONTEXTO:\n{context}\n\n"
        f"PREGUNTA: {question}\n\n"
        f"RESPUESTA:"
    )


# ──────────────────────────────────────────
# POST /query
# Orquesta búsqueda semántica + generación RAG
# ──────────────────────────────────────────
@app.route("/query", methods=["POST"])
def query():
    data = request.get_json()
    question = data.get("question")
    model    = data.get("model", "fast")
    top_k    = data.get("top_k", 5)

    if not question:
        return jsonify({"error": "Pregunta vacía"}), 400

    # 1. Buscar chunks relevantes
    search_resp = requests.post(
        f"{VECTOR_SERVICE}/search",
        json={"query": question, "top_k": top_k}
    )
    search_resp.raise_for_status()
    chunks = search_resp.json()["results"]

    if not chunks:
        return jsonify({"error": "No se encontró contexto relevante"}), 404

    # 2. Construir prompt con contexto
    prompt = build_prompt(question, chunks)

    # 3. Generar respuesta con el LLM
    llm_resp = requests.post(
        f"{LLM_SERVICE}/generate",
        json={"prompt": prompt, "model": model}
    )
    llm_resp.raise_for_status()
    answer = llm_resp.json()["response"]


    mejor_chunk = max(chunks, key=lambda c: c["score"])

    return jsonify({
        "question": question,
        "answer": answer,
        "model": model,
        "fuentes": [mejor_chunk["source"]]
    })


# ──────────────────────────────────────────
# POST /ingest
# Recibe archivo y lo manda a indexar al Vector Service
# ──────────────────────────────────────────
@app.route("/ingest", methods=["POST"])
def ingest():
    if "file" not in request.files:
        return jsonify({"error": "No se recibió archivo"}), 400

    file = request.files["file"]
    ext  = os.path.splitext(file.filename)[1].lower()

    if ext not in (".txt", ".md", ".pdf"):
        return jsonify({"error": "Formato no soportado"}), 400

    # Guardar temporalmente para mandarlo al vector service
    temp_path = f"/tmp/{file.filename}"
    file.save(temp_path)

    index_resp = requests.post(
        f"{VECTOR_SERVICE}/index",
        json={"filepath": temp_path}
    )
    index_resp.raise_for_status()

    return jsonify(index_resp.json())


# ──────────────────────────────────────────
# GET /documents
# Lista los documentos indexados en Qdrant
# ──────────────────────────────────────────
@app.route("/documents", methods=["GET"])
def documents():
    resp = requests.get(f"{VECTOR_SERVICE}/collections")
    resp.raise_for_status()
    return jsonify(resp.json())


# ──────────────────────────────────────────
# GET /health
# Verifica que los 3 servicios estén vivos
# ──────────────────────────────────────────
# app.py - Versión mejorada de la función health

@app.route("/health", methods=["GET"])
def health():

    status = {
        "gateway": "ok", 
        "vector_service": "unknown", 
        "llm_service": "unknown",
        "ollama_status": "unknown"
    }

    # 1. Verificar Vector Service
    try:
        # Intentamos una operación ligera en el servicio de vectores
        r = requests.get(f"{VECTOR_SERVICE}/collections", timeout=2)
        status["vector_service"] = "ok" if r.ok else f"error_{r.status_code}"
    except requests.exceptions.ConnectionError:
        status["vector_service"] = "unreachable"
    except requests.exceptions.Timeout:
        status["vector_service"] = "timeout"
    except Exception as e:
        status["vector_service"] = f"exception_{str(e)}"

    # 2. Verificar LLM Service (Flask Wrapper)
    try:

        # Hacemos una petición de generación mínima
        # Usamos un timeout más largo porque el LLM puede estar despertando

        r = requests.post(
            f"{LLM_SERVICE}/generate",
            json={"prompt": "ping", "model": "fast"}, 
            timeout=10 
        )
        if r.ok:
            status["llm_service"] = "ok"
            # Si el servicio LLM responde, asumimos que Ollama está bien
            status["ollama_status"] = "connected"
        else:
            status["llm_service"] = f"error_{r.status_code}"
    except requests.exceptions.ConnectionError:
        status["llm_service"] = "unreachable"
    except requests.exceptions.Timeout:
        status["llm_service"] = "busy_or_loading_model"
    except Exception as e:
        status["llm_service"] = f"exception_{str(e)}"

    # Determinamos el estado global
    is_ok = status["gateway"] == "ok" and \
            status["vector_service"] == "ok" and \
            status["llm_service"] == "ok"
            
    overall = "ok" if is_ok else "degraded"
    
    return jsonify({
        "status": overall, 
        "services": status,
        "timestamp": os.getenv("CURRENT_TIME", "2026-05-03") 
    }), 200 if is_ok else 503

if __name__ == "__main__":
    app.run(port=5000, debug=True)