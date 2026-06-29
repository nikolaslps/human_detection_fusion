import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription, TimerAction, DeclareLaunchArgument
from launch.launch_description_sources import AnyLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

def generate_launch_description():
    ultralytics_launch_dir = get_package_share_directory('ultralytics_ros')
    
    use_sim_time_arg = DeclareLaunchArgument(
        'use_sim_time',
        default_value='false',
        description='Use simulation (Gazebo) clock if true'
    )
    
    debug_arg = DeclareLaunchArgument(
        'debug',
        default_value='false',
        description='Enable debug mode'
    )

    planning_frame_arg = DeclareLaunchArgument(
        'planning_frame',
        default_value='kiro_base_link',
        description='The planning reference frame for fusion'
    )

    yolo_tracker = IncludeLaunchDescription(
        AnyLaunchDescriptionSource(
            os.path.join(ultralytics_launch_dir, 'launch', 'tracker_with_cloud.launch.xml')
        ),
        launch_arguments={
            'use_sim_time': LaunchConfiguration('use_sim_time'),
            'debug': LaunchConfiguration('debug'),
            'input_topic': '/camera/camera/color/image_raw/compressed',
            'camera_info_topic': '/camera/camera/color/camera_info',
            'lidar_topic': '/bpearl_lidar/points',
            'min_cluster_size': '10',
            'classes': '0',
        }.items()
    )

    bridge_node = Node(
        package='human_detection_fusion',
        executable='yolo_uwb_fusion_node',
        name='yolo_uwb_fusion_node',
        output='screen',
        parameters=[{'use_sim_time': LaunchConfiguration('use_sim_time'), 'planning_frame': LaunchConfiguration('planning_frame')}]
    )

    # Start the msgBridge after YOLO starts
    delayed_bridge_node = TimerAction(
        period=20.0,
        actions=[bridge_node]
    )

    return LaunchDescription([
        use_sim_time_arg,
        debug_arg,
        planning_frame_arg,
        yolo_tracker,
        delayed_bridge_node
    ])
