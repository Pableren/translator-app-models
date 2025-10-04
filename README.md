# Local ASR (Web UI + FastAPI + faster-whisper)

Aplicación 100% offline que captura el audio del sistema (PulseAudio/PipeWire) en Linux y transcribe en vivo con `faster-whisper`. UI web mínima en `http://localhost:7860`.

## Estructura

- `app/main.py`: FastAPI (UI, endpoints, WebSocket)
- `app/audio.py`: captura de audio del "Monitor of …" (Pulse)
- `app/transcriber.py`: servicio de transcripción con faster-whisper
- `app/templates/index.html` y `app/static/`: UI mínima
- `docker-compose.yml` + `Dockerfile`: ejecución con Docker Engine (GPU/CPU)
- `requirements.txt`

## Requisitos (host)

- Linux (Zorin/Ubuntu) con PulseAudio o PipeWire (compatibilidad Pulse)
- Docker Engine (NO Docker Desktop) y Docker Compose v2
- (GPU) NVIDIA Container Toolkit instalado en el host
- `pavucontrol` (recomendado) para enrutar al "Monitor of …"

## Quickstart (Makefile)

Flujos listos para onboarding:

- GPU (recomendado con RTX 3060):
  1) Instalar Toolkit NVIDIA (primera vez, opcional automático):
     ```bash
     CONFIRM=YES make host-setup-gpu
     ```
  2) Verificar GPU desde Docker:
     ```bash
     make gpu-verify
     ```
  3) Bootstrap completo (prepara volúmenes + build + predescarga del modelo):
     ```bash
     MODEL_SIZE=large-v3 make bootstrap-gpu
     ```
  4) Levantar servicio:
     ```bash
     make up
     ```

- CPU (sin GPU):
  1) Bootstrap completo en CPU:
     ```bash
     MODEL_SIZE=small make bootstrap-cpu
     ```
  2) Levantar servicio:
     ```bash
     make up
     ```

Comandos útiles:

- `make clean-models` → limpia modelos/cachés en `models/`.
- `make devices` → lista dispositivos de audio que ve el contenedor.
- `make status` → `GET /api/status`.
- `make logs` / `make down` → logs y detener.

## Variables clave

- `MODEL_SIZE`: `tiny|base|small|medium|large-v3` (por defecto: `large-v3` en compose)
- `DEVICE`: `cuda|cpu` (por defecto: `cuda` en compose)
- `COMPUTE_TYPE`: `float16|int8|int8_float16` (por defecto: `float16` en compose)
- `LANG`: `es|en|auto` (por defecto: `es`)
- `AUDIO_INPUT`: pista para elegir dispositivo por nombre (por defecto: `monitor`)
- `XDG_RUNTIME_DIR` / `PULSE_SERVER`: se configuran en compose para acceder a Pulse del host

## Preparación

1. Copia variables de ejemplo y ajusta `UID/GID` a tu usuario (alternativamente los targets usan tus IDs actuales):
   ```bash
   cp .env.example .env
   echo UID=$(id -u) >> .env
   echo GID=$(id -g) >> .env
   ```
2. (GPU) Verifica que `nvidia-smi` funcione en el host y que el Toolkit esté instalado (o usa `make host-setup-gpu` + `make gpu-verify`).
3. Opcional: crea carpetas persistentes
   ```bash
   mkdir -p data models
   ```

## Ejecutar (GPU NVIDIA)

```bash
docker compose up --build
```

- Abre `http://localhost:7860`
- En `pavucontrol` → pestaña Recording, asigna al proceso del contenedor el "Monitor of <tu salida>".
- Botón "Iniciar": comienza captura y transcripción.
- Botón "Detener": cierra sesión y guarda archivos en `data/`.

## Ejecutar en CPU

Edita `.env` o lanza sobreescribiendo:
```bash
DEVICE=cpu COMPUTE_TYPE=int8 MODEL_SIZE=small docker compose up --build
```

## Endpoints útiles

- `GET /api/status`
- `POST /api/control/start`
- `POST /api/control/stop`
- `GET /api/files` (lista audio/transcripts)
- `POST /api/files/transcripts/{filename}/rename` (JSON: `{ "new_name": "nuevo.txt" }`)
- `GET /api/audio/devices` (debug: lista dispositivos que ve PortAudio)
- WebSocket: `/ws/stream` (manda deltas de texto en vivo)

## Notas sobre audio en contenedor

- Se monta el socket Pulse y la cookie del usuario.
- El contenedor se ejecuta con tu `UID:GID` para evitar permisos.
- Si no ves el "monitor":
  - Asegura `XDG_RUNTIME_DIR=/run/user/<UID>` y mapea `.../pulse/native`.
  - Revisa `pactl info` dentro del contenedor (`Server String` debe apuntar al socket).

## Gestión de modelos y cachés

- Carpeta de modelos/cachés (host): `models/` (mapeada a `/app/models`).
- Limpiar espacio (seguro):
  ```bash
  make clean-models
  ```
- Predescarga del modelo sin bootstrap:
  ```bash
  MODEL_SIZE=large-v3 make install-model-gpu   # usa GPU
  MODEL_SIZE=small    make install-model-cpu   # usa CPU
  ```

## Nativo (sin Docker)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native
python -m uvicorn app.main:app --host 0.0.0.0 --port 7860
```

## GPU Settings (faster-whisper)

- RTX 3060 (12GB) → `DEVICE=cuda`, `COMPUTE_TYPE=float16`, `MODEL_SIZE=large-v3` recomendado.
- CPU fallback → `DEVICE=cpu`, `COMPUTE_TYPE=int8`, `MODEL_SIZE=small`.

## Solución de problemas (GPU)

- "NVIDIA Driver was not detected" o error CUDA en instalación del modelo:
  - Ejecuta `make gpu-verify`. Si falla, corre `CONFIRM=YES make host-setup-gpu` y reintenta.
  - Asegúrate de usar Docker Engine (no Desktop) y que `nvidia-smi` funciona en el host.
  - Reinicia Docker tras cambios: `sudo systemctl restart docker`.

## Licencias

- Modelos Whisper (open-source). Revisa licencias de dependencias incluidas.
