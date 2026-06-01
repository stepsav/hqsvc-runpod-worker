# Serverless-воркер HQ-SVC — zero-shot пение голосом юзера (AAAI 2026), для A/B с YingMusic.
# Research-код: инференс зашит в gradio_app (predict + initialize_models). Возможны итерации.
FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ffmpeg sox libsox-dev libsox-fmt-all tzdata build-essential python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir huggingface_hub runpod

WORKDIR /app
# HF-репо HQ-SVC содержит код + config + чекпойнт. Качаем всё, КРОМЕ conda-env (4.77 ГБ).
RUN python -c "from huggingface_hub import snapshot_download as d; d('shawnpi/HQ-SVC', local_dir='/app/HQ-SVC', ignore_patterns=['environment.tar.gz'])"

WORKDIR /app/HQ-SVC
# requirements.txt — слепок conda-env с git/local-версиями (напр. lhotse==1.24.0+git...,
# diffusers==0.28.0.dev0), которых нет на PyPI. Срезаем +локальные и .dev суффиксы → стабильные версии.
RUN sed -i -E 's/\+[A-Za-z0-9._]+//g; s/\.dev[0-9]*//g' requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

RUN python -c "import runpod; print('RUNPOD OK', runpod.__version__)"

COPY handler.py /app/HQ-SVC/handler.py
ENTRYPOINT []
CMD ["sh", "-c", "python -u /app/HQ-SVC/handler.py 2>&1"]
