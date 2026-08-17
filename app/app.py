import os
import socket
from datetime import datetime, timezone
from flask import Flask, jsonify

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "0.1.0")
ENVIRONMENT = os.environ.get("APP_ENV", "development")

@app.route("/")
def index():
    return jsonify({
        "app": "aks-demo",
        "version": VERSION,
        "environment": ENVIRONMENT,
        "hostname": socket.gethostname(),
        "timestamp": datetime.now(timezone.utc).isoformat()
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
