import requests
import os

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "localhost")
OLLAMA_PORT = os.getenv("OLLAMA_PORT", "11434")
OLLAMA_URL = f"http://{OLLAMA_HOST}:{OLLAMA_PORT}/api/generate"

MODELS = {
    "fast": "gemma2:2b",
    "quality": "qwen2.5:14b"
}


def generate(prompt: str, model_tier: str = "fast") -> str:
    
    #Manda el prompt a Ollama y regresa la respuesta como string.
    
    model = MODELS.get(model_tier, MODELS["fast"])

    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False
    }

    response = requests.post(OLLAMA_URL, json=payload, timeout=240)
    response.raise_for_status()

    return response.json()["response"]