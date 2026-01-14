#!/usr/bin/env bash
#
# =============================================================================
# ibswinfo Dump Generator
# =============================================================================
#
# Description:
#   This utility script generates a comprehensive register dump from an NVIDIA
#   Infiniband switch. This dump is used to create regression tests and mocks
#   for the 'ibswinfo' tool, allowing development and testing without physical
#   access to the hardware.
#
# Usage:
#   ./generate_dump.sh [device]
#
# Requirements:
#   - NVIDIA Firmware Tools (MFT) installed (specifically 'mst' and 'mlxreg_ext').
#   - Root privileges (usually required to access hardware registers).
#   - 'ibswitches' (optional, for better auto-detection).
#
# Output:
#   Generates a file named 'ibsw_dump_LID<lid>_<Model>.txt' in the current directory.
#
# =============================================================================

set -e # Exit immediately if a command exits with a non-zero status

OUTPUT_FILE="ibsw_dump_tmp_$(date +%Y%m%d_%H%M%S).txt"

# -----------------------------------------------------------------------------
# Help Function
# -----------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [device]

Helper script to generate a dump file for ibswinfo regression testing.

Arguments:
  device        Optional. Device path (e.g., /dev/mst/SW_...) or LID (e.g., lid-22).
                If not provided, the script attempts to auto-detect devices using
                'mst status' and 'ibswitches'.

Options:
  -h, --help    Show this help message.

Examples:
  ./generate_dump.sh           # Interactive mode (auto-detection)
  ./generate_dump.sh lid-22    # Capture dump for LID 22
EOF
    exit 0
}

[[ "$1" == "-h" || "$1" == "--help" ]] && usage

# -----------------------------------------------------------------------------
# Dependency Check
# -----------------------------------------------------------------------------
if ! command -v mlxreg_ext &>/dev/null; then
    echo "Error: 'mlxreg_ext' command not found. Please install NVIDIA Firmware Tools (MFT)."
    exit 1
fi

DEVICE=$1

