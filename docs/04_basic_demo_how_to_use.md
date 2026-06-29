# 04 — Basic Demo & How to Use

The hello world ([`03`](03_installation_and_hello_world.md)) proves the install works. The **demo**
shows the module doing its actual job — detecting persons in a shared workspace and publishing their
3-D positions with worker identities — without any hardware, by using the companion simulation repo
as a reproducible stand-in for the real IKH warehouse deployment.

>[!NOTE]
> **Recommended:** For the full step-by-step walkthrough, see [`examples/run_demo.md`](../examples/run_demo.md).

## What the demo shows

Two Docker containers run on the same host:

1. **`pmb2_hunav_simulation`** (`kiro_sensors` branch) — Gazebo Classic with a PMB2 robot equipped with a simulated VLP-16 LiDAR, RealSense D435 camera, and a UWB simulator node. HuNavSim pedestrians move around the robot in a warehouse world. The UWB simulator node mirrors two pedestrian positions onto `uwb/worker1` and `uwb/worker2` (replacing what the FIWARE DDS↔NGSI-LD enabler provides in production).

2. **`human_detection_fusion`** — YOLO detects persons in the camera image,   `tracker_with_cloud_node` projects detections to 3-D using VLP-16 points, and `yolo_uwb_fusion_node` associates them with UWB worker identities, publishing ROS4HRI person positions.

## One-command demo

If not already done, *from the root of the current repo* run the following commands:
```bash
git clone https://github.com/andvatistas/pmb2_hunav_simulation.git ../pmb2_hunav_simulation
git -C ../pmb2_hunav_simulation checkout kiro_sensors
```

Now ready to run the one-command demo:

```bash
chmod +x examples/run_demo.sh
./examples/run_demo.sh
```

This builds both images on first run (~10–20 min total), starts the simulation container, then starts the detection container with RViz2, and verifies output on `/humans/persons/tracked`.

## Expected output

After all nodes are up (~45–60 s from `./examples/run_demo.sh`):

- **RViz2**: VLP-16 point cloud visible as a white point cloud around the robot; green 3-D bounding boxes (`/detection_marker`) around detected pedestrians; annotated camera image in the bottom panel showing YOLO bounding boxes with tracking IDs.
- **Topic**: `ros2 topic echo /humans/persons/tracked` returns an `IdsList` message with IDs such as `["worker_1", "worker_2"]` or `["human_1"]` (anonymous, when no UWB match is found within the fusion distance threshold).
- **Per-person position**: `ros2 topic echo /humans/persons/worker_1/position` returns a `PointOfInterest3DStamped` message with `x`, `y`, `z` in the `base_link` frame.

## Running against a real robot

The container needs to see the following topics before the fusion node becomes useful:

| Topic | Type | Source |
|---|---|---|
| `/camera/camera/color/image_raw/compressed` | `sensor_msgs/CompressedImage` | RealSense D455 driver |
| `/camera/camera/color/camera_info` | `sensor_msgs/CameraInfo` | RealSense D455 driver |
| `/bpearl_lidar/points` | `sensor_msgs/PointCloud2` | Bpearl LiDAR driver |
| `uwb/worker1` | `geometry_msgs/Point` | FIWARE DDS↔NGSI-LD enabler (`Worker:EMP-1 / mapPosition`) |
| `uwb/worker1_name_tag` | `std_msgs/String` | FIWARE DDS↔NGSI-LD enabler (`Worker:EMP-1 / nameTag`) |
| `uwb/worker2` | `geometry_msgs/Point` | FIWARE DDS↔NGSI-LD enabler (`Worker:EMP-2 / mapPosition`) |
| `uwb/worker2_name_tag` | `std_msgs/String` | FIWARE DDS↔NGSI-LD enabler (`Worker:EMP-2 / nameTag`) |

The TF tree must include `kiro_base_link` (or override `planning_frame` in
`config/detection_params.yaml`). Set `ROS_DISCOVERY_SERVER` before running if using a Fast DDS
discovery server:

```bash
export ROS_DISCOVERY_SERVER=<robot_ip>:11811
./run.sh
```

## Known limitations

- **YOLO model load time**: YOLO takes ~20–30 s to load on first run. The fusion node has an 8 s
  startup delay (configurable in `launch/human_detection.launch.py`) to let YOLO initialize first.
  If detections appear but the fusion node misses them initially, this is expected.
- **UWB identity matching**: if a pedestrian is detected visually but is farther than
  `FUSION_DISTANCE` from all UWB workers, it is published as `human_<N>` (anonymous). This is
  expected when a non-worker person enters the scene.
- **Simulation localization**: the simulated UWB positions from `pmb2_hunav_simulation` are in the
  `map` frame; ensure `uwb_frame: map` in `config/detection_params.yaml` (the default).

See `examples/run_demo.md` for additional troubleshooting steps.
