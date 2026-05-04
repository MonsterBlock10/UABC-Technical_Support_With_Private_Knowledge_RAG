# RAG — Asistente de Soporte Técnico con Conocimiento Privado

Sistema de Recuperación Aumentada por Generación (RAG) distribuido para consulta de documentación técnica interna. Desarrollado como proyecto para la materia de Sistemas Distribuidos, UABC Facultad de Ciencias.

---

## Requisitos previos

- Python 3.12.x
- Docker
- Ollama
- Git

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/MonsterBlock10/UABC-Technical_Support_With_Private_Knowledge_RAG.git
cd UABC-Technical_Support_With_Private_Knowledge_RAG
```

### 2. Crear el entorno virtual

Las rutas del proyecto están basadas en la máquina de desarrollo. Al clonar en una máquina nueva es necesario crear un entorno virtual propio, no reutilizar el de otra máquina.

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

### 3. Instalar dependencias

**Linux / macOS:**
```bash
pip install -r utilidades/requirements.txt --break-system-packages
```

**Windows:**
```powershell
pip install -r utilidades\requirements.txt
```

### 4. Dar permisos a los scripts (solo Linux / macOS)

En Windows no aplica, los scripts `.ps1` no requieren este paso.

```bash
chmod +x utilidades/start_linux.sh
chmod +x utilidades/stop_linux.sh

# macOS
chmod +x utilidades/start_macos.sh
chmod +x utilidades/stop_macos.sh
```

### 5. Descargar modelo de Ollama

El script de inicio descarga `gemma2:2b` automáticamente si no está presente. Si prefieres descargarlo manualmente:

```bash
ollama pull gemma2:2b
```

Para usar el modelo de mayor calidad (requiere más recursos):
```bash
ollama pull qwen2.5:14b
```

---

## Uso

### Iniciar el sistema

El script levanta automáticamente Ollama, Qdrant y los 3 servicios Flask.

**Linux:**
```bash
./utilidades/start_linux.sh
```

**macOS:**
```bash
./utilidades/start_macos.sh
```

**Windows:**
```powershell
.\utilidades\start_windows.ps1
```

Al finalizar deberías ver:

```json
{
    "services": {
        "gateway": "ok",
        "llm_service": "ok",
        "vector_service": "ok"
    },
    "status": "ok"
}
```

### Detener el sistema

**Linux:**
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

rag_project/
├── gateway/
│   ├── app.py
│   └── requirements.txt
├── vector_service/
│   ├── app.py
│   ├── ingestor.py
│   ├── embedder.py
│   └── requirements.txt
├── llm_service/
│   ├── app.py
│   ├── ollama_client.py
│   └── requirements.txt
├── docs/
│   ├── manual_ejemplo.txt
│   ├── guia_instalacion.md
│   └── reporte_tecnico.pdf
├── utilidades/
│   ├── requirements.txt
    ├── linux
│       ├── start_linux_pop.sh
│       ├── stop_linux_pop.sh
│   
├── requirements.txt
    ├── start_macos.sh
│   ├── stop_macos.sh
│   ├── start_windows.ps1
│   └── stop_windows.ps1
├── docker-compose.yml
└── README.md


## Permisos de ejecución de scripts

Antes de ejecutar los scripts por primera vez es necesario otorgarles permisos de ejecución. Esto solo se hace una vez por máquina.

**Linux (pop os):**
```bash
chmod +x utilidades/start_linux.sh
chmod +x utilidades/stop_linux.sh
```

**macOS:**
```bash
chmod +x utilidades/start_macos.sh
chmod +x utilidades/stop_macos.sh
```

**Windows:**
En Windows no se usa `chmod`. Los scripts `.ps1` de PowerShell requieren que la política de ejecución esté habilitada. Ejecuta PowerShell como administrador y corre esto una sola vez:
```powershell
Set-ExecutionPolicy RemoteSigned
```
Después de eso los scripts `.ps1` se pueden ejecutar sin problema.

---

## Consideraciones

- Las rutas en los scripts están basadas en la máquina de desarrollo. Al usar el proyecto en otra máquina es necesario ajustar `PROJECT_DIR` en el script correspondiente.
- El flujo correcto es: levantar Qdrant → levantar servicios → ingestar documentos → hacer consultas. De no seguirse este orden el sistema no funcionará correctamente.
- Los logs de cada servicio se guardan en `utilidades/logs/` para diagnóstico de errores.
- `qwen2.5:14b` requiere al menos 16GB de RAM para correr con fluidez.

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
Eso cubre todo lo que tenías en tu archivo original pero en formato README estándar. ¿Le cambias algo o está bien así?