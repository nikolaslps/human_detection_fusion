# Docker Installation and Launch

This is the recommended way of installing and running the `human_detection_fusion` package. 

The container deployment environment automatically clones and uses the upstream open-source perception tracking stack required for raw vision inference:

> [!NOTE]
> **Upstream Software Attribution**
> ```yaml
> cff-version: 1.2.0
> message: "If you use this software, please cite it as below."
> authors:
>   - family-names: "Mori"
>     given-names: "Kimihiro"
> title: "ultralytics_ros"
> date-released: 2023-05-28
> license: "AGPL-3.0"
> url: "[https://github.com/Alpaca-zip/ultralytics_ros](https://github.com/Alpaca-zip/ultralytics_ros)"
> ```

## Build the Docker Container
Build the docker image by running the executable from the repository root .
```bash
chmod +x ./docker/setup_human_detect.sh # if not executable already
```
```
./docker/setup_human_detect.sh
```

If the installation finishes correctly, you will be greeted with a success message:

> [!NOTE]
> **Expected Build Output:**
> ```text
> ==================================================
> SUCCESS: Selected packages built inside container.
> To run: ./docker/run_human_detect.bash
> ==================================================
> ```

## Start the Docker Container
Run the executable.
```bash
chmod +x ./docker/run_human_detect.bash # if not executable already
```
```
./docker/run_human_detect.bash
```

> [!NOTE]
> **Expected Terminal Transition:**
> ```text
> non-network local connections being added to access control list
> root@container-environment:~/human_detect_ws#
> ```

## From inside the container
1. Source the workspace
```bash
source install/setup.bash
```

2. Run the launch file
```bash
ros2 launch human_detection_fusion msgBridge.launch.py
```

### Verify the Log Output

Verify a successful startup by checking that your terminal logs reflect the following sequence:

```text
[INFO] [launch]: All log files can be found below /root/.ros/log/2026-06-25-14-47-26-466523-Nitro-ANV16-61-1733727
[INFO] [launch]: Default logging verbosity is set to INFO
[INFO] [tracker_node.py-1]: process started with pid [1733728]
[INFO] [tracker_with_cloud_node-2]: process started with pid [1733730]
[tracker_node.py-1] YOLOv8m-seg summary (fused): 105 layers, 27,268,704 parameters, 0 gradients, 104.5 GFLOPs
[INFO] [cohan_msg_bridge_node-3]: process started with pid [1734925]
[cohan_msg_bridge_node-3] [INFO] [1782398866.720360208] [cohan_msg_bridge]: Bridge Node with UWB Fusion Started.
[cohan_msg_bridge_node-3] [INFO] [1782398866.720702498] [cohan_msg_bridge]: Successfully changed classes to 0
```

> [!IMPORTANT]
> **Permissive Execution:** Prior to launching, verify that the underlying Python tracking script inside the upstream perception block has executable file permissions. If the node fails to boot, run the following system command:
> ```bash
> chmod +x src/ultralytics_ros/script/tracker_node.py
> ```

> [!NOTE]
> **Selective Workspace Build Execution**
> If a compilation step is required for the workspace, execute the following command to exclusively compile the relevant perception blocks, avoiding time-consuming builds of unrelated ecosystem packages:
> 
> ```bash
> colcon build --symlink-install --packages-select ultralytics_ros cohan_msgs human_detection_fusion
> source install/setup.bash
> ```

> [!TIP]
> **Point Cloud Voxel Density Alignment**
> If data streams fail to publish over the downstream topic array (`/detection_cloud` or `/yolo_3d_result`), audit the spatial clustering parameters inside the layout profile (`tracker_with_cloud.launch.xml`).
> 
> Ensure the cluster filtering size parameter matches your active lidar/camera return constraints:
> * **Parameter Target:** `min_cluster_size`
> * **Recommended Operational Value:** `10`

> [!NOTE]
> **Runtime Parameter Introspection**
> Before initializing the runtime execution loop, explicitly verify the environment parameter files mapped inside the entry launch configuration (`msgBridge.launch.py`). For a full deep-dive into configurable parameters and launch options, see the [Launch ROS Nodes Documentation](../docs/04_launch_ros_nodes.md).

