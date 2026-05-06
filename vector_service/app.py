from flask import Flask, request, jsonify
from qdrant_client import QdrantClient
from qdrant_client.models import VectorParams, Distance, PointStruct
from ingestor import parse_document, chunk_text
from embedder import get_embeddings
import uuid
import os

app = Flask(__name__)

# --- Configuración de Qdrant ---
QDRANT_HOST = os.getenv("QDRANT_HOST", "127.0.0.1")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", 6333))
COLLECTION_NAME = "docs"
VECTOR_SIZE = 384  # dimensiones de all-MiniLM-L6-v2

# Inicialización del cliente con un timeout de seguridad
client = QdrantClient(host=QDRANT_HOST, port=QDRANT_PORT, timeout=10)


def ensure_collection():

    #Crea la colección en Qdrant si no existe.
    
    collections = [c.name for c in client.get_collections().collections]
    if COLLECTION_NAME not in collections:
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE)
        )


# ──────────────────────────────────────────
# POST /index
# Recibe filepath, parsea, chunkea, embeddea y guarda en Qdrant
# ──────────────────────────────────────────
@app.route("/index", methods=["POST"])
def index():
    data = request.get_json()
    filepath = data.get("filepath")

    if not filepath or not os.path.exists(filepath):
        return jsonify({"error": "Archivo no encontrado"}), 400

    ensure_collection()

    text = parse_document(filepath)
    chunks = chunk_text(text)
    embeddings = get_embeddings(chunks)

    points = [
        PointStruct(
            id=str(uuid.uuid4()),
            vector=embedding,
            payload={
                "text": chunk,
                "source": os.path.basename(filepath)
            }
        )
        for chunk, embedding in zip(chunks, embeddings)
    ]

    client.upsert(collection_name=COLLECTION_NAME, points=points)

    return jsonify({
        "status": "ok",
        "source": os.path.basename(filepath),
        "chunks_indexados": len(points)
    })


# ──────────────────────────────────────────
# POST /search
# Recibe una query, la embeddea y busca los chunks más similares
# ──────────────────────────────────────────
@app.route("/search", methods=["POST"])
def search():
    data = request.get_json()
    query = data.get("query")
    top_k = data.get("top_k", 5)

    if not query:
        return jsonify({"error": "Query vacía"}), 400

    ensure_collection()

    query_vector = get_embeddings([query])[0]

    results = client.search(
        collection_name=COLLECTION_NAME,
        query_vector=query_vector,
        limit=top_k
    )

    return jsonify({
        "results": [
            {
                "text": r.payload["text"],
                "source": r.payload["source"],
                "score": r.score
            }
            for r in results
        ]
    })


# ──────────────────────────────────────────
# GET /collections
# Info general de la colección en Qdrant
# ──────────────────────────────────────────
@app.route("/collections", methods=["GET"])
def collections():
    ensure_collection()
    info = client.get_collection(COLLECTION_NAME)
    return jsonify({
        "collection": COLLECTION_NAME,
        "vectores_totales": info.vectors_count,
        "dimension": VECTOR_SIZE
    })

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ready"}), 200

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, debug=False)