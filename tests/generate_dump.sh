#!/usr/bin/env bash
#
# Helper script to generate a dump file for ibswinfo regression testing.
# Copy this script to your switch (or a machine with MFT installed), run it,
# and submit the generated file via a Pull Request.
#

OUTPUT_FILE="ibsw_dump_$(date +%Y%m%d_%H%M%S).txt"

# Help
usage() {
    cat << EOF
Usage: $(basename "$0") [device]

Helper script to generate a dump file for ibswinfo regression testing.

Arguments:
  device        Optional. Device path (e.g., /dev/mst/SW_...) or LID (e.g., lid-22).
                If not provided, the script attempts to auto-detect an MST device.

Options:
  -h, --help    Show this help message.

Example:
  ./generate_dump.sh
  ./generate_dump.sh lid-22
EOF
    exit 0
}

[[ "$1" == "-h" || "$1" == "--help" ]] && usage

# Check dependencies
if ! command -v mst &>/dev/null; then
    echo "Error: 'mst' command not found. Please install NVIDIA Firmware Tools (MFT)."
    exit 1
fi

# Detect device
DEVICE=$1
if [[ -z "$DEVICE" ]]; then
    echo "Scanning for MST devices..."
    MST_STATUS=$(mst status 2>/dev/null)
    DEVICE=$(echo "$MST_STATUS" | grep -oP '/dev/mst/SW_[^ ]+' | head -n 1)

    if [[ -z "$DEVICE" ]]; then
        echo "No MST device found automatically."
        echo "Current 'mst status' output:"
        echo "$MST_STATUS"
        echo ""
        echo "Tips:"
        echo "  - Run 'mst start' and 'mst ib add' to populate /dev/mst/"
        echo "  - Or use a LID (check 'ibswitches' output, e.g., lid-22)"
        echo ""
        read -p "Please enter the device path or LID: " DEVICE
    fi
fi

if [[ -z "$DEVICE" ]]; then
    echo "Error: No device specified."
    exit 1
fi

echo "Using device: $DEVICE"

# Collect metadata for tests
echo ""
echo "Please provide expected values for validation (leave empty if unsure):"
read -p "Expected Part Number (e.g., MQM8790-HS2F): " EXP_PN
read -p "Expected LID (decimal, e.g., 22): " EXP_LID

# Generate header
cat << EOF > "$OUTPUT_FILE"
# TEST_METADATA
# GENERATED_BY=generate_dump.sh
# DATE=$(date)
# DEVICE=$DEVICE
# EXPECTED_PN=$EXP_PN
# EXPECTED_LID=$EXP_LID
EOF

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

for cmd in "${commands[@]}"
do
    echo "======================================================================