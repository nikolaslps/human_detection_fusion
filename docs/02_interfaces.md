# 02 — Interfaces

## ROS 2 / Vulcanexus interface

Runtime: **Vulcanexus Humble** (ROS 2 Humble + Fast DDS). The module is a containerized pipeline
composed of three ROS 2 nodes: a YOLO tracker, a LiDAR-camera fusion node (both from
`ultralytics_ros`), and the custom `yolo_uwb_fusion_node` that combines 3-D detections with UWB
worker identity data and publishes ROS4HRI person positions.

### Nodes

| Node | Package | Executable | Role |
|---|---|---|---|
| `tracker_node` | `ultralytics_ros` | `tracker_node.py` | YOLO inference + tracking → `/yolo_result`, `/yolo_image` |
| `tracker_with_cloud_node` | `ultralytics_ros` | `tracker_with_cloud_node` | LiDAR-camera projection → `/yolo_3d_result`, `/detection_marker` |
| `yolo_uwb_fusion_node` | `human_detection_fusion` | `yolo_uwb_fusion_node` | UWB identity fusion → `/humans/persons/*` |
| `rviz2` | `rviz2` | `rviz2` | Optional visualiser, activated by `rviz:=true` |

### Subscriptions (external inputs)

| Topic | Type | Source | Notes |
|---|---|---|---|
| `/camera/camera/color/image_raw/compressed` | `sensor_msgs/CompressedImage` | RealSense D455 driver | Real-robot default. Switch to `/image_raw` with `input_topic` arg in sim mode. |
| `/camera/camera/color/camera_info` | `sensor_msgs/CameraInfo` | RealSense D455 driver | Required for 3-D projection |
| `/bpearl_lidar/points` | `sensor_msgs/PointCloud2` | Bpearl LiDAR driver | Used by `tracker_with_cloud_node` to assign 3-D depth to detections |
| `uwb/worker1` | `geometry_msgs/Point` | DDS↔NGSI-LD enabler (FIWARE `Worker:EMP-1 / mapPosition`) | Position of worker 1 in UWB frame (default: `map`) |
| `uwb/worker1_name_tag` | `std_msgs/String` | DDS↔NGSI-LD enabler (FIWARE `Worker:EMP-1 / nameTag`) | Identity label for worker 1 |
| `uwb/worker2` | `geometry_msgs/Point` | DDS↔NGSI-LD enabler (FIWARE `Worker:EMP-2 / mapPosition`) | Position of worker 2 in UWB frame (default: `map`) |
| `uwb/worker2_name_tag` | `std_msgs/String` | DDS↔NGSI-LD enabler (FIWARE `Worker:EMP-2 / nameTag`) | Identity label for worker 2 |

### Internal topic (YOLO → fusion)

| Topic | Type | Description |
|---|---|---|
| `yolo_3d_result` | `vision_msgs/Detection3DArray` | 3-D bounding boxes from `tracker_with_cloud_node`, consumed by `yolo_uwb_fusion_node`. Not an external integration point. |

### Publications

| Topic | Type | Consumer | Notes |
|---|---|---|---|
| `/humans/persons/tracked` | `hri_msgs/IdsList` | Social navigation planners, HRI systems | List of currently detected person IDs |
| `/humans/persons/<id>/position` | `hri_msgs/PointOfInterest3DStamped` | Social navigation planners | 3-D position of person `<id>` in `planning_frame`. One publisher per active person, created dynamically. |
| `/yolo_result` | `vision_msgs/Detection2DArray` | `tracker_with_cloud_node` | YOLO 2-D detections with tracking IDs |
| `/yolo_image` | `sensor_msgs/Image` | RViz2, monitoring | Annotated camera frame with YOLO bounding boxes |
| `/detection_marker` | `visualization_msgs/MarkerArray` | RViz2 | 3-D bounding boxes as CUBE markers |

### Key parameters (`config/detection_params.yaml`)

