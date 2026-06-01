"""
RunPod Serverless handler для HQ-SVC — zero-shot конвертация голоса/пения (AAAI 2026).
Для A/B-сравнения с YingMusic. Та же схема I/O.

Инференс зашит в gradio_app.py:
  initialize_models(config_path)  — загрузка модели (глобалы)
  predict(source_audio, target_files, shift_key, adjust_f0) -> (status_str, out_wav_path)

Вход (event["input"]):
  source_audio     — base64 исходного вокала
  reference_audio  — base64 образца голоса юзера
  shift_key        — сдвиг тона (по умолч. 0)
  adjust_f0        — автоподстройка высоты (по умолч. True)

Выход: converted_audio (wav) + status, либо error + traceback.
"""
import os
import sys
import base64
import tempfile
import traceback

import runpod

REPO = "/app/HQ-SVC"
CONFIG = os.environ.get("HQSVC_CONFIG", "configs/hq_svc_infer.yaml")

# gradio_app использует относительные пути (configs/..., utils/...) → работаем из его папки
os.chdir(REPO)
sys.path.insert(0, REPO)

_state = {"ready": False, "error": None, "mod": None}


class _F:
    """Шим под gradio File-объект (на случай если predict ждёт .name)."""
    def __init__(self, path):
        self.name = path


def _load():
    if _state["ready"] or _state["error"]:
        return
    try:
        import gradio_app as ga
        print("[HQ-SVC] initialize_models…", flush=True)
        ga.initialize_models(CONFIG)
        _state["mod"] = ga
        _state["ready"] = True
        print("[HQ-SVC] модели готовы.", flush=True)
    except Exception:
        _state["error"] = traceback.format_exc()
        print("[HQ-SVC] ОШИБКА загрузки:\n" + _state["error"], flush=True)


def _w(path, b64):
    with open(path, "wb") as f:
        f.write(base64.b64decode(b64))


def _call_predict(ga, src, ref, shift, adjust):
    """predict может ждать пути-строки ИЛИ gradio-объекты с .name — пробуем оба."""
    try:
        return ga.predict(src, [ref], shift, adjust)
    except AttributeError:
        return ga.predict(_F(src), [_F(ref)], shift, adjust)


def handler(event):
    try:
        _load()
        if _state["error"]:
            return {"error": "model load failed", "traceback": _state["error"]}

        inp = event.get("input", {}) or {}
        src_b64 = inp.get("source_audio")
        ref_b64 = inp.get("reference_audio")
        if not src_b64 or not ref_b64:
            return {"error": "need source_audio and reference_audio (base64)"}
        shift = inp.get("shift_key", 0)
        adjust = bool(inp.get("adjust_f0", True))

        wd = tempfile.mkdtemp()
        sp = os.path.join(wd, "source.wav")
        rp = os.path.join(wd, "target.wav")
        _w(sp, src_b64)
        _w(rp, ref_b64)

        print("[HQ-SVC] predict…", flush=True)
        result = _call_predict(_state["mod"], sp, rp, shift, adjust)
        # ожидаем (status, out_path)
        status, out_p = (result if isinstance(result, (list, tuple)) and len(result) >= 2
                         else ("", result))

        if not out_p or not os.path.exists(out_p):
            return {"error": "no output file", "status": str(status)}

        with open(out_p, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("utf-8")
        return {
            "converted_audio": b64,
            "audio_base64": b64,
            "format": "wav",
            "model": "hq-svc",
            "status": str(status),
        }
    except Exception:
        return {"error": "handler crashed", "traceback": traceback.format_exc()}


runpod.serverless.start({"handler": handler})
