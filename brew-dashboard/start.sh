#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$DIR/server.py" &
PID=$!
sleep 0.5
open "http://localhost:9999"
echo "Server PID: $PID  (kill with: kill $PID)"
wait $PID
