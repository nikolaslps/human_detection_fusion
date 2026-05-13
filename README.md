# ARISE KIRO -- Human Detection Fusion Node

![Vulcanexus](https://img.shields.io/badge/Vulcanexus-Humble-00214c?style=for-the-badge&logo=ros)
![License](https://img.shields.io/badge/License-AGPL%20v3.0-orange?style=for-the-badge&logo=gnu&logoColor=white)
![Build Status](https://img.shields.io/badge/build-passing-brightgreen?style=for-the-badge&logo=github-actions&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)

## Table of Contents

- [Overview](#overview)
- [File Structure](#file-structure)
- [Launch Arguments](#launch-arguments)
- [Installation](#installation)
- [Usage](#usage)
- [Supported Distribution](#supported-distribution)
- [License](#license)


## Overview

This package is designed for real-time human detection. It leverages the `ultralytics_ros` wrapper to run **YOLO**-based inference and fuses 2D image data with 3D LiDAR point clouds. 

Our contribution introduces native support for `CompressedImage` streams, allowing the node to check the type of the input image topic and handle it correctly.

This detection pipeline serves as a critical component for the KIRO Robot. By specifically tracking humans and feeding their coordinates into a **Social Planner**, the robot can navigate safely through crowded areas, respecting personal space and social norms. 

The fusion is triggered by a YOLO detection and follows a **Nearest Neighbor** association strategy. All data is transformed into a global or robot-centric frame (e.g., `kiro_base_link`). This ensures that a visual coordinate $(x,y)$ and a UWB coordinate $(x,y)$ represent the same physical location.

For every visual detection, the node iterates through all active UWB workers:
1. Calculate Euclidean distance: $d = \sqrt{(x_{v} - x_{u})^2 + (y_{v} - y_{u})^2}$
2. Compare against `FUSION_DISTANCE` (threshold).
3. **If Match found:** Assign the UWB Identity (e.g., "Worker 1") to the high-precision Visual bounding box.
4. **If No Match:** Label as a generic human (e.g., "human_1").

Any UWB workers **not** associated with a visual detection are still published. This ensures the robot knows a person is present even if they are:
* Behind the robot.
* Obscured by an obstacle.
* In low-light conditions where YOLO fails.


## File Structure
```text
human_detection_fusion/
├── include/
│   └── human_detection_fusion/
│           ├── cohan_msg_bridge.hpp 
│           └── fusion_utils.hpp
├── launch/
│   └── msgBridge.launch.py             # Main system launch file
├── src/
│   └── cohan_msg_bridge.cpp            # Main fusion logic
├── CMakeLists.txt                      # Build configuration
├── package.xml                         # Package metadata and dependencies
├── README.md                           # Documentation
└── LICENSE                             # License information
```

## Launch Arguments
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


## Installation

### 1. Docker Container (Recommended)
For the most stable experience, we recommend using our pre-configured Docker environment.
* Refer to the [ARISE KIRO Docker Repository](https://github.com/andvatistas/ARISE-KIRO-reusable-modules) for setup assistance.
* Follow the provided `README.md` within that repository to pull the image and launch the container.

### 2. Building from Source
**Note**: Building from source has not been fully tested in all environments. We strongly recommend using the Docker version above.

#### Prerequisites
Ensure you are running **ROS 2 Humble**, preferably on the **Vulcanexus** image.

#### Setup Workspace
Clone the repositories into your ROS 2 workspace `src` folder:

```bash
cd ~/ros2_ws/src
```

```bash
# CoHAN Planner (need this for cohan_msgs package)
git clone -b v2 https://github.com/sphanit/CoHAN-Nav2.git
```

```bash
# Ultralytics ROS Node
GIT_LFS_SKIP_SMUDGE=1 git clone -b feature-rotated-image https://github.com/nikolaslps/ultralytics_ros.git
```

```bash
# Humand Detection Fusion Node
git clone https://github.com/nikolaslps/human_detection_fusion.git
```

Install Dependencies
```bash
cd ~/ros2_ws
sudo rosdep init # May not be necessary
rosdep update
apt-get update
rosdep install --from-paths src --ignore-src -y -r --rosdistro humble
```

Download the python requirements for the `ultralytics_ros` package
```bash
cd ~/ros2_ws/src/ultralytics_ros/
pip install -r requirements.txt
```

Build the packages by running the following from inside the `ros2_ws`:
```bash
cd ~/ros2_ws
colcon build --symlink-install --packages-select ultralytics_ros cohan_msgs human_detection_fusion
source install/setup.bash
```

## Usage 

Launch the detection nodes by running:
```bash
ros2 launch human_detection_fusion msgBridge.launch.py
```

## Supported Distribution
* **ROS 2 Humble on Vulcanexus image**

## License
This project is licensed under the **GNU Affero General Public License v3.0**. See the [LICENSE](LICENSE) file for details.


