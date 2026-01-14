#!/usr/bin/env bash

# Test runner pour ibswinfo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$REPO_DIR/tests/bin:$PATH"

echo "=== Running Tests with Mocks ==="

# Test de la version
echo -n "Testing version... "
OUTPUT=$("$REPO_DIR/ibswinfo.sh" -v)
if [[ "$OUTPUT" == *"version 0.7"* ]]; then
    echo "OK"
else
    echo "FAILED (Got: $OUTPUT)"
    exit 1
fi

# Test de l'aide
echo -n "Testing usage... "
"$REPO_DIR/ibswinfo.sh" -h > /dev/null
if [[ $? -eq 2 ]]; then
    echo "OK"
else
    echo "FAILED"
    exit 1
fi

echo "All basic tests passed!"
