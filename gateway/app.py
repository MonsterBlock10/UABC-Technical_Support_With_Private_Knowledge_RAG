from flask import Flask, request, jsonify
import requests
import os
import tempfile

app = Flask(__name__)

# Configuración de URLs - Usamos 127.0.0.1 para evitar problemas de resolución en Windows
VECTOR_SERVICE = os.getenv("VECTOR_SERVICE_URL", "http://127.0.0.1:5001")
LLM_SERVICE    = os.getenv("LLM_SERVICE_URL",    "http://127.0.0.1:5002")

def build_prompt(question: str, chunks: list[dict]) -> str:
    
    #Construye el prompt RAG con el contexto recuperado.
    context = "\n\n".join(
        f"[Fuente: {c['source']}]\n{c['text']}"
        for c in chunks
    )
    return (
            f"Eres un asistente de soporte técnico amable y servicial. "
            f"Si el usuario te saluda o hace charla trivial, responde de forma amigable para generar una buena experiencia. "
            f"Para preguntas específicas sobre el servicio o soporte, utiliza ÚNICAMENTE el contexto proporcionado a continuación. "
            f"Si la información no está en el contexto, di amablemente que no tienes esa información específica pero intenta ayudar en lo que puedas.\n\n"
            f"CONTEXTO:\n{context}\n\n"
            f"PREGUNTA: {question}\n\n"
            f"RESPUESTA:"
        )

@app.route("/query", methods=["POST"])
def query():

    data = request.get_json()
    question = data.get("question")
    model    = data.get("model", "fast")
    top_k    = data.get("top_k", 5)

    if not question:
        return jsonify({"error": "Pregunta vacía"}), 400

    try:
        # Buscar chunks relevantes en el servicio de vectores
        search_resp = requests.post(
            f"{VECTOR_SERVICE}/search",
            json={"query": question, "top_k": top_k},
            timeout=15
        )
        search_resp.raise_for_status()
        chunks = search_resp.json().get("results", [])

        if not chunks:
            prompt = (f"El usuario pregunta: '{question}'. "
                     f"Responde amablemente que actualmente no hay documentos técnicos en la base de datos, "
                     f"pero intenta responder de forma general como asistente de soporte.")
            fuente_usada = "Conocimiento General (Sin documentos)"
        else:
            prompt = build_prompt(question, chunks)
            mejor_chunk = max(chunks, key=lambda c: c["score"])
            fuente_usada = mejor_chunk["source"]

        # Damos 120 segundos porque Ollama puede ser lento
        llm_resp = requests.post(
            f"{LLM_SERVICE}/generate",
            json={"prompt": prompt, "model": model},
            timeout=120 
        )
        llm_resp.raise_for_status()
        answer = llm_resp.json()["response"]

        return jsonify({
            "question": question,
            "answer": answer,
            "model": model,
            "fuentes": [fuente_usada]
        })

    except Exception as e:
        return jsonify({"error": f"Error en la orquestación: {str(e)}"}), 500

@app.route("/ingest", methods=["POST"])
def ingest():
    
    #Recibe archivo y lo manda a indexar al Vector Service.
    
    if "file" not in request.files:
        return jsonify({"error": "No se recibió archivo"}), 400

    file = request.files["file"]
    
    # tempfile detecta automaticamente OS
    temp_dir = tempfile.gettempdir()
    temp_path = os.path.join(temp_dir, file.filename)
    
    try:
        file.save(temp_path)
        index_resp = requests.post(
            f"{VECTOR_SERVICE}/index",
            json={"filepath": temp_path},
            timeout=60
        )
        index_resp.raise_for_status()
        return jsonify(index_resp.json())
    except Exception as e:
        return jsonify({"error": f"Fallo en ingesta: {str(e)}"}), 500
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.route("/health", methods=["GET"])
def health():

    # Chequea que el script de PowerShell sepa cuándo arrancar.

    status = {"gateway": "ok", "vector_service": "unknown", "llm_service": "unknown"}

    try:
        r_vec = requests.get(f"{VECTOR_SERVICE}/collections", timeout=3)
        status["vector_service"] = "ok" if r_vec.ok else "error"
    except:
        status["vector_service"] = "unreachable"

    try:
        # Hacemos un pequeño ping al LLM para ver si Ollama responde
        r_llm = requests.post(f"{LLM_SERVICE}/generate", 
                             json={"prompt": "ping", "model": "fast"}, timeout=10)
        status["llm_service"] = "ok" if r_llm.ok else "error"
    except:
        status["llm_service"] = "unreachable"

    is_ok = all(v == "ok" for v in status.values())
    return jsonify({"status": "ok" if is_ok else "degraded", "services": status}), 200 if is_ok else 503

if __name__ == "__main__":
    # debug=False evita que se creen procesos duplicados en Windows
    app.run(host="0.0.0.0", port=5000, debug=False)