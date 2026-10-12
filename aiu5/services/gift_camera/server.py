"""Serve local, in-memory camera previews and v1 YOLO candidates for one Godot gift session."""
import argparse
import base64
import ctypes
import json
import logging
import os
from pathlib import Path
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from tracking import CLASS_NAMES, StableTracker

class CameraSession:
    def __init__(self, args):
        self.args = args
        self.lock = threading.Lock()
        self.stop = threading.Event()
        self.last_request = time.monotonic()
        self.snapshot = {"session_id":args.session, "status":"starting", "message":"正在加载首版模型与摄像头…", "candidates":[], "sequence":0}

    def publish(self, **values):
        with self.lock:
            self.snapshot.update(values)

    def run(self):
        capture = None
        try:
            import cv2
            import torch
            from ultralytics import YOLO
            torch.set_num_threads(2)
            model = YOLO(self.args.model)
            if [model.names[i] for i in range(len(model.names))] != CLASS_NAMES:
                raise RuntimeError("模型类别与18类首版映射不一致，已停止赐予。")
            device = "0" if torch.cuda.is_available() else "cpu"
            capture = cv2.VideoCapture(self.args.camera, cv2.CAP_DSHOW)
            if not capture.isOpened():
                capture.release()
                capture = cv2.VideoCapture(self.args.camera, cv2.CAP_MSMF)
            if not capture.isOpened():
                raise RuntimeError("无法打开摄像头，请检查Windows摄像头权限或关闭占用摄像头的应用，然后重试。")
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            tracker = StableTracker()
            sequence = 0
            misses = 0
            while not self.stop.is_set():
                started = time.monotonic()
                ok, frame = capture.read()
                if not ok:
                    misses += 1
                    if misses >= 5:
                        raise RuntimeError("摄像头画面中断，请检查设备后重新开启。")
                    self.stop.wait(.2)
                    continue
                misses = 0
                frame = cv2.flip(frame, 1)
                height, width = frame.shape[:2]
                if width > 640:
                    frame = cv2.resize(frame, (640, int(height * 640 / width)))
                    height, width = frame.shape[:2]
                try:
                    result = model.predict(frame, imgsz=512, conf=.45, device=device, verbose=False, max_det=12)[0]
                except Exception:
                    if device == "cpu":
                        raise
                    logging.exception("GPU inference failed, retrying on CPU")
                    device = "cpu"
                    model.to("cpu")
                    if torch.cuda.is_available():
                        torch.cuda.empty_cache()
                    result = model.predict(frame, imgsz=512, conf=.45, device=device, verbose=False, max_det=12)[0]
                detections = []
                for box in result.boxes:
                    class_id = int(box.cls.item())
                    xyxy = [float(v) for v in box.xyxy[0].tolist()]
                    detections.append({"class_id":class_id, "class_name":CLASS_NAMES[class_id], "confidence":round(float(box.conf.item()),4), "box":xyxy})
                candidates = tracker.update(detections, time.monotonic())
                for candidate in candidates:
                    x1,y1,x2,y2 = map(int, candidate["box"])
                    color = (110,215,130) if candidate["stable"] else (80,170,220)
                    cv2.rectangle(frame, (x1,y1), (x2,y2), color, 2)
                    cv2.putText(frame, f'{candidate["class_name"]} {candidate["confidence"]:.0%}', (x1,max(18,y1-5)), cv2.FONT_HERSHEY_SIMPLEX,.5,color,1)
                success, jpg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY,75])
                if not success:
                    raise RuntimeError("摄像头画面编码失败。")
                sequence += 1
                self.publish(status="ready", message="请将物品放在镜头前保持稳定，再点击“定格选择”。", device="GPU" if device != "cpu" else "CPU", sequence=sequence,
                             frame_jpeg=base64.b64encode(jpg).decode("ascii"), width=width, height=height, candidates=candidates)
                self.stop.wait(max(0,.25-(time.monotonic()-started)))
        except Exception as exc:
            logging.exception("Camera session failed")
            self.publish(status="error", message=str(exc), candidates=[], frame_jpeg="")
        finally:
            if capture is not None:
                capture.release()
            logging.info("camera_released session=%s", self.args.session)

def parent_alive(pid):
    if os.name != "nt":
        return True
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.restype = ctypes.c_void_p
    handle = kernel.OpenProcess(0x1000, False, pid)
    if not handle:
        return False
    code = ctypes.c_ulong()
    alive = bool(kernel.GetExitCodeProcess(ctypes.c_void_p(handle), ctypes.byref(code))) and code.value == 259
    kernel.CloseHandle(ctypes.c_void_p(handle))
    return alive

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--session", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--parent", type=int, required=True)
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--log", required=True)
    args = parser.parse_args()
    Path(args.log).parent.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("YOLO_CONFIG_DIR", str(Path(args.log).parent / "yolo-config"))
    logging.basicConfig(filename=args.log, level=logging.INFO, encoding="utf-8", format="%(asctime)s %(levelname)s %(message)s")
    session = CameraSession(args)
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass
        def authorized(self):
            if self.headers.get("X-AIU5-Token") != args.token:
                self.send_error(403)
                return False
            session.last_request = time.monotonic()
            return True
        def do_GET(self):
            if not self.authorized(): return
            if self.path != "/snapshot":
                self.send_error(404); return
            with session.lock:
                payload = json.dumps(session.snapshot, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)
        def do_POST(self):
            if not self.authorized(): return
            if self.path != "/stop":
                self.send_error(404); return
            session.stop.set()
            self.send_response(204); self.end_headers()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.timeout = .5
    server.daemon_threads = True
    worker = threading.Thread(target=session.run, name="yolo-camera", daemon=True)
    worker.start()
    try:
        while not session.stop.is_set():
            server.handle_request()
            if time.monotonic()-session.last_request > 20 or not parent_alive(args.parent):
                session.stop.set()
    finally:
        session.stop.set()
        worker.join(timeout=4)
        server.server_close()
        logging.info("session_closed %s", args.session)

if __name__ == "__main__":
    main()
