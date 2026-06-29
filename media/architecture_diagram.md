# human_detection_fusion — Architecture & data flow

## Component / data-flow diagram

How `human_detection_fusion` sits between the robot's sensors and a downstream consumer (e.g. `kiro_nav`).

```mermaid
flowchart LR
    cam["RGB Camera<br/>(compressed or raw)"] -->|"input_topic<br/>sensor_msgs/CompressedImage"| yolo
    lidar["Bpearl LiDAR<br/>(/bpearl_lidar/points)"] -->|"sensor_msgs/PointCloud2"| yolo

    subgraph yolo["ultralytics_ros · tracker_with_cloud"]
        detector["YOLO detector<br/>(class 0 — person)"] --> cloud["3-D cloud projection<br/>(camera + LiDAR fusion)"]
    end

    yolo -->|"/yolo_3d_result<br/>vision_msgs/Detection3DArray"| fusion
    yolo -->|"/yolo_result · /yolo_image<br/>/detection_marker"| viz["RViz2 (optional)"]

    uwb["UWB anchors<br/>(workers 1 … N)"] -->|"uwb/workerN<br/>geometry_msgs/Point"| fusion
    uwb -->|"uwb/workerN_name_tag<br/>std_msgs/String"| fusion

    tf["/tf · /tf_static<br/>(map → planning_frame)"] --> fusion

    subgraph fusion["yolo_uwb_fusion_node"]
        match["Distance matching<br/>(threshold: 1.0 m)"]
        yolo_only["YOLO-only → human_N"]
        uwb_fused["YOLO + UWB → worker_N"]
        uwb_only["UWB-only → worker_N<br/>(fallback when YOLO misses)"]
        match --> yolo_only
        match --> uwb_fused
        match --> uwb_only
    end

    fusion -->|"/humans/persons/tracked<br/>hri_msgs/IdsList"| out
    fusion -->|"/humans/persons/&lt;id&gt;/position<br/>hri_msgs/PointOfInterest3DStamped"| out

    out["Downstream consumer<br/>(e.g. kiro_nav · hri_to_cohan_bridge)"]
```

Key tuning knobs (hardcoded constants in the node):
- **SCORE_THRESHOLD** `0.8` — minimum YOLO detection confidence to consider.
- **FUSION_DISTANCE** `1.0 m` — max distance between a YOLO bbox centre and a UWB position to call them the same person.

---

## Sequence — one detection cycle

```mermaid
sequenceDiagram
    participant CAM as Camera / LiDAR
    participant YOL as ultralytics_ros<br/>(tracker_with_cloud)
    participant UWB as UWB anchors<br/>(workers 1…N)
    participant FUS as yolo_uwb_fusion_node
    participant DN  as Downstream<br/>(kiro_nav / bridge)

    CAM-->>YOL: image + point cloud (continuous)
    YOL-->>FUS: /yolo_3d_result  (Detection3DArray, each cycle)
    UWB-->>FUS: uwb/workerN  (geometry_msgs/Point, async)

    loop on every /yolo_3d_result message
        FUS->>FUS: transform detections → planning_frame (TF)
        FUS->>FUS: for each detection (score ≥ 0.8, class = person)
        FUS->>FUS:   try UWB distance-match → worker_N
        FUS->>FUS:   else → human_N (unknown)
        FUS->>FUS: for each UWB worker not matched → worker_N (UWB-only)
        FUS-->>DN: /humans/persons/tracked  (IdsList)
        FUS-->>DN: /humans/persons/<id>/position  (PointOfInterest3DStamped)
    end
```
