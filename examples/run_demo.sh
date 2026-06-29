#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run_demo.sh  –  PMB2 + HuNavSim (kiro_sensors branch) + human_detection_fusion demo
#
# Reproduces the two-container detection demo: simulated PMB2 with Bpearl lidar,
# RealSense camera, and UWB in one container; this repo's YOLO+UWB fusion stack
# in another, receiving sensor topics over --network host DDS.
#
# IMPORTANT: pmb2_hunav_simulation must be on the 'kiro_sensors' branch.
#
# Usage:
#   ./run_demo.sh                  # run every step in order (sim, detect, test)
#   ./run_demo.sh sim               # start simulation container only
#   ./run_demo.sh detect            # start human detection (sim must be running)
#   ./run_demo.sh test              # echo one detection from /humans/persons/tracked
#   ./run_demo.sh stop              # stop both containers
#   ./run_demo.sh --no-build all    # skip docker builds on repeat runs
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SIM_REPO_DIR="${SIM_REPO_DIR:-$MODULE_DIR/../pmb2_hunav_simulation}"
NO_BUILD=false

usage() {
    cat <<EOF
Usage: ./run_demo.sh [OPTIONS] [STEP]

Two-container demo: pmb2_hunav_simulation (kiro_sensors branch) as sensor source,
human_detection_fusion as the detection module.

Steps:
  sim      Start the simulation container (pmb2_hunav_simulation, kiro_sensors branch)
  detect   Start the human detection container (--sim --rviz)
  test     Echo one message from /humans/persons/tracked (verifies detection output)
  stop     Stop both containers
  all      Run sim, detect, test in order (default)

Options:
  --no-build   Skip docker build in both containers (images already exist)
  --help, -h   Show this help

Env overrides:
  SIM_REPO_DIR   Path to pmb2_hunav_simulation checkout
                 (default: $SIM_REPO_DIR)
EOF
}

require_sim_repo() {
    if [ ! -d "$SIM_REPO_DIR" ]; then
        echo "[run_demo] ERROR: simulation repo not found at $SIM_REPO_DIR"
        echo "           Clone pmb2_hunav_simulation as a sibling of human_detection_fusion/,"
        echo "           check it out on the 'kiro_sensors' branch,"
        echo "           or set SIM_REPO_DIR to point at your checkout."
        exit 1
    fi
    # Warn if the sim repo is not on kiro_sensors branch
    local current_branch
    current_branch=$(git -C "$SIM_REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [ "$current_branch" != "kiro_sensors" ]; then
        echo "[run_demo] WARNING: pmb2_hunav_simulation is on branch '$current_branch',"
        echo "           expected 'kiro_sensors' (which adds Bpearl + camera + UWB simulation)."
        echo "           Continuing — but sensor topics may be missing."
    fi
}

step_sim() {
    require_sim_repo
    echo "[run_demo] Starting simulation container (kiro_sensors branch)..."
    local build_flag=()
    [ "$NO_BUILD" = true ] && build_flag=(--no-build)
    (cd "$SIM_REPO_DIR" && ./run.sh --detach "${build_flag[@]}")

    # Gazebo world loads slowly under software rendering — wait for the robot
    # to appear on /joint_states before declaring success. The spawn_entity.py
    # service can be in 'ros2 service list' before it's actually callable, so we
    # retry the spawn itself (same quirk documented in kiro_nav's run_demo.sh).
    echo "[run_demo] Waiting for PMB2 to spawn (retrying known spawn_entity race)..."
    local attempt
    for attempt in 1 2 3 4 5 6; do
        if docker exec pmb2_hunav_simulation bash -c \
            "source /opt/ros/humble/setup.bash && \
             source /home/kiro_ws/install/setup.bash && \
             ros2 topic list 2>/dev/null | grep -q '/joint_states'" \
            >/dev/null 2>&1; then
            echo "[run_demo] PMB2 is up."
            return
        fi
        echo "[run_demo] Attempt $attempt: PMB2 not up yet, waiting 15s..."
        sleep 15
    done
    echo "[run_demo] WARNING: could not confirm PMB2 spawn after 6 attempts. Continuing."
}

step_detect() {
    echo "[run_demo] Starting human_detection_fusion container (--sim --rviz)..."
    local build_flag=()
    [ "$NO_BUILD" = true ] && build_flag=(--no-build)
    (cd "$MODULE_DIR" && ./run.sh --sim --rviz --detach "${build_flag[@]}")

    echo "[run_demo] Waiting for YOLO+UWB Fusion Node to start (up to 60s)..."
    local ready=false
    for ((i = 0; i < 60; i++)); do
        if docker logs human_detection_fusion 2>&1 | grep -q "YOLO+UWB Fusion Node started"; then
            ready=true
            break
        fi
        sleep 1
    done
    if [ "$ready" = true ]; then
        echo "[run_demo] Fusion node is active."
    else
        echo "[run_demo] WARNING: did not see fusion node ready message within 60s. Continuing."
    fi
}

step_test() {
    echo "[run_demo] Echoing one message from /humans/persons/tracked (10s timeout)..."
    docker exec human_detection_fusion bash -c \
        "source /opt/vulcanexus/humble/setup.bash && \
         source /home/human_detect_ws/install/setup.bash && \
         timeout 10 ros2 topic echo /humans/persons/tracked --once" \
    && echo "[run_demo] Detection output confirmed." \
    || echo "[run_demo] WARNING: no message received on /humans/persons/tracked within 10s."
}

step_stop() {
    echo "[run_demo] Stopping containers..."
    docker stop human_detection_fusion pmb2_hunav_simulation 2>/dev/null || true
}

STEP="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build) NO_BUILD=true; shift ;;
        --help|-h)  usage; exit 0 ;;
        sim|detect|test|stop|all) STEP="$1"; shift ;;
        *) echo "[run_demo] Unknown argument: $1"; usage; exit 1 ;;
    esac
done

case "$STEP" in
    sim)    step_sim ;;
    detect) step_detect ;;
    test)   step_test ;;
    stop)   step_stop ;;
    all)    step_sim; step_detect; step_test ;;
esac
