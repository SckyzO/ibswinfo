#!/usr/bin/env bash

# Test runner for ibswinfo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$REPO_DIR/tests/bin:$PATH"

# We use a LID to avoid /dev/mst file checks
# The dump corresponds to LID 0x16 = 22
DEVICE="lid-22"

echo "=== Running Tests with Real Data Dump ==="
echo "Using Mock Device: $DEVICE"

# Test version
echo -n "Testing version... "
OUTPUT=$("$REPO_DIR/ibswinfo.sh" -v)
if [[ "$OUTPUT" == *"version 0.7"* ]]; then
    echo "OK"
else
    echo "FAILED (Got: $OUTPUT)"
    exit 1
fi

# Test inventory gathering (real dump reading)
echo -n "Testing inventory gathering... "

# Capture stdout and stderr in temporary files
STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)

"$REPO_DIR/ibswinfo.sh" -d "$DEVICE" -o inventory > "$STDOUT_FILE" 2> "$STDERR_FILE"
RET_CODE=$?
OUTPUT=$(cat "$STDOUT_FILE")
ERR_OUTPUT=$(cat "$STDERR_FILE")

rm "$STDOUT_FILE" "$STDERR_FILE"

# Verification based on ibsw_dump.txt content
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

# Test JSON output

echo -n "Testing JSON output... "

OUTPUT=$("$REPO_DIR/ibswinfo.sh" -d "$DEVICE" -o json 2>/dev/null)



# Basic JSON validation (check for some keys and valid structure)

if [[ "$OUTPUT" == *"\"node_description\":"* && "$OUTPUT" == *"\"uptime_sec\":"* ]]; then

    # Try to validate with python if available

    if command -v python3 &>/dev/null; then

        echo "$OUTPUT" | python3 -m json.tool >/dev/null

        if [[ $? -eq 0 ]]; then

            echo "OK"

        else

            echo "FAILED (Invalid JSON)"

            exit 1

        fi

    else

        echo "OK (Basic check)"

    fi

else

    echo "FAILED"

    exit 1

fi



# Test Dashboard output
echo -n "Testing Dashboard output... "
OUTPUT=$("$REPO_DIR/ibswinfo.sh" -d "$DEVICE" -o dashboard 2>/dev/null)

if [[ "$OUTPUT" == *"Thermals"* && "$OUTPUT" == *"Cooling"* ]]; then
    echo "OK"
else
    echo "FAILED"
    exit 1
fi

echo "All tests passed successfully!"