| Parameter | Node | Default | Description |
|---|---|---|---|
| `planning_frame` | `yolo_uwb_fusion_node` | `kiro_base_link` | TF frame for publishing fused human positions. Sim: `base_link`. |
| `uwb_frame` | `yolo_uwb_fusion_node` | `map` | TF frame in which UWB positions are expressed. |
| `use_sim_time` | all nodes | `false` | Use `/clock` from Gazebo when `true`. Controlled by `run.sh --sim`. |
| `input_topic` | launch arg | `/camera/.../compressed` | Camera topic. Sim: `/image_raw`. |
| `yolo_model` | `tracker_node` | `yolov8m-seg.pt` | Ultralytics model. Auto-downloaded on first run (~52 MB). |
| `classes` | `tracker_node` | `0` | COCO class 0 = person. Set programmatically by `yolo_uwb_fusion_node` at startup. |
| `min_cluster_size` | `tracker_with_cloud_node` | `10` | Minimum Bpearl cluster points for a valid 3-D detection |
| `conf_thres` | `tracker_node` | `0.75` | YOLO detection confidence threshold |

### Launch files

| File | Purpose |
|---|---|
| `launch/human_detection.launch.py` | Main launch file. Starts `tracker_with_cloud` + `yolo_uwb_fusion_node` (delayed 8 s) + optional RViz2. Volume-mounted — edit without rebuilding. Args: `params_file`, `use_sim_time`, `input_topic`, `planning_frame`, `rviz`. |
| `launch/msgBridge.launch.py` | Legacy launch file, kept for backwards compatibility. Superseded by `human_detection.launch.py`. |

---

## ARISE middleware interfaces — applicability

The minimum ARISE interfaces are ROS 2/Vulcanexus, FIWARE/NGSI-LD, the DDS↔NGSI-LD enabler, and
ROS4HRI. For this module all four interfaces apply.

### FIWARE / NGSI-LD + DDS↔NGSI-LD enabler — ✅ Applied for UWB inputs

Worker positions and identity tags consumed by this module originate from FIWARE NGSI-LD `Worker`
entities in the KIRO Orion-LD context broker. The eProsima DDS↔NGSI-LD enabler bridges the
following NGSI-LD entity attributes as DDS topics, which ROS 2 receives natively over Fast DDS:

| DDS topic (enabler publishes) | ROS 2 topic (this module subscribes) | NGSI-LD entity | Attribute |
|---|---|---|---|
| `rt/uwb/worker1` | `uwb/worker1` | `urn:ngsi-ld:Worker:EMP-1` | `mapPosition` |
| `rt/uwb/worker1_name_tag` | `uwb/worker1_name_tag` | `urn:ngsi-ld:Worker:EMP-1` | `nameTag` |
| `rt/uwb/worker2` | `uwb/worker2` | `urn:ngsi-ld:Worker:EMP-2` | `mapPosition` |
| `rt/uwb/worker2_name_tag` | `uwb/worker2_name_tag` | `urn:ngsi-ld:Worker:EMP-2` | `nameTag` |

The `rt/` prefix is the Fast DDS / ROS 2 DDS-layer naming convention — ROS 2 topics are
automatically prefixed with `rt/` in the underlying DDS namespace, so the DDS enabler uses `rt/`
topic names to publish data that ROS 2 nodes receive without any remapping.

The full KIRO system-level DDS↔NGSI-LD enabler configuration (lives at KIRO system level, not in
this repository) is shown below. Entries consumed by this module are marked with `◄`:

