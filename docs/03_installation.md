# Installation and Usage Guide

This guide covers setting up the `human_detection_fusion` pipeline. You can either deploy using the recommended docker container layout included directly in this repository or build natively from source.

---

## Installation

### 1. Pre-configured Docker Container (Recommended)
For a stable development experience with all system and Python dependencies pre-installed, use the native Docker environment files located inside the `/docker` directory of this repository.

* Refer to the internal [Docker Installation](../docker/Docker-Install.md) for full installation setup steps.


### 2. Building from Source

> [!WARNING]
> Native compilation on the host machine has not been fully verified across all hardware profiles (only tested on Ubuntu 22.04 and partially on Ubuntu 24.04). Using the integrated Docker automation above is highly recommended to prevent dependency drift or configuration conflicts.

> [!IMPORTANT]
> **Prerequisites:** Ensure your system is running **ROS 2 Humble**, preferably deployed on a [Vulcanexus Humble](https://docs.vulcanexus.org/en/latest/) base image.

#### Setup Workspace
Create a standard development workspace and an underlying source directory:

```bash
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src
```

> [!IMPORTANT]
> **Repository Placement:** Before proceeding, you must manually copy some files from this repository straight into your new source space.
> 
> Your directory layout **must** look exactly like this for the build system to work:
> ```text
> ~/ros2_ws/src/human_detection_fusion/
> ├── include/
> │   └── human_detection_fusion/
> │           ├── cohan_msg_bridge.hpp 
> │           └── fusion_utils.hpp
> ├── launch/
> │   └── msgBridge.launch.py
> ├── src/
> │   └── cohan_msg_bridge.cpp            
> ├── CMakeLists.txt
> └── package.xml
> ```

Clone the remaining mandatory external packages into that same `~/ros2_ws/src` folder:

```bash
# CoHAN Planner (need this for cohan_msgs package)
git clone -b v2 https://github.com/sphanit/CoHAN-Nav2.git
```

```bash
# Ultralytics ROS Node
GIT_LFS_SKIP_SMUDGE=1 git clone -b feature-rotated-image https://github.com/nikolaslps/ultralytics_ros.git
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