#!/usr/bin/env bash

# Test runner for ibswinfo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$REPO_DIR/tests/bin:$PATH"

# Function to run tests for a specific dump file
run_tests_for_dump() {
    local dump_file=$1
    export MOCK_DUMP_FILE="$dump_file"
    
    echo "----------------------------------------------------------------"
    echo "Testing with dump: $(basename "$dump_file")"
    
    # Extract metadata
    local expected_pn=$(grep "# EXPECTED_PN=" "$dump_file" | cut -d= -f2)
    local expected_lid=$(grep "# EXPECTED_LID=" "$dump_file" | cut -d= -f2)
    
    if [[ -z "$expected_pn" ]]; then
        echo "WARNING: No metadata found in dump (EXPECTED_PN), skipping advanced checks."
    fi

    # Determine device to use (LID preferred if available in metadata to bypass /dev/mst checks)
    local device_arg=""
    if [[ -n "$expected_lid" ]]; then
        device_arg="lid-$expected_lid"
    else
        # Fallback to MST device detection
        device_arg=$("$REPO_DIR/tests/bin/mst" status | grep "/dev/mst/SW_" | head -n 1)
    fi
    
    echo "Using Device: $device_arg"

    # Test version (Global test, but good to run here too)
    local script_version=$(grep '^VERSION=' "$REPO_DIR/ibswinfo.sh" | cut -d'"' -f2)
    local output_v=$("$REPO_DIR/ibswinfo.sh" -v)
    if [[ "$output_v" != *"version $script_version"* ]]; then
        echo "FAILED: Version mismatch (Expected: $script_version, Got: $output_v)"
        return 1
    fi

    # Test Inventory
    echo -n "  [Inventory] "
    local output_inv_file=$(mktemp)
    local error_inv_file=$(mktemp)
    "$REPO_DIR/ibswinfo.sh" -d "$device_arg" -o inventory > "$output_inv_file" 2> "$error_inv_file"
    local output_inv=$(cat "$output_inv_file")
    local error_inv=$(cat "$error_inv_file")
    rm "$output_inv_file" "$error_inv_file"

    if [[ -n "$expected_pn" ]]; then
        if [[ "$output_inv" == *"$expected_pn"* ]]; then
            echo "OK"
        else
            echo "FAILED (Part Number $expected_pn not found)"
            echo "--- STDOUT ---"
            echo "$output_inv"
            echo "--- STDERR ---"
            echo "$error_inv"
            return 1
        fi
    else
        echo "SKIPPED (No metadata)"
    fi

    # Test JSON
    echo -n "  [JSON]      "
    local output_json=$("$REPO_DIR/ibswinfo.sh" -d "$device_arg" -o json 2>/dev/null)
    if [[ "$output_json" == *"\"node_description\":"* ]]; then
        echo "OK"
    else
        echo "FAILED (Invalid JSON)"
        return 1
    fi

    # Test Dashboard
    echo -n "  [Dashboard] "
    local output_dash=$("$REPO_DIR/ibswinfo.sh" -d "$device_arg" -o dashboard 2>/dev/null)
    if [[ "$output_dash" == *"Thermals"* ]]; then
        echo "OK"
    else
        echo "FAILED (Dashboard output mismatch)"
        return 1
    fi
    
    return 0
}

# Main loop
global_status=0
echo "=== Running Multi-Version Tests ==="

count=0
for dump in "$REPO_DIR"/tests/mocks/ibsw_dump_*.txt; do
    if [[ -f "$dump" ]]; then
        run_tests_for_dump "$dump"
        if [[ $? -ne 0 ]]; then
            global_status=1
        fi
        ((count++))
    fi
done

if [[ $count -eq 0 ]]; then
    echo "No dump files found in tests/mocks/"
    exit 1
fi

echo "----------------------------------------------------------------"
if [[ $global_status -eq 0 ]]; then
    echo "All tests passed successfully on $count dumps!"
else
    echo "Some tests FAILED."
fi

exit $global_status