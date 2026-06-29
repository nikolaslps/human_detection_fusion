# 03 — Installation & Hello World

The supported and recommended runtime is **Docker** (Vulcanexus Humble image). The **hello world**
here is minimal — it only confirms the install works and the full dependency chain is correctly
built. To see the detection pipeline running against simulated sensors, run the **demo** in
[`04_basic_demo_how_to_use.md`](04_basic_demo_how_to_use.md).

## Dependencies

| Category | Hello world | Full demo | Where |
|---|---|---|---|
| Operating system | Linux with Docker Engine | Same | `run.sh`, `docker/Dockerfile` |
| ROS 2 / Vulcanexus | None on the host — Humble + Vulcanexus is baked into the image | Same | `docker/Dockerfile`: `FROM eprosima/vulcanexus:humble-desktop` |
| ultralytics / YOLO | None on the host — installed inside the image via `pip` | Same | `docker/Dockerfile` |
| `hri_msgs` | None on the host — cloned and built inside the image | Same | `docker/Dockerfile` |
| `ultralytics_ros` | None on the host — cloned from `nikolaslps/ultralytics_ros` inside the image | Same | `docker/Dockerfile` |
| Docker | Required | Required | `run.sh` |
| X11 server | Not required | Required only for `--rviz` | `run.sh --rviz` |
| FIWARE / Context Broker | Not required | Not required | `docs/02_interfaces.md` — UWB comes from FIWARE in production; sim uses a UWB simulator node instead |
| Hardware | **None** | **None** (companion simulation repo stands in) | `docs/01_arise_context.md` target platforms |
| Companion simulation repo | Not required | Required — [`pmb2_hunav_simulation`](../../pmb2_hunav_simulation) `kiro_sensors` branch, cloned as a sibling directory | `examples/run_demo.md` |

## Install (Docker)

```bash
# From repository root
chmod +x run.sh examples/run_demo.sh
./run.sh --shell
```

`--shell` builds the image (several minutes — installs ultralytics, clones and builds
`ultralytics_ros` and `hri_msgs` from source, builds `human_detection_fusion`) and drops you into
a bash shell inside the container. No robot, simulation, or network sensors needed for this step.

On repeat runs, skip the build:

```bash
./run.sh --no-build --shell
```

## Hello world — confirm the install works

Inside the container shell (via `./run.sh --shell`):

```bash
# 1. Verify the ROS 2 package is built
ros2 pkg list | grep human_detection
# Expected: human_detection_fusion

# 2. Verify ultralytics / YOLO is available
python3 -c "from ultralytics import YOLO; print('YOLO ok')"
# Expected: YOLO ok

# 3. Verify hri_msgs are available
ros2 interface show hri_msgs/msg/IdsList
# Expected: std_msgs/Header header \n string[] ids

# 4. Verify the fusion executable exists
ros2 run human_detection_fusion yolo_uwb_fusion_node --help 2>&1 | head -3
```

All four commands succeeding confirms that the Docker image is correctly built and the full
dependency chain is satisfied. No sensor hardware is required.

## Native (no Docker)

Native installation is possible but requires building `ultralytics_ros`, `hri_msgs`, and
`human_detection_fusion` from source against a Vulcanexus Humble install — the same steps
`docker/Dockerfile` automates. Docker is strongly recommended. If you need a native setup, follow
the build steps in `docker/Dockerfile` as a reference script.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Build takes very long or fails cloning dependencies | Network access required during `docker build`; retry on a stable connection. `ultralytics_ros` and `hri_msgs` are cloned from GitHub. |
| `ros2 pkg list` is empty inside the shell | Source the workspace: `source /home/ros2_ws/install/setup.bash` |
| `human_detection_fusion` not listed | Build failed silently — check `docker build` output for CMake or colcon errors. |
| `python3 -c "from ultralytics import YOLO"` fails | `pip install ultralytics` step failed at build time — check network during build. |
| `yolov8m-seg.pt` download on first run | Expected — ultralytics auto-downloads model weights (~52 MB) on first `YOLO()` call. Pre-download and bind-mount at `/root/.cache/ultralytics/` for offline deployments. |
| YOLO model not loading in `--sim` mode | The 8 s `TimerAction` delay in the launch file should allow YOLO to load first — if it still fails, increase the delay in `launch/human_detection.launch.py`. |
| Nodes don't see each other | DDS discovery — ensure `--network host`; align `ROS_DOMAIN_ID` across containers. |

## Next: the demo

To run the full pipeline against Gazebo-simulated sensors — PMB2 with VLP-16 LiDAR, RealSense
D435 camera, and a UWB simulator node — continue to
[`04_basic_demo_how_to_use.md`](04_basic_demo_how_to_use.md).
