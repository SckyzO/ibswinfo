#!/usr/bin/env bash

# Test runner pour ibswinfo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$REPO_DIR/tests/bin:$PATH"

# On utilise un LID pour éviter les vérifications de fichiers /dev/mst
# Le dump correspond au LID 0x16 = 22
DEVICE="lid-22"

echo "=== Running Tests with Real Data Dump ==="
echo "Using Mock Device: $DEVICE"

# Test de la version
echo -n "Testing version... "
OUTPUT=$("$REPO_DIR/ibswinfo.sh" -v)
if [[ "$OUTPUT" == *"version 0.7"* ]]; then
    echo "OK"
else
    echo "FAILED (Got: $OUTPUT)"
    exit 1
fi

# Test de l'inventaire (lecture réelle du dump)
echo -n "Testing inventory gathering... "

# Capture stdout et stderr dans des fichiers temporaires
STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)

"$REPO_DIR/ibswinfo.sh" -d "$DEVICE" -o inventory > "$STDOUT_FILE" 2> "$STDERR_FILE"
RET_CODE=$?
OUTPUT=$(cat "$STDOUT_FILE")
ERR_OUTPUT=$(cat "$STDERR_FILE")

rm "$STDOUT_FILE" "$STDERR_FILE"

# Vérifications basées sur le contenu de ibsw_dump.txt
# PN: MQM9790-NS2F
if [[ "$OUTPUT" == *"MQM9790-NS2F"* ]]; then
     echo "OK"
else
    echo "FAILED"
    echo "Return Code: $RET_CODE"
    echo "--- STDOUT ---"
    echo "$OUTPUT"
    echo "--- STDERR ---"
    echo "$ERR_OUTPUT"
    exit 1
fi

echo "All tests passed successfully!"