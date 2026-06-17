#!/bin/bash
# docker build -t kiro_human_detect_vulcanexus .

xhost +local:docker

docker run -it \
    --rm \
    --name human_detection \
    --network host \
    --ipc host \
    --pid host \
    --env DISPLAY=$DISPLAY \
    --env QT_X11_NO_MITSHM=1 \
    --env DEBIAN_FRONTEND=noninteractive \
    --env RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    --volume /tmp/.X11-unix:/tmp/.X11-unix:rw \
    --volume "$(pwd)/human_detect_ws:/root/human_detect_ws:rw" \
    --shm-size=512m \
    kiro_human_detect_vulcanexus
 
# If using NVIDIA GPU. add the following flags
    # --gpus all \
    # --env NVIDIA_VISIBLE_DEVICES=all \
    # --env NVIDIA_DRIVER_CAPABILITIES=all \

# If want to use Discovery Server, add the following flags
    # --env ROS_DISCOVERY_SERVER=10.0.17.100:11811 \

# If want to specify Domain ID, add the following flag
    # --env ROS_DOMAIN_ID=25 \