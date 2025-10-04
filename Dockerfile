# GPU-capable base (also works for CPU-only runs). If you only need CPU, you can switch to python:3.11-slim.
# Include cuDNN to avoid runtime errors loading libcudnn_* (required by faster-whisper on CUDA)
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# System deps: libpulse client, PortAudio runtime for sounddevice, libsndfile for soundfile, and basic tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    libpulse0 pulseaudio-utils \
    libportaudio2 \
    libasound2 libasound2-plugins alsa-utils \
    libsndfile1 \
    ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# App dirs
WORKDIR /app

# Python deps
COPY requirements.txt /app/
RUN python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir -r requirements.txt

# Copy app
COPY app /app/app
COPY scripts /app/scripts
RUN chmod +x /app/scripts/asr_bus_entrypoint.sh

# Default env (can be overridden)
ENV MODEL_SIZE=small \
    DEVICE=cpu \
    COMPUTE_TYPE=int8 \
    LANG=es \
    APP_BASE_DIR=/app \
    DATA_DIR=/app/data \
    MODEL_DIR=/app/models \
    SAMPLE_RATE=16000 \
    CHANNELS=1 \
    BLOCKSIZE=1024 \
    XDG_RUNTIME_DIR=/run/user/1000 \
    PULSE_SERVER=unix:/run/user/1000/pulse/native

EXPOSE 7860

# Run API
CMD ["python3", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]
