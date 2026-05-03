from sentence_transformers import SentenceTransformer

model = SentenceTransformer("all-MiniLM-L6-v2") # 90mb
# De no ver que se tiene un buen rendimiento puede cambiarse el modelo

def get_embeddings(texts: list[str]) -> list[list[float]]:
    
    #Convierte una lista de textos en una lista de vectores numéricos.
    
    embeddings = model.encode(texts, convert_to_tensor=False)
    return embeddings.tolist()