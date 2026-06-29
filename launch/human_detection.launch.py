"""
human_detection.launch.py
--------------------------
Launches the full KIRO human-detection stack inside the container:

  1. ultralytics_ros tracker_with_cloud
       YOLO object detection + Bpearl point-cloud 3D projection
       → /yolo_result          (Detection2DArray + tracked IDs)
       → /yolo_image           (annotated debug image)
       → /yolo_3d_result       (vision_msgs/Detection3DArray, input to fusion)
       → /detection_marker     (visualization_msgs/MarkerArray, 3-D bounding boxes)

  2. yolo_uwb_fusion_node  (delayed 20 s to let YOLO load its model first)
       fuses /yolo_3d_result with UWB worker positions
       → /humans/persons/tracked           (hri_msgs/IdsList)
       → /humans/persons/<id>/position     (hri_msgs/PointOfInterest3DStamped)

  3. rviz2 (optional, enable via rviz:=true)
       Fixed frame: base_link | displays: Bpearl PointCloud2, detection_marker, /yolo_image

Volume-mounted from the host at /launch/ — edit and restart without rebuilding the image.
"""
import os
from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, TimerAction, IncludeLaunchDescription
from launch.substitutions import LaunchConfiguration
from launch.conditions import IfCondition
from launch.launch_description_sources import AnyLaunchDescriptionSource
from launch_ros.actions import Node


def generate_launch_description():
    ultralytics_launch_dir = get_package_share_directory('ultralytics_ros')

    # ── Launch arguments ────────────────────────────────────────────────────
    params_file_arg    = DeclareLaunchArgument(
        'params_file',    default_value='/config/detection_params.yaml')
    use_sim_time_arg   = DeclareLaunchArgument(
        'use_sim_time',   default_value='false')
    input_topic_arg    = DeclareLaunchArgument(
        'input_topic',    default_value='/camera/camera/color/image_raw/compressed',
        description='Camera image topic. Real: /compressed variant. Sim: /image_raw.')
    planning_frame_arg = DeclareLaunchArgument(
        'planning_frame', default_value='kiro_base_link',
        description='TF frame for publishing fused human positions. Sim: base_link.')
    rviz_arg           = DeclareLaunchArgument(
        'rviz',           default_value='false',
        description='Launch RViz2 with Bpearl + detection_marker + YOLO image displays.')

    params_file    = LaunchConfiguration('params_file')
    use_sim_time   = LaunchConfiguration('use_sim_time')
    input_topic    = LaunchConfiguration('input_topic')
    planning_frame = LaunchConfiguration('planning_frame')
    rviz           = LaunchConfiguration('rviz')

    # ── YOLO tracker + 3-D cloud fusion (ultralytics_ros) ──────────────────
    yolo_tracker = IncludeLaunchDescription(
        AnyLaunchDescriptionSource(
            os.path.join(ultralytics_launch_dir, 'launch', 'tracker_with_cloud.launch.xml')
        ),
        launch_arguments={
            'use_sim_time':       use_sim_time,
            'input_topic':        input_topic,
            'camera_info_topic':  '/camera/camera/color/camera_info',
            'lidar_topic':        '/bpearl_lidar/points',
            'result_image_topic': '/yolo_image',
            'conf_thres':         '0.75',
            'min_cluster_size':   '10',
            'classes':            '0',
        }.items()
    )

    # ── YOLO + UWB fusion node (delayed to let YOLO model load first) ───────
    fusion_node = Node(
        package='human_detection_fusion',
        executable='yolo_uwb_fusion_node',
        name='yolo_uwb_fusion_node',
        output='screen',
        parameters=[
            params_file,
            {'use_sim_time': use_sim_time, 'planning_frame': planning_frame},
        ]
    )

    delayed_fusion = TimerAction(period=8.0, actions=[fusion_node])

    # ── RViz2 (optional) ────────────────────────────────────────────────────
    rviz_node = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        arguments=['-d', '/rviz/human_detection.rviz'],
        parameters=[{'use_sim_time': use_sim_time}],
        condition=IfCondition(rviz),
        output='screen'
    )

    return LaunchDescription([
        params_file_arg,
        use_sim_time_arg,
        input_topic_arg,
        planning_frame_arg,
        rviz_arg,
        yolo_tracker,
        delayed_fusion,
        rviz_node,
    ])
