# ARISE KIRO -- Human Detection Fusion Node

![Vulcanexus](https://img.shields.io/badge/Vulcanexus-Humble-00214c?style=for-the-badge&logo=ros)
![License](https://img.shields.io/badge/License-AGPL%20v3.0-orange?style=for-the-badge&logo=gnu&logoColor=white)
![Build Status](https://img.shields.io/badge/build-manual-lightgrey?style=for-the-badge&logo=github-actions&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)

## Table of Contents

- [Overview](#overview)
- [Supported Setup](#supported-setup)
- [File Structure](#file-structure)
- [Contact Information](#contact-information)
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

## Supported Setup

| Category | Tested On | Expected Compatibility | Not Supported / Unknown |
| :--- | :--- | :--- | :--- |
| **Middleware & OS** | **Vulcanexus Humble** (Ubuntu 22.04 LTS) utilizing **Fast DDS** as the default RMW middleware layer | Standard ROS 2 Humble setups | Older ROS distributions (e.g., Foxy, Galactic) or ROS 1 |
| **Sensors** | **Intel RealSense D455** & **Bpearl 3D Lidar** | Any RGB-D sensor or Lidar providing standardized PointCloud2 data streams | Monocular 2D webcams (lacking spatial depth parameters) |

## File Structure

```text
human_detection_fusion/
├── docker/
│   ├── Docker-Install.md               # Docker Installation and Launch Manual
│   ├── Dockerfile                      # Dockerfile based on Vulcanexus image
│   ├── run_kiro_hri_exec.bash          # Script to launch the Docker Container
│   └── setup_hri_exec.sh               # Script to build the Docker Container
├── docs/
│   ├── 01_arise_context.md             # ARISE Ecosystem Context & Core Integration
│   ├── 02_interfaces.md                # Interface Documentation
│   ├── 03_installation.md              # Installation and Usage Guide
│   ├── 04_launch_ros_nodes.md          # ROS2 Launch Arguments
│   └── 05_role_in_demonstrator.md      # Role in the TRL 6-7 Demonstrator
├── include/
│   └── human_detection_fusion/
│           ├── cohan_msg_bridge.hpp 
│           └── fusion_utils.hpp
├── launch/
│   └── msgBridge.launch.py             # Main system launch file
├── media/                              # Images 
├── src/
│   └── cohan_msg_bridge.cpp            # Main fusion logic
├── .gitignore
├── CMakeLists.txt                      # Build configuration
├── LICENSE                             # License information
├── package.xml                         # Package metadata and dependencies
└── README.md                           # Overview of the ARISE KIRO specific package
```

## Contact Information

For queries regarding the development, replication, or integration of this calculation module within the ARISE framework, feel free to reach out:

* **Module Developer:** Nikolaos Lappas
* **GitHub:** [nikolaslps](https://github.com/nikolaslps)
* **Email:** [nikolas.lappas.2003@gmail.com](mailto:nikolas.lappas.2003@gmail.com)

## License
This project is licensed under the **GNU Affero General Public License v3.0**. See the [LICENSE](LICENSE) file for details.


