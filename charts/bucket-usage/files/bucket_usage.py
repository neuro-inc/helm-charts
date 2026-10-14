import datetime
import hashlib
import hmac
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ENDPOINT = os.environ["S3_ENDPOINT"].rstrip("/")
REGION = os.environ["S3_REGION"]
BUCKETS = [b for b in os.environ["S3_BUCKETS"].split(",") if b]
INTERVAL = int(os.environ.get("SCAN_INTERVAL_SECONDS", "900"))
PORT = int(os.environ.get("PORT", "9100"))
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
KINDS = ("registry_blobs", "registry_uploads", "registry_repositories", "other")

state = {b: {"bytes": None, "objects": None, "success": 0, "last_success": 0.0, "duration": 0.0} for b in BUCKETS}
lock = threading.Lock()


def credentials(index):
    return os.environ[f"S3_ACCESS_KEY_{index}"], os.environ[f"S3_SECRET_KEY_{index}"]


def sign(key, msg):
    return hmac.new(key, msg.encode(), hashlib.sha256).digest()


def list_page(bucket, access_key, secret_key, token):
    url = urllib.parse.urlsplit(f"{ENDPOINT}/{bucket}")
    params = {"encoding-type": "url", "list-type": "2", "max-keys": "1000"}
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
        ["GET", url.path, query, *(f"{k}:{headers[k]}" for k in sorted(headers)), "", signed, EMPTY_SHA256]
    )
    scope = f"{day}/{REGION}/s3/aws4_request"
    to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical.encode()).hexdigest()])
    key = sign(sign(sign(sign(f"AWS4{secret_key}".encode(), day), REGION), "s3"), "aws4_request")
    signature = hmac.new(key, to_sign.encode(), hashlib.sha256).hexdigest()
    headers["authorization"] = (
        f"AWS4-HMAC-SHA256 Credential={access_key}/{scope}, SignedHeaders={signed}, Signature={signature}"
    )
    headers["user-agent"] = "bucket-usage/1.0"
    request = urllib.request.Request(f"{ENDPOINT}/{bucket}?{query}", headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return ET.fromstring(response.read())
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"HTTP {error.code}: {error.read()[:300]!r}") from None


def kind_of(key):
    if key.startswith("docker/registry/v2/blobs/"):
        return "registry_blobs"
    if key.startswith("docker/registry/v2/repositories/"):
        return "registry_uploads" if "/_uploads/" in key else "registry_repositories"
    return "other"


def scan(bucket, access_key, secret_key):
    sizes = dict.fromkeys(KINDS, 0)
    counts = dict.fromkeys(KINDS, 0)
    token = None
    while True:
        page = list_page(bucket, access_key, secret_key, token)
        ns = page.tag[: page.tag.index("}") + 1] if page.tag.startswith("{") else ""
        for item in page.iter(f"{ns}Contents"):
            kind = kind_of(urllib.parse.unquote_plus(item.findtext(f"{ns}Key")))
            sizes[kind] += int(item.findtext(f"{ns}Size"))
            counts[kind] += 1
        if page.findtext(f"{ns}IsTruncated") != "true":
            return sizes, counts
        token = page.findtext(f"{ns}NextContinuationToken")
        if not token:
            raise RuntimeError("truncated listing without a continuation token")


def loop():
    while True:
        for index, bucket in enumerate(BUCKETS):
            started = time.time()
            try:
                sizes, counts = scan(bucket, *credentials(index))
                with lock:
                    state[bucket].update(bytes=sizes, objects=counts, success=1, last_success=time.time())
                print(f"{bucket}: {sum(counts.values())} objects, {sum(sizes.values())} bytes", flush=True)
            except Exception as error:
                with lock:
                    state[bucket]["success"] = 0
                print(f"{bucket}: scan failed: {error!r}", flush=True)
            with lock:
                state[bucket]["duration"] = time.time() - started
        time.sleep(INTERVAL)


def render():
    with lock:
        snapshot = {b: dict(s) for b, s in state.items()}
    helps = {
        "s3_bucket_bytes": "Bytes in the bucket at the last successful listing, by key layout",
        "s3_bucket_objects": "Objects in the bucket at the last successful listing, by key layout",
        "s3_bucket_scan_success": "1 if the last listing of the bucket succeeded",
        "s3_bucket_scan_last_success_timestamp_seconds": "Unix time of the last successful listing",
        "s3_bucket_scan_duration_seconds": "Duration of the last listing",
    }
    series = {name: [] for name in helps}
    for bucket, s in snapshot.items():
        label = f'bucket="{bucket}"'
        if s["bytes"] is not None:
            series["s3_bucket_bytes"] += [f'{{{label},kind="{k}"}} {v}' for k, v in s["bytes"].items()]
            series["s3_bucket_objects"] += [f'{{{label},kind="{k}"}} {v}' for k, v in s["objects"].items()]
        series["s3_bucket_scan_success"].append(f"{{{label}}} {s['success']}")
        series["s3_bucket_scan_last_success_timestamp_seconds"].append(f"{{{label}}} {s['last_success']}")
        series["s3_bucket_scan_duration_seconds"].append(f"{{{label}}} {s['duration']}")
    lines = []
    for name, values in series.items():
        if values:
            lines.append(f"# HELP {name} {helps[name]}")
            lines.append(f"# TYPE {name} gauge")
            lines += [name + v for v in values]
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
