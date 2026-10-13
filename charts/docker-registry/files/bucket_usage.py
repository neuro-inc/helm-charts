import datetime
import hashlib
import hmac
import os
import threading
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ENDPOINT = os.environ["S3_ENDPOINT"].rstrip("/")
REGION = os.environ["S3_REGION"]
BUCKET = os.environ["S3_BUCKET"]
ACCESS_KEY = os.environ["S3_ACCESS_KEY"]
SECRET_KEY = os.environ["S3_SECRET_KEY"]
INTERVAL = int(os.environ.get("SCAN_INTERVAL_SECONDS", "900"))
PORT = int(os.environ.get("PORT", "9100"))
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
KINDS = ("blobs", "uploads", "repositories", "other")

state = {"bytes": None, "objects": None, "success": 0, "last_success": 0.0, "duration": 0.0}
lock = threading.Lock()


def sign(key, msg):
    return hmac.new(key, msg.encode(), hashlib.sha256).digest()


def list_page(token):
    url = urllib.parse.urlsplit(f"{ENDPOINT}/{BUCKET}")
    params = {"list-type": "2", "max-keys": "1000"}
    if token:
        params["continuation-token"] = token
    query = "&".join(
        f"{urllib.parse.quote(k, safe='-_.~')}={urllib.parse.quote(v, safe='-_.~')}" for k, v in sorted(params.items())
    )
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date, day = now.strftime("%Y%m%dT%H%M%SZ"), now.strftime("%Y%m%d")
    headers = {"host": url.netloc, "x-amz-content-sha256": EMPTY_SHA256, "x-amz-date": amz_date}
    signed = ";".join(sorted(headers))
    canonical = "\n".join(
        ["GET", urllib.parse.quote(url.path), query, *(f"{k}:{headers[k]}" for k in sorted(headers)), "", signed, EMPTY_SHA256]
    )
    scope = f"{day}/{REGION}/s3/aws4_request"
    to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical.encode()).hexdigest()])
    key = sign(sign(sign(sign(f"AWS4{SECRET_KEY}".encode(), day), REGION), "s3"), "aws4_request")
    signature = hmac.new(key, to_sign.encode(), hashlib.sha256).hexdigest()
    headers["authorization"] = (
        f"AWS4-HMAC-SHA256 Credential={ACCESS_KEY}/{scope}, SignedHeaders={signed}, Signature={signature}"
    )
    request = urllib.request.Request(f"{ENDPOINT}/{BUCKET}?{query}", headers=headers)
    with urllib.request.urlopen(request, timeout=120) as response:
        return ET.fromstring(response.read())


def kind_of(key):
    if key.startswith("docker/registry/v2/blobs/"):
        return "blobs"
    if "/_uploads/" in key:
        return "uploads"
    if key.startswith("docker/registry/v2/repositories/"):
        return "repositories"
    return "other"


def scan():
    sizes = dict.fromkeys(KINDS, 0)
    counts = dict.fromkeys(KINDS, 0)
    token = None
    while True:
        page = list_page(token)
        ns = page.tag[: page.tag.index("}") + 1] if page.tag.startswith("{") else ""
        for item in page.iter(f"{ns}Contents"):
            kind = kind_of(item.findtext(f"{ns}Key"))
            sizes[kind] += int(item.findtext(f"{ns}Size"))
            counts[kind] += 1
        if page.findtext(f"{ns}IsTruncated") != "true":
            return sizes, counts
        token = page.findtext(f"{ns}NextContinuationToken")
        if not token:
            raise RuntimeError("truncated listing without a continuation token")


def loop():
    while True:
        started = time.time()
        try:
            sizes, counts = scan()
            with lock:
                state.update(bytes=sizes, objects=counts, success=1, last_success=time.time())
            print(f"scan ok: {sum(counts.values())} objects, {sum(sizes.values())} bytes", flush=True)
        except Exception as error:
            with lock:
                state["success"] = 0
            print(f"scan failed: {error!r}", flush=True)
        with lock:
            state["duration"] = time.time() - started
        time.sleep(INTERVAL)


def render():
    with lock:
        snapshot = dict(state)
    label = f'bucket="{BUCKET}"'
    lines = []
    if snapshot["bytes"] is not None:
        lines.append("# TYPE registry_bucket_bytes gauge")
        lines += [f'registry_bucket_bytes{{{label},kind="{k}"}} {v}' for k, v in snapshot["bytes"].items()]
        lines.append("# TYPE registry_bucket_objects gauge")
        lines += [f'registry_bucket_objects{{{label},kind="{k}"}} {v}' for k, v in snapshot["objects"].items()]
    lines.append("# TYPE registry_bucket_scan_success gauge")
    lines.append(f"registry_bucket_scan_success{{{label}}} {snapshot['success']}")
    lines.append("# TYPE registry_bucket_scan_last_success_timestamp_seconds gauge")
    lines.append(f"registry_bucket_scan_last_success_timestamp_seconds{{{label}}} {snapshot['last_success']}")
    lines.append("# TYPE registry_bucket_scan_duration_seconds gauge")
    lines.append(f"registry_bucket_scan_duration_seconds{{{label}}} {snapshot['duration']}")
    return ("\n".join(lines) + "\n").encode()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            body, status = render(), 200
        elif self.path == "/healthz":
            body, status = b"ok\n", 200
        else:
            body, status = b"not found\n", 404
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    threading.Thread(target=loop, daemon=True).start()
    ThreadingHTTPServer(("", PORT), Handler).serve_forever()
