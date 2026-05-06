from flask import Flask, request, jsonify
from ollama_client import generate
import os

app = Flask(__name__)


# ──────────────────────────────────────────
# POST /generate
# Recibe prompt y model tier, regresa respuesta del LLM
# ──────────────────────────────────────────
@app.route("/generate", methods=["POST"])
def generate_response():
    data = request.get_json()
    prompt = data.get("prompt")
    model_tier = data.get("model", "fast")

    if not prompt:
        return jsonify({"error": "Prompt vacío"}), 400

    try:
        response = generate(prompt, model_tier)
        return jsonify({
            "response": response,
            "model": model_tier
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ready"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002, debug=False)