```json
{
  "dds": {
    "ddsmodule": {
      "dds": {
        "domain": 0,
        "transport": "udp"
      }
    },
    "ngsild": {
      "topics": {

        "rt/robot/uwb/robot_pose": {
          "entityType": "Robot",
          "entityId": "urn:ngsi-ld:Robot:rb-1",
          "attribute": "mapPosition"
        },

        "rt/robot/status": {
          "entityType": "Robot",
          "entityId": "urn:ngsi-ld:Robot:rb-1",
          "attribute": "status"
        },

        "rt/robot/robot_name_tag": {
          "entityType": "Robot",
          "entityId": "urn:ngsi-ld:Robot:rb-1",
          "attribute": "nameTag"
        },

        "rt/mission/deliver_in_hand": {
          "entityType": "Mission",
          "entityId": "urn:ngsi-ld:Mission:ms-1",
          "attribute": "deliverInHand"
        },

        "rt/mission/tool_id": {
          "entityType": "Mission",
          "entityId": "urn:ngsi-ld:Mission:ms-1",
          "attribute": "tool"
        },

        "rt/mission/target_worker_id": {
          "entityType": "Mission",
          "entityId": "urn:ngsi-ld:Mission:ms-1",
          "attribute": "orderedByNameTag"
        },

        "rt/mission/status": {
          "entityType": "Mission",
          "entityId": "urn:ngsi-ld:Mission:ms-1",
          "attribute": "status"
        },

        "rt/uwb/worker1": {              // ◄ consumed by this module as uwb/worker1
          "entityType": "Worker",
          "entityId": "urn:ngsi-ld:Worker:EMP-1",
          "attribute": "mapPosition"
        },

        "rt/uwb/worker1_name_tag": {     // ◄ consumed by this module as uwb/worker1_name_tag
          "entityType": "Worker",
          "entityId": "urn:ngsi-ld:Worker:EMP-1",
          "attribute": "nameTag"
        },

        "rt/uwb/worker2": {              // ◄ consumed by this module as uwb/worker2
          "entityType": "Worker",
          "entityId": "urn:ngsi-ld:Worker:EMP-2",
          "attribute": "mapPosition"
        },

        "rt/uwb/worker2_name_tag": {     // ◄ consumed by this module as uwb/worker2_name_tag
          "entityType": "Worker",
          "entityId": "urn:ngsi-ld:Worker:EMP-2",
          "attribute": "nameTag"
        }

      }
    }
  }
}
```

The `Robot` and `Mission` topics (`rt/robot/uwb/robot_pose`, `rt/mission/*`, etc.) are used by
other KIRO modules (mission controller, localization) — not consumed here. Only the four `Worker`
topics marked with `◄` are inputs to this module.

**NGSI-LD Worker entity structure (for reference):**

```json
{
  "id": "urn:ngsi-ld:Worker:EMP-1",
  "type": "Worker",
  "mapPosition": { "type": "GeoProperty", "value": {"type": "Point", "coordinates": [x, y, z]} },
  "nameTag":     { "type": "Property", "value": "worker_name" },
  "@context": ["https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld"]
}
```

### ROS4HRI / ROS4RI — ✅ Upstream producer

This module is the upstream producer of the ROS4HRI person-position interface in KIRO. It publishes:

- **`/humans/persons/tracked`** (`hri_msgs/IdsList`) — list of active person IDs.
- **`/humans/persons/<id>/position`** (`hri_msgs/PointOfInterest3DStamped`) — one topic per tracked
  person, published dynamically as persons appear.

The `yolo_uwb_fusion_node` creates a new publisher for each new person ID on the fly and removes
persons from the tracked list after a detection timeout. Downstream consumers (e.g. `kiro_nav`'s
`hri_to_cohan_bridge`) subscribe dynamically using the `IdsList` to discover active person topics,
following the standard ROS4HRI convention without any custom integration.

| HRI concept | Module representation | ROS4HRI alignment | Evidence |
|---|---|---|---|
| Human presence | Per-person entry in `/humans/persons/tracked` + position topic | ✅ Standard ROS4HRI output (`hri_msgs/IdsList` + `hri_msgs/PointOfInterest3DStamped`) | `src/yolo_uwb_fusion_node.cpp` |
| Worker identity | Person ID string derived from UWB name tag (e.g. `worker_1`) | ✅ Identity resolved via UWB nearest-neighbour, exposed as the ROS4HRI person ID | `src/yolo_uwb_fusion_node.cpp` |
| Gesture or action | Not represented | N/A — visual pipeline detects persons only; no gesture recognition | — |
| Operator state | Not represented | N/A — no operator-monitoring component | — |
| Speech or intent | Not represented | N/A — no speech component | — |

---

## DDS configuration

| Mode | Transport | Flags |
|---|---|---|
| Simulation | `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` | `--network host`, no `--ipc host` |
| Real robot | `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` | `--network host`, no `--ipc host` |

The module always uses `RMW_IMPLEMENTATION=rmw_fastrtps_cpp` (Vulcanexus FastDDS).
`FASTDDS_BUILTIN_TRANSPORTS=UDPv4` is set in both modes to avoid FastDDS shared-memory transport
silently failing across mismatched IPC namespaces when sibling containers share a host.

All nodes use ROS 2 default QoS: `RELIABLE`/`VOLATILE`, depth 10. No custom QoS is configured.
