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
    local expected_pn
    expected_pn=$(grep "# EXPECTED_PN=" "$dump_file" | cut -d= -f2)
    local expected_lid
    expected_lid=$(grep "# EXPECTED_LID=" "$dump_file" | cut -d= -f2)
    
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
    local script_version
    script_version=$(grep '^VERSION=' "$REPO_DIR/ibswinfo.sh" | cut -d'"' -f2)
    local output_v
    output_v=$("$REPO_DIR/ibswinfo.sh" -v)
    if [[ "$output_v" != *"version $script_version"* ]]; then
        echo "FAILED: Version mismatch (Expected: $script_version, Got: $output_v)"
        return 1
    fi

    # Test Inventory
    echo -n "  [Inventory] "
    local output_inv_file
    output_inv_file=$(mktemp)
    local error_inv_file
    error_inv_file=$(mktemp)
    "$REPO_DIR/ibswinfo.sh" -d "$device_arg" -o inventory > "$output_inv_file" 2> "$error_inv_file"
    local output_inv
    output_inv=$(cat "$output_inv_file")
    local error_inv
    error_inv=$(cat "$error_inv_file")
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
    local output_json
    output_json=$("$REPO_DIR/ibswinfo.sh" -d "$device_arg" -o json 2>/dev/null)
    if [[ "$output_json" == *"\"node_description\":"* ]]; then
        echo "OK"
    else
        echo "FAILED (Invalid JSON)"
        return 1
    fi

    # Test Dashboard
    echo -n "  [Dashboard] "
    local output_dash
    output_dash=$("$REPO_DIR/ibswinfo.sh" -d "$device_arg" -o dashboard 2>/dev/null)
    if [[ "$output_dash" == *"POWER SUPPLY"* ]]; then
        echo "OK"
    else
        echo "FAILED (Dashboard output mismatch)"
        return 1
    fi

    # Test graceful handling of unsupported registers (Issue #1).
    # The FW-LIMITED fixture intentionally injects "-E- FW burnt..." on MSCI;
    # the script must exit 0, emit a warning on stderr, and still produce
    # parsable output for the registers that did succeed.
    if [[ "$(basename "$dump_file")" == "ibsw_dump_LID42_FW-LIMITED.txt" ]]; then
        echo -n "  [FW-burnt] "
        local fwb_stdout fwb_stderr fwb_rc
        local fwb_out_file fwb_err_file
        fwb_out_file=$(mktemp)
        fwb_err_file=$(mktemp)
        "$REPO_DIR/ibswinfo.sh" -d "$device_arg" > "$fwb_out_file" 2> "$fwb_err_file"
        fwb_rc=$?
        fwb_stdout=$(cat "$fwb_out_file")
        fwb_stderr=$(cat "$fwb_err_file")
        rm "$fwb_out_file" "$fwb_err_file"

        if [[ $fwb_rc -ne 0 ]]; then
            echo "FAILED (exit code $fwb_rc, expected 0)"
            echo "--- STDERR ---"
            echo "$fwb_stderr"
            return 1
        fi
        if [[ "$fwb_stderr" != *"warning: register MSCI unavailable"* ]]; then
            echo "FAILED (no warning emitted for unsupported MSCI register)"
            echo "--- STDERR ---"
            echo "$fwb_stderr"
            return 1
        fi
        if [[ "$fwb_stdout" != *"part number"* ]]; then
            echo "FAILED (stdout missing expected fields after register skip)"
            echo "--- STDOUT ---"
            echo "$fwb_stdout"
            return 1
        fi
        echo "OK"
    fi

    # Test JSON output safety against special characters (Issue #3).
    # The JSON-SPECIAL fixture has a node_description containing " and \,
    # which would break naive interpolation. Verify the output parses as
    # valid JSON and that the node_description round-trips intact.
    if [[ "$(basename "$dump_file")" == "ibsw_dump_LID77_JSON-SPECIAL.txt" ]]; then
        echo -n "  [JSON-safe] "
        local js_out js_parsed
        js_out=$("$REPO_DIR/ibswinfo.sh" -d "$device_arg" -o json 2>/dev/null)

        # Pick a JSON validator: prefer jq, fall back to python3.
        local validator=""
        if command -v jq >/dev/null 2>&1; then
            validator="jq"
        elif command -v python3 >/dev/null 2>&1; then
            validator="python3"
        else
            echo "SKIPPED (no jq or python3 available)"
            return 0
        fi

        if [[ "$validator" == "jq" ]]; then
            if ! echo "$js_out" | jq -e . >/dev/null 2>&1; then
                echo "FAILED (jq could not parse JSON)"
                echo "--- OUTPUT ---"
                echo "$js_out"
                return 1
            fi
            js_parsed=$(echo "$js_out" | jq -r .node_description)
        else
            if ! echo "$js_out" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
                echo "FAILED (python3 could not parse JSON)"
                echo "--- OUTPUT ---"
                echo "$js_out"
                return 1
            fi
            js_parsed=$(echo "$js_out" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["node_description"])')
        fi

        # The fixture encodes the literal string  "a\b"c  in the node
        # description hex blocks. Confirm round-trip integrity.
        if [[ "$js_parsed" != '"a\b"c' ]]; then
            printf '%s\n'   'FAILED (node_description round-trip mismatch)'
            printf '  got:      [%s]\n' "$js_parsed"
            printf '%s\n'   '  expected: ["a\b"c]'
            return 1
        fi
        echo "OK ($validator)"
    fi

    return 0
}

# Main loop
global_status=0
echo "=== Running Multi-Version Tests ==="

count=0
for dump in "$REPO_DIR"/tests/dumps/ibsw_dump_*.txt; do
    if [[ -f "$dump" ]]; then
        if ! run_tests_for_dump "$dump"; then
            global_status=1
        fi
        ((count++))
    fi
done

if [[ $count -eq 0 ]]; then
    echo "No dump files found in tests/dumps/"
    exit 1
fi

# Global CLI-validation tests (dump-independent).
echo "----------------------------------------------------------------"
echo "=== Global CLI tests ==="

# Issue #4: -S "" must be rejected up-front, before any device access,
# to avoid leaving node_description[0] uninitialized on the switch.
echo -n "  [empty -S]    "
empty_s_out=$("$REPO_DIR/ibswinfo.sh" -S "" 2>&1)
empty_s_rc=$?
if [[ $empty_s_rc -eq 0 ]]; then
    echo "FAILED (expected non-zero exit, got 0)"
    global_status=1
elif [[ "$empty_s_out" != *"description string cannot be empty"* ]]; then
    echo "FAILED (expected 'description string cannot be empty' in stderr)"
    echo "  got: [$empty_s_out]"
    global_status=1
else
    echo "OK"
fi

echo "----------------------------------------------------------------"
if [[ $global_status -eq 0 ]]; then
    echo "All tests passed successfully on $count dumps!"
else
    echo "Some tests FAILED."
fi

exit $global_status
