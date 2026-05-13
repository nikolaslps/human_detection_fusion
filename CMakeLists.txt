cmake_minimum_required(VERSION 3.8)
project(human_detection_fusion)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(tf2 REQUIRED)
find_package(tf2_ros REQUIRED)
find_package(tf2_geometry_msgs REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(vision_msgs REQUIRED)
find_package(cohan_msgs REQUIRED)
find_package(ultralytics_ros REQUIRED)
find_package(std_msgs REQUIRED)

include_directories(include/${PROJECT_NAME})

add_executable(cohan_msg_bridge_node 
  src/cohan_msg_bridge.cpp
)

ament_target_dependencies(cohan_msg_bridge_node
  rclcpp
  tf2
  tf2_ros
  tf2_geometry_msgs
  vision_msgs
  cohan_msgs
  ultralytics_ros
  std_msgs
)

install(TARGETS 
  cohan_msg_bridge_node
  DESTINATION lib/${PROJECT_NAME})

# install public headers
install(DIRECTORY include/
  DESTINATION include/
)

# install launch files
install(DIRECTORY launch
  DESTINATION share/${PROJECT_NAME}/
)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  # the following line skips the linter which checks for copyrights
  # comment the line when a copyright and license is added to all source files
  set(ament_cmake_copyright_FOUND TRUE)
  # the following line skips cpplint (only works in a git repo)
  # comment the line when this package is in a git repo and when
  # a copyright and license is added to all source files
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
