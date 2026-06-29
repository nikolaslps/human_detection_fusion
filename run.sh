#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh  –  Build (optional) and launch the human_detection_fusion container
#
# Usage:
#   ./run.sh                  # build and launch against real robot sensors
#   ./run.sh --sim            # build and launch in simulation mode (Gazebo pairing)
#   ./run.sh --no-build       # skip docker build (image already exists)
#   ./run.sh --shell          # drop into bash inside the container (debug/hello-world)
#   ./run.sh --rviz           # launch with RViz2 (Bpearl points, markers, YOLO image)
# ─────────────────────────────────────────────────────────────────────────────
set -e

IMAGE_NAME="human_detection_fusion:latest"
CONTAINER_NAME="human_detection_fusion"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
LAUNCH_DIR="$SCRIPT_DIR/launch"
RVIZ_DIR="$SCRIPT_DIR/rviz"
BUILD=true
SHELL_MODE=false
USE_SIM_TIME=false
DETACH=false
RVIZ=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build)  BUILD=false;        shift ;;
        --shell)     SHELL_MODE=true;    shift ;;
        --sim)       USE_SIM_TIME=true;  shift ;;
        --detach|-d) DETACH=true;        shift ;;
        --rviz)      RVIZ=true;          shift ;;
        --help|-h)
            echo "Usage: ./run.sh [OPTIONS]"
            echo ""
            echo "  --no-build       Skip docker build (use existing image)"
            echo "  --shell          Open a bash shell inside the container (no launch)"
            echo "                   Use to verify install: ros2 pkg list | grep human_detection"
            echo "  --sim            Use simulated clock + UDPv4 DDS transport (for Gazebo pairing)"
            echo "                   Also switches camera input to uncompressed /image_raw"
            echo "  --detach, -d     Run detached — used by examples/run_demo.sh"
            echo "  --rviz           Launch RViz2 (Bpearl points, detection markers, YOLO image)"
            echo ""
            echo "Environment overrides:"
            echo "  SIM_REPO_DIR     Path to pmb2_hunav_simulation checkout (for examples/)"
            echo "  ROS_DISCOVERY_SERVER  FastDDS discovery server (real-robot mode)"
            echo ""
            exit 0 ;;
        *) echo "[run.sh] Unknown argument: $1"; exit 1 ;;
    esac
done

if [ "$BUILD" = true ]; then
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Building image: $IMAGE_NAME"
    echo "═══════════════════════════════════════════"
    docker build -t "$IMAGE_NAME" -f docker/Dockerfile .
fi

if [ ! -d "$CONFIG_DIR" ]; then
    echo "[run.sh] ERROR: config/ not found at $CONFIG_DIR"; exit 1
fi
if [ ! -d "$LAUNCH_DIR" ]; then
    echo "[run.sh] ERROR: launch/ not found at $LAUNCH_DIR"; exit 1
fi

# DDS: always UDPv4 (FastRTPS/Vulcanexus) — avoids shared-memory transport
# silently failing across mismatched IPC namespaces when sibling containers share a host.
# Discovery server env vars are passed through for real-robot use.
DDS_FLAGS=(
    -e FASTDDS_BUILTIN_TRANSPORTS=UDPv4
    -e ROS_DISCOVERY_SERVER="${ROS_DISCOVERY_SERVER:-}"
    -e ROS_SUPER_CLIENT="${ROS_SUPER_CLIENT:-true}"
)

# Topic and frame selection: real vs sim
if [ "$USE_SIM_TIME" = true ]; then
    INPUT_TOPIC="/camera/camera/color/image_raw"
    PLANNING_FRAME="base_link"
else
    INPUT_TOPIC="/camera/camera/color/image_raw/compressed"
    PLANNING_FRAME="kiro_base_link"
fi

xhost +local:docker 2>/dev/null || true

if [ "$SHELL_MODE" = true ]; then
    CONTAINER_CMD="bash"
else
    CONTAINER_CMD="bash /launch/launch.sh /config/detection_params.yaml ${USE_SIM_TIME} ${RVIZ}"
fi

if [ "$DETACH" = true ]; then
    TTY_FLAG="-d"
else
    TTY_FLAG="-it"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  Starting $CONTAINER_NAME"
echo "  sim_time : $USE_SIM_TIME | rviz: $RVIZ"
echo "  input    : $INPUT_TOPIC"
echo "═══════════════════════════════════════════"
echo ""

docker run --rm \
    --name "$CONTAINER_NAME" \
    --network host \
    --pid host \
    -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    -e DISPLAY="${DISPLAY:-}" \
    -e QT_X11_NO_MITSHM=1 \
    -e USE_SIM_TIME="$USE_SIM_TIME" \
    -e INPUT_TOPIC="$INPUT_TOPIC" \
    -e PLANNING_FRAME="$PLANNING_FRAME" \
    -e RVIZ="$RVIZ" \
    "${DDS_FLAGS[@]}" \
    -v "$CONFIG_DIR":/config:ro \
    -v "$LAUNCH_DIR":/launch:ro \
    -v "$RVIZ_DIR":/rviz:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    "$TTY_FLAG" \
    "$IMAGE_NAME" \
    $CONTAINER_CMD
