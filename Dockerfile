# Serverless-воркер HQ-SVC — Plan Б: используем ГОТОВОЕ conda-окружение авторов
# (environment.tar.gz, conda-pack) вместо pip. Эталонное окружение → эталонное качество.
# Их torch собран под CUDA 11 (видно по nvidia-*-cu11) → базовый образ CUDA 11.8 runtime.
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Системные либы: аудио (sox/ffmpeg), git+git-lfs для клонирования HF-репо с большими файлами
RUN apt-get update && apt-get install -y --no-install-recommends \
        git git-lfs ffmpeg sox libsox-dev libsox-fmt-all ca-certificates tzdata \
    && git lfs install && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Клонируем HF-репо: код + config + чекпойнт (utils/pretrain/...) + environment.tar.gz (LFS)
RUN git clone https://huggingface.co/shawnpi/HQ-SVC /app/HQ-SVC

WORKDIR /app/HQ-SVC
# Распаковываем conda-pack окружение и чиним пути (conda-unpack), затем удаляем архив
RUN mkdir -p /opt/hqenv \
    && tar -xzf environment.tar.gz -C /opt/hqenv \
    && /opt/hqenv/bin/conda-unpack \
    && rm -f environment.tar.gz

# RunPod SDK ставим ВНУТРЬ их окружения
RUN /opt/hqenv/bin/pip install --no-cache-dir runpod

# Проверка: runpod виден их python'ом
RUN /opt/hqenv/bin/python -c "import runpod; print('RUNPOD OK', runpod.__version__)"

COPY handler.py /app/HQ-SVC/handler.py

ENTRYPOINT []
# Запускаем handler ИМЕННО python'ом из conda-env
CMD ["sh", "-c", "/opt/hqenv/bin/python -u /app/HQ-SVC/handler.py 2>&1"]