# -----------------------------------------------------------------------------
# Device Detection & Selection
# -----------------------------------------------------------------------------
if [[ -z "$DEVICE" ]]; then
    echo "Scanning for devices..."
    DEVICES_LIST=()

    # 1. Scan MST devices (local PCI/USB)
    if command -v mst &>/dev/null; then
        while read -r line; do
            [[ -n "$line" ]] && DEVICES_LIST+=("$line (MST Device)")
        done < <(mst status 2>/dev/null | grep -oP '/dev/mst/SW_[^ ]+')
    fi

    # 2. Scan In-Band devices (via ibswitches)
    if command -v ibswitches &>/dev/null; then
        while read -r line; do
            lid=$(echo "$line" | grep -oP 'lid \K[0-9]+')
            name=$(echo "$line" | grep -oP '"[^"]+"')
            [[ -n "$lid" ]] && DEVICES_LIST+=("lid-$lid (In-Band: $name)")
        done < <(ibswitches 2>/dev/null | grep "^Switch")
    fi

    # 3. Interactive Menu
    if [[ ${#DEVICES_LIST[@]} -eq 0 ]]; then
        echo "No devices found automatically."
        read -p "Enter device path manually (e.g. /dev/mst/SW_... or lid-22): " DEVICE
    else
        echo ""
        echo "Found available devices:"
        for i in "${!DEVICES_LIST[@]}"; do
            echo "  $((i+1)). ${DEVICES_LIST[$i]}"
        done
        echo "  0. Enter manually"
        echo ""
        
        while [[ -z "$DEVICE" ]]; do
            read -p "Select a device (0-${#DEVICES_LIST[@]}): " CHOICE
            if [[ "$CHOICE" == "0" ]]; then
                read -p "Enter device path manually: " DEVICE
            elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [[ "$CHOICE" -ge 1 && "$CHOICE" -le "${#DEVICES_LIST[@]}" ]]; then
                # Extract device identifier (first word)
                SELECTED="${DEVICES_LIST[$((CHOICE-1))]}"
                DEVICE=$(echo "$SELECTED" | awk '{print $1}')
            else
                echo "Invalid choice. Please try again."
            fi
        done
    fi
fi

if [[ -z "$DEVICE" ]]; then
    echo "Error: No device specified."
    exit 1
fi

echo "Using device: $DEVICE"

# -----------------------------------------------------------------------------
# Dump Generation
# -----------------------------------------------------------------------------
# List of MFT commands to execute to gather all necessary registers
commands=(
    "mst version"
    "mlxreg_ext -d $DEVICE --reg_name MGIR --get"
    "mlxreg_ext -d $DEVICE --reg_name MGPIR --get --indexes slot_index=0x0"
    "mlxreg_ext -d $DEVICE --reg_name MSGI --get"
    "mlxreg_ext -d $DEVICE --reg_name MSCI --get --indexes index=0x0"
    "mlxreg_ext -d $DEVICE --reg_name SPZR --get --indexes swid=0x0"
    "mlxreg_ext -d $DEVICE --reg_name MSPS --get"
    "mlxreg_ext -d $DEVICE --reg_name MTMP --get --indexes sensor_index=0x0,slot_index=0x0"
    "mlxreg_ext -d $DEVICE --reg_name MFCR --get"
    "mlxreg_ext -d $DEVICE --show_reg MFCR"
)

echo ""
echo "Generating dump..."
echo "# TEST_METADATA" > "$OUTPUT_FILE"
echo "# DATE=$(date)" >> "$OUTPUT_FILE"
echo "# DEVICE=$DEVICE" >> "$OUTPUT_FILE"

for cmd in "${commands[@]}"; do
    echo "======================================================================" >> "$OUTPUT_FILE"
    echo "COMMAND: $cmd" >> "$OUTPUT_FILE"
    echo "======================================================================" >> "$OUTPUT_FILE"
    # Capture both stdout and stderr
    eval "$cmd" >> "$OUTPUT_FILE" 2>&1
    echo -e "\n" >> "$OUTPUT_FILE"
done

echo "Done!"

# -----------------------------------------------------------------------------
# Metadata Auto-Detection & Finalization
# -----------------------------------------------------------------------------

# Try to auto-detect Part Number (MSGI register) and LID from the generated dump
# Decodes hex string from 'part_number' field
AUTO_PN=$(grep -A 15 "COMMAND: .* --reg_name MSGI" "$OUTPUT_FILE" | grep "part_number" | awk '{print $NF}' | sed 's/0x//g; s/00$//' | xxd -r -p 2>/dev/null | tr -d '\0' | tr -d '[:space:]')

# Try to parse LID from device string
AUTO_LID=$(echo "$DEVICE" | grep -oP 'lid-\K[0-9]+')
[[ -z "$AUTO_LID" ]] && AUTO_LID=$(echo "$DEVICE" | grep -oP 'lid-0x\K[0-9a-fA-F]+' | xargs -I{} printf "%d" 0x{})

echo ""
echo "Detected metadata:"
echo "  Part Number: ${AUTO_PN:-Unknown}"
echo "  LID:         ${AUTO_LID:-Unknown}"

# Ask for user confirmation (pre-filled with detected values)
read -p "Confirm Part Number (or enter manually): " -e -i "$AUTO_PN" EXP_PN
read -p "Confirm LID (or enter manually): " -e -i "$AUTO_LID" EXP_LID

# Sanitize filenames
CLEAN_PN=$(echo "${EXP_PN:-UnknownModel}" | tr -cd '[:alnum:]-')
CLEAN_LID=$(echo "${EXP_LID:-UnknownLID}" | tr -cd '[:alnum:]')

FINAL_FILENAME="ibsw_dump_LID${CLEAN_LID}_${CLEAN_PN}.txt"

# Inject confirmed metadata into the dump header for automated testing
sed -i "1a # EXPECTED_PN=$EXP_PN" "$OUTPUT_FILE"
sed -i "2a # EXPECTED_LID=$EXP_LID" "$OUTPUT_FILE"

mv "$OUTPUT_FILE" "$FINAL_FILENAME"

echo ""
echo "Final file: $FINAL_FILENAME"
echo "Please submit this file via Pull Request to 'tests/dumps/'."
