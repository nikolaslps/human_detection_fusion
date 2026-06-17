## ROS2 Launch Arguments

The `human_detection_fusion` execution behavior is parameterized via launch arguments. These configuration blocks are classified by spatial framing context and tracking pipeline sensors:

### 1. Coordinate Frames
These parameters define the spatial context of the handover.

| Argument | Default Value | Description |
| :--- | :--- | :--- |
| `planning_frame` | `kiro_base_link` | The planning reference frame for fusion. |
| `use_sim_time` | `false` | Use simulation (Gazebo) clock if true. |
| `debug` | `false` | Enable debug mode. |

### 2. YOLO Detection Module
Responsible for human tracking.

| Argument | Default Value | Description |
| :--- | :--- | :--- |
| `input_topic` | `/camera/camera/color/image_raw/compressed` | Camera input topic for human tracking. |
| `camera_info_topic` | `/camera/camera/color/camera_info` | Camera info. |
| `lidar_topic` | `/bpearl_lidar/points` | 3D Lidar input topic for human tracking. |