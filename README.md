# HQ-SVC — Serverless-воркер (A/B-конкурент YingMusic)

Zero-shot конвертация голоса/пения (AAAI 2026). Ставим для **A/B-сравнения** с YingMusic.
⚠️ Лицензии в репо НЕТ → только внутренний тест, НЕ в коммерческий продукт.

## Деплой (через GitHub, как остальные)
1. Новый репозиторий GitHub: `hqsvc-runpod-worker`.
2. Залей в корень: `handler.py`, `Dockerfile`, `README.md`.
3. RunPod → Serverless → New Endpoint → Deploy from GitHub → ветка `main`.
4. **GPU: 48 GB (A40/A6000) или 80 GB (A100/H100)** — ❌ НЕ Blackwell (24GB PRO6000 / 32GB 5090).
5. Min Workers 0, Execution timeout 1200, Disk 30 ГБ, FlashBoot ON.
6. Endpoint ID → запиши.

⚠️ Сборка долгая: качает HF-репо (~1 ГБ без conda-env) + pip-зависимости.
В Build logs жди `RUNPOD OK`.

## Тестовый запрос (та же схема, что YingMusic)
```json
{
  "input": {
    "source_audio": "<base64 вокала>",
    "reference_audio": "<base64 голоса юзера>",
    "shift_key": 0,
    "adjust_f0": true
  }
}
```
Ответ: `converted_audio` (wav) + `status`.

## Ожидаемые места отладки (research-код, gradio)
- predict может ждать gradio-объекты с `.name` — handler пробует оба варианта.
- requirements.txt вместо conda-env: возможны конфликты версий (тогда правим).
- путь config/чекпойнта — `configs/hq_svc_infer.yaml`, `utils/pretrain/250000_step_val_loss_0.50.pth`.
- При сбое handler вернёт `traceback` — присылай.
