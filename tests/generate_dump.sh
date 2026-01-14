#!/usr/bin/env bash
#
# Helper script to generate a dump file for ibswinfo regression testing.
# Copy this script to your switch (or a machine with MFT installed), run it,
# and submit the generated file via a Pull Request.
#

OUTPUT_FILE="ibsw_dump_tmp_$(date +%Y%m%d_%H%M%S).txt"

# Help
usage() {
    cat << EOF
Usage: $(basename "$0") [device]

Helper script to generate a dump file for ibswinfo regression testing.

Arguments:
  device        Optional. Device path (e.g., /dev/mst/SW_...) or LID (e.g., lid-22).
                If not provided, the script attempts to auto-detect devices.

Options:
  -h, --help    Show this help message.
EOF
    exit 0
}

[[ "$1" == "-h" || "$1" == "--help" ]] && usage

# Check dependencies
if ! command -v mlxreg_ext &>/dev/null; then
    echo "Error: 'mlxreg_ext' command not found. Please install NVIDIA Firmware Tools (MFT)."
    exit 1
fi

DEVICE=$1

if [[ -z "$DEVICE" ]]; then
    echo "Scanning for devices..."
    DEVICES_LIST=()

    # Scan MST
    if command -v mst &>/dev/null; then
        while read -r line; do
            [[ -n "$line" ]] && DEVICES_LIST+=("$line (MST Device)")
        done < <(mst status 2>/dev/null | grep -oP '/dev/mst/SW_[^ ]+')
    fi

    # Scan IBSWITCHES
    if command -v ibswitches &>/dev/null; then
        while read -r line; do
            lid=$(echo "$line" | grep -oP 'lid \K[0-9]+')
            name=$(echo "$line" | grep -oP '"[^"]+"')
            [[ -n "$lid" ]] && DEVICES_LIST+=("lid-$lid (In-Band: $name)")
        done < <(ibswitches 2>/dev/null | grep "^Switch")
    fi

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
                # Extract just the device path/lid (before the first space)
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

# Commands to run
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
    eval "$cmd" >> "$OUTPUT_FILE" 2>&1
    echo -e "\n" >> "$OUTPUT_FILE"
done

echo "Done!"

# Try to auto-detect Part Number and LID from the dump we just made
AUTO_PN=$(grep -A 15 "COMMAND: .* --reg_name MSGI" "$OUTPUT_FILE" | grep "part_number" | awk '{print $NF}' | sed 's/0x//g; s/00$//' | xxd -r -p 2>/dev/null | tr -d '\0' | tr -d '[:space:]')
AUTO_LID=$(echo "$DEVICE" | grep -oP 'lid-\K[0-9]+')
[[ -z "$AUTO_LID" ]] && AUTO_LID=$(echo "$DEVICE" | grep -oP 'lid-0x\K[0-9a-fA-F]+' | xargs -I{} printf "%d" 0x{})

echo ""
echo "Detected metadata:"
echo "  Part Number: ${AUTO_PN:-Unknown}"
echo "  LID:         ${AUTO_LID:-Unknown}"

# Ask for confirmation or manual entry if auto-detect failed
read -p "Confirm Part Number (or enter manually): " -e -i "$AUTO_PN" EXP_PN
read -p "Confirm LID (or enter manually): " -e -i "$AUTO_LID" EXP_LID

# Clean up PN for filename
CLEAN_PN=$(echo "${EXP_PN:-UnknownModel}" | tr -cd '[:alnum:]-')
CLEAN_LID=$(echo "${EXP_LID:-UnknownLID}" | tr -cd '[:alnum:]')

FINAL_FILENAME="ibsw_dump_LID${CLEAN_LID}_${CLEAN_PN}.txt"

# Update header with confirmed metadata
sed -i "1a # EXPECTED_PN=$EXP_PN" "$OUTPUT_FILE"
sed -i "2a # EXPECTED_LID=$EXP_LID" "$OUTPUT_FILE"
mv "$OUTPUT_FILE" "$FINAL_FILENAME"

echo ""
echo "Final file: $FINAL_FILENAME"
echo "Please submit this file via Pull Request to 'tests/dumps/'."