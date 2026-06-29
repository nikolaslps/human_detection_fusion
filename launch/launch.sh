#!/bin/bash
# launch.sh — validator + launcher, runs inside the container
# Called by run.sh as: bash /launch/launch.sh <params_file> <use_sim_time> [<rviz>]
set -e

PARAMS_FILE="${1:-/config/detection_params.yaml}"
USE_SIM_TIME="${2:-false}"
RVIZ="${3:-${RVIZ:-false}}"
LAUNCH_FILE="${LAUNCH_FILE:-/launch/human_detection.launch.py}"

# INPUT_TOPIC and PLANNING_FRAME are injected as env vars by run.sh
INPUT_TOPIC="${INPUT_TOPIC:-/camera/camera/color/image_raw/compressed}"
PLANNING_FRAME="${PLANNING_FRAME:-kiro_base_link}"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   human_detection_fusion — ARISE D4 module  ║"
echo "╚══════════════════════════════════════════════╝"
echo "  params_file   : $PARAMS_FILE"
echo "  use_sim_time  : $USE_SIM_TIME"
echo "  input_topic   : $INPUT_TOPIC"
echo "  planning_frame: $PLANNING_FRAME"
echo "  rviz          : $RVIZ"
echo ""

# File checks — exit with a useful error if a mount is missing
for f in "$PARAMS_FILE" "$LAUNCH_FILE"; do
    if [ ! -f "$f" ]; then
        echo "[launch.sh] ERROR: Required file not found: $f"
        echo "            Mount it via: -v \$(pwd)/config:/config -v \$(pwd)/launch:/launch"
        exit 1
    fi
done

# Brief topic check (non-fatal) — 5s timeout per topic
echo "Checking expected input topics (5 s timeout each)..."
for topic in /bpearl_lidar/points /camera/camera/color/camera_info uwb/worker1 uwb/worker2; do
    if timeout 5 ros2 topic info "$topic" > /dev/null 2>&1; then
        echo "  [OK]  $topic"
    else
        echo "  [--]  $topic  (not seen yet — proceeding anyway)"
    fi
done
echo ""

source /opt/vulcanexus/humble/setup.bash
source /home/human_detect_ws/install/setup.bash

ros2 launch "$LAUNCH_FILE" \
    params_file:="$PARAMS_FILE" \
    use_sim_time:="$USE_SIM_TIME" \
    input_topic:="$INPUT_TOPIC" \
    planning_frame:="$PLANNING_FRAME" \
    rviz:="$RVIZ"
