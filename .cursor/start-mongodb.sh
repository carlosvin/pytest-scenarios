#!/usr/bin/env bash
# Start a local MongoDB instance for pytest-scenarios tests.
# Idempotent: safe to run on every boot; does nothing if MongoDB is already up.
set -euo pipefail

DATA_DIR="${MONGO_DATA_DIR:-$HOME/.mongodb/data}"
LOG_DIR="${MONGO_LOG_DIR:-$HOME/.mongodb/log}"
MONGO_URI="mongodb://127.0.0.1:27017"

mkdir -p "$DATA_DIR" "$LOG_DIR"

ping_mongo() {
    mongosh --quiet --norc --eval 'db.runCommand({ ping: 1 })' "$MONGO_URI" >/dev/null 2>&1
}

if ping_mongo; then
    echo "MongoDB is already running at $MONGO_URI."
    exit 0
fi

# A previous mongod may have exited uncleanly; the lock file blocks a fresh start.
rm -f "$DATA_DIR/mongod.lock" 2>/dev/null || true

mongod \
    --dbpath "$DATA_DIR" \
    --logpath "$LOG_DIR/mongod.log" \
    --bind_ip 127.0.0.1 \
    --port 27017 \
    --fork

for _ in $(seq 1 30); do
    if ping_mongo; then
        echo "MongoDB is ready at $MONGO_URI."
        exit 0
    fi
    sleep 1
done

echo "MongoDB failed to become ready. Recent log output:" >&2
tail -n 40 "$LOG_DIR/mongod.log" >&2 || true
exit 1
