# Serverless-воркер HQ-SVC — Plan Б: готовое conda-окружение авторов (эталонное качество).
# Их torch собран под CUDA 11 (nvidia-*-cu11) → базовый образ CUDA 11.8 runtime.
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
        git git-lfs ffmpeg sox libsox-dev libsox-fmt-all ca-certificates tzdata \
    && git lfs install \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# ВАЖНО: clone + распаковка conda-env + удаление архива + удаление .git — в ОДНОМ RUN.
# Иначе environment.tar.gz (4.77 ГБ) и .git/lfs (ещё ~4.77 ГБ) останутся в слоях и раздуют образ.
RUN git clone https://huggingface.co/shawnpi/HQ-SVC /app/HQ-SVC \
    && mkdir -p /opt/hqenv \
    && tar -xzf /app/HQ-SVC/environment.tar.gz -C /opt/hqenv \
    && /opt/hqenv/bin/python /opt/hqenv/bin/conda-unpack \
    && rm -f /app/HQ-SVC/environment.tar.gz \
    && rm -rf /app/HQ-SVC/.git

# RunPod SDK — внутрь их окружения
RUN /opt/hqenv/bin/pip install --no-cache-dir runpod \
    && /opt/hqenv/bin/python -c "import runpod; print('RUNPOD OK', runpod.__version__)"

COPY handler.py /app/HQ-SVC/handler.py

ENTRYPOINT []
CMD ["sh", "-c", "/opt/hqenv/bin/python -u /app/HQ-SVC/handler.py 2>&1"]
