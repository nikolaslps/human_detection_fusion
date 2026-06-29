# Human Detection Fusion — Simulation Demo

This demo runs two Docker containers on the same host to verify the full detection pipeline end-to-end, without needing a real robot, camera, or LiDAR.

| Container | Repo | What it does |
|---|---|---|
| `pmb2_hunav_simulation` | `pmb2_hunav_simulation` (`kiro_sensors` branch) | Gazebo Classic with PMB2 + VLP-16 lidar + RealSense D435 + HuNavSim pedestrians + simulated UWB |
| `human_detection_fusion` | this repo | YOLO + Bpearl fusion + UWB association → `/humans/persons/*` (ROS4HRI) |

---

## Prerequisites

- Docker installed and running
- X11 forwarding available (`echo $DISPLAY` should return something)
- `pmb2_hunav_simulation` cloned as a sibling directory (`../pmb2_hunav_simulation`) and checked out on the `kiro_sensors` branch:

```bash
git -C ../pmb2_hunav_simulation checkout kiro_sensors
```

---

## Quick path: run_demo.sh

```bash
chmod +x examples/run_demo.sh
./examples/run_demo.sh            # builds both images and runs all steps
./examples/run_demo.sh --no-build # skip builds on repeat runs
```

Individual steps:

```bash
./examples/run_demo.sh sim        # start simulation only
./examples/run_demo.sh detect     # start detection (sim must be running)
./examples/run_demo.sh test       # verify /humans/persons/tracked output
./examples/run_demo.sh stop       # stop both containers
```

Override the simulation repo path:

```bash
SIM_REPO_DIR=/path/to/pmb2_hunav_simulation ./examples/run_demo.sh
```

---

## Manual steps

If you prefer to run each command yourself:

**Step 1 — Start the simulation:**

```bash
cd ../pmb2_hunav_simulation
git checkout kiro_sensors
./run.sh --detach            # builds + runs in background
```

Wait ~30s for Gazebo to load and PMB2 to spawn. Confirm:

```bash
docker exec pmb2_hunav_simulation bash -c \
  "source /opt/ros/humble/setup.bash && ros2 topic list | grep bpearl"
# Expected: /bpearl_lidar/points
```

**Step 2 — Start human detection:**

```bash
cd ../human_detection_fusion
./run.sh --sim --rviz --detach
```

`--sim` switches to simulated clock + uncompressed camera topic + `base_link` planning frame.
`--rviz` opens RViz2 showing Bpearl point cloud, YOLO 3-D bounding boxes, and the annotated YOLO image.

Wait ~30s for YOLO to load its model (yolov8m-seg.pt auto-downloaded on first run), then another 20s for the fusion node delay.

**Step 3 — Verify detections:**

```bash
docker exec human_detection_fusion bash -c \
  "source /opt/vulcanexus/humble/setup.bash && \
   source /home/human_detect_ws/install/setup.bash && \
   ros2 topic echo /humans/persons/tracked --once"
```

Expected output contains a list of person IDs (e.g. `human_1`, `worker_1`).

**Step 4 — Stop:**

```bash
docker stop human_detection_fusion pmb2_hunav_simulation
```

---

## What RViz2 shows

With `--rviz`:

| Display | Topic | Type |
|---|---|---|
| Bpearl Points | `/bpearl_lidar/points` | PointCloud2 |
| YOLO Detections | `/detection_marker` | MarkerArray (3-D bounding boxes around detected people) |
| YOLO Image | `/yolo_image` | Image (annotated camera frame) |

---

## Known limitations affecting this demo

- **YOLO model download**: `yolov8m-seg.pt` (~52 MB) is downloaded by the ultralytics library on first run inside the container. If there is no internet access, pre-download the model and mount it at `/root/.cache/ultralytics/` or pass a local path via the `yolo_model` launch arg.
- **Gazebo spawn race**: Gazebo Classic loads the world slowly under software rendering. `run_demo.sh` retries the spawn check automatically. If you run manually and the robot doesn't appear, wait 30s and check again.
- **No UWB in real sim**: The simulated UWB mirrors HuNavSim agent positions, not real UWB ranging. All detected pedestrians will appear as `worker_1`/`worker_2` if within fusion distance, or `human_N` otherwise.
- **Compressed image**: In sim mode, `run.sh --sim` automatically switches to the uncompressed `/camera/camera/color/image_raw` topic. The real-robot default is the `/compressed` variant; pass `input_topic:=...` to override.
