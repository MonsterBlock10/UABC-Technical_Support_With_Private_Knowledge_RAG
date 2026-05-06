# RAG — Asistente de Soporte Técnico con Conocimiento Privado

Sistema de Recuperación Aumentada por Generación (RAG) distribuido para consulta de documentación técnica interna. Desarrollado como proyecto para la materia de Sistemas Distribuidos, UABC Facultad de Ciencias.

---

## Requisitos previos

- Python 3.12.x
- Docker Desktop
- Git

> Ollama se instala automáticamente en Linux. En macOS y Windows ver sección de instalación.

---

## Instalación de Ollama

**Linux** — se instala automáticamente al correr el script de inicio.

**macOS:**
```bash
brew install ollama
```
O descarga el instalador desde: https://ollama.com/download

**Windows:**
Descarga e instala el `.exe` desde: https://ollama.com/download

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/MonsterBlock10/UABC-Technical_Support_With_Private_Knowledge_RAG.git
cd UABC-Technical_Support_With_Private_Knowledge_RAG
```

### 2. Crear el entorno virtual

Al clonar en una máquina nueva es necesario crear un entorno virtual propio. Los scripts detectan automáticamente la ubicación del proyecto, pero el entorno virtual debe crearse manualmente la primera vez.

**Linux / macOS:**
```bash
python3 -m venv rag_venv
source rag_venv/bin/activate
```

**Windows:**
```powershell
python -m venv rag_venv
.\rag_venv\Scripts\Activate.ps1
```

> En ejecuciones posteriores los scripts activan el entorno automáticamente.

### 3. Dar permisos a los scripts (solo Linux / macOS)

**Linux (Pop!_OS):**
```bash
chmod +x utilidades/linux/start_linux_pop.sh
chmod +x utilidades/linux/stop_linux_pop.sh
```

**macOS:**
```bash
chmod +x utilidades/mac/start_macos.sh
chmod +x utilidades/mac/stop_macos.sh
```

**Windows:**
En Windows no se usa `chmod`. Ejecuta PowerShell como administrador y habilita los scripts una sola vez:
```powershell
Set-ExecutionPolicy RemoteSigned
```

### 4. Descargar modelos de Ollama

El script descarga `gemma2:2b` automáticamente si no está presente. Para descargarlo manualmente:

```bash
ollama pull gemma2:2b
```

Para el modelo de mayor calidad (requiere más recursos):
```bash
ollama pull qwen2.5:14b
```

---

## Uso

### Iniciar el sistema

El script levanta automáticamente Ollama, Qdrant, los 3 servicios Flask, ingesta los documentos de `docs/` y abre un loop interactivo de preguntas.

**Linux (Pop!_OS):**
```bash
./utilidades/linux/start_linux_pop.sh
```

**macOS:**
```bash
./utilidades/mac/start_macos.sh
```

**Windows:**
```powershell
.\utilidades\windows\start_windows.ps1
```

Al finalizar el arranque deberías ver:
====================================================
SISTEMA LISTO. Escribe 'salir' para terminar
====================================================
Pregunta:

Durante el uso puedes:
- Escribir cualquier pregunta para consultarla contra los documentos indexados
- Escribir `fast` para cambiar al modelo gemma2:2b
- Escribir `quality` para cambiar al modelo qwen2.5:14b
- Escribir `salir` para cerrar el sistema

### Detener el sistema

El sistema se apaga automáticamente al escribir `salir` en el loop de preguntas. Para forzar el cierre manualmente:

**Linux (Pop!_OS):**
```bash
./utilidades/linux/stop_linux_pop.sh
```

**macOS:**
```bash
./utilidades/mac/stop_macos.sh
```

**Windows:**
```powershell
.\utilidades\windows\stop_windows.ps1
```

---

## Uso de la API

El sistema también puede usarse directamente mediante su API REST sin necesidad del script interactivo.

### Ingestar un documento

```bash
curl -X POST http://localhost:5000/ingest \
  -F "file=@docs/manual_ejemplo.txt"
```

### Hacer una consulta

```bash
# Modelo rapido (gemma2:2b)
curl -X POST http://localhost:5000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "tu pregunta aqui", "model": "fast"}'

# Modelo de mayor calidad (qwen2.5:14b)
curl -X POST http://localhost:5000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "tu pregunta aqui", "model": "quality"}'
```

### Ver documentos indexados

```bash
curl http://localhost:5000/documents
```

### Verificar estado del sistema

```bash
curl http://localhost:5000/health
```

---

## Qdrant

Qdrant corre en Docker y es levantado automáticamente por el script de inicio. Para manejarlo manualmente:

```bash
# Levantar
docker compose up -d

# Verificar estado
docker compose ps

# Ver logs
docker compose logs qdrant

# Apagar
docker compose down
```

Dashboard web disponible en: `http://localhost:6333/dashboard`

---

## Estructura del proyecto
UABC-Technical_Support_With_Private_Knowledge_RAG/
├── gateway/
│   └── app.py
├── vector_service/
│   ├── app.py
│   ├── ingestor.py
│   └── embedder.py
├── llm_service/
│   ├── app.py
│   └── ollama_client.py
├── docs/
│   ├── oreos.txt
│   └── neuronas.txt
├── utilidades/
│   ├── linux/
│   │   ├── start_linux_pop.sh
│   │   └── stop_linux_pop.sh
│   ├── mac/
│   │   ├── start_macos.sh
│   │   └── stop_macos.sh
│   ├── windows/
│   │   ├── start_windows.ps1
│   │   └── stop_windows.ps1
│   ├── logs/
│   └── requirements.txt
├── docker-compose.yml
├── .gitignore
└── README.md

---

## Consideraciones

- El flujo correcto es: levantar Qdrant → levantar servicios → ingestar documentos → hacer consultas. Los scripts manejan este orden automáticamente.
- Los logs de cada servicio se guardan en `utilidades/logs/` para diagnóstico de errores.
- `qwen2.5:14b` requiere al menos 16GB de RAM para correr con fluidez. En equipos con menos recursos se recomienda usar `gemma2:2b`.
- Los scripts detectan automáticamente la ruta del proyecto, por lo que funcionan en cualquier ubicación sin necesidad de modificarlos.

---

## Tecnologías utilizadas

| Componente | Tecnología |
|---|---|
| Backend | Flask (Python 3.12) |
| Base de datos vectorial | Qdrant (Docker) |
| Embeddings | sentence-transformers — all-MiniLM-L6-v2 |
| LLM local | Ollama — gemma2:2b / qwen2.5:14b |
| Parseo de documentos | PyMuPDF |
| Comunicación | HTTP/1.1 |