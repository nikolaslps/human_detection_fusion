FROM eprosima/vulcanexus:humble-desktop

WORKDIR /home
ENV EDITOR=nano
ENV XDG_RUNTIME_DIR=/tmp
ENV SHELL=/bin/bash
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

RUN find /etc/apt/sources.list.d/ -name "*.list" -exec grep -l "vulcanexus" {} \; | xargs -r rm -f && \
    find /etc/apt/sources.list.d/ -name "*.sources" -exec grep -l "vulcanexus" {} \; | xargs -r rm -f && \
    sed -i '/vulcanexus/d' /etc/apt/sources.list 2>/dev/null || true

RUN apt-get update && apt-get install -y \
    wget git git-lfs bash-completion build-essential sudo nano \
    python3-vcstool python3-rosdep python3-colcon-common-extensions python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    ros-humble-cv-bridge \
    ros-humble-vision-msgs \
    ros-humble-pcl-ros \
    ros-humble-pcl-conversions \
    ros-humble-rmw-fastrtps-cpp \
    ros-humble-tf2-geometry-msgs \
    ros-humble-image-transport \
    ros-humble-compressed-image-transport \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install \
    "lap==0.4.0" \
    "onnx==1.14.0" \
    "urllib3==1.26.18" \
    "numpy==1.23.4" \
    "opencv-python==4.7.0.72" \
    ultralytics

RUN rosdep init || true && rosdep update

RUN mkdir -p /home/human_detect_ws/src
WORKDIR /home/human_detect_ws/src

RUN git clone -b add-points-of-interest-3d https://github.com/andvatistas/hri_msgs.git

# Pinned to the commit used in development (nikolaslps fork adds CompressedImage support)
RUN git clone https://github.com/nikolaslps/ultralytics_ros.git && \
    cd ultralytics_ros && git checkout 2387b75dfb192bd912cd00731dc940238f508b71

# # Fix tracker_with_cloud_node:
# #   1. Sync queue 5→30: at 10Hz LiDAR vs 30Hz camera, queue=5 drops most syncs
# #   2. Marker lifetime = 2× callback interval (was 1×): prevents flicker when a
# #      callback is slightly late
# RUN sed -i \
#     -e 's/Synchronizer<ApproximateSyncPolicy>>(5)/Synchronizer<ApproximateSyncPolicy>>(30)/' \
#     -e 's/duration<double>(duration))/duration<double>(std::max(duration * 2.0, 0.2)))/' \
#     /home/human_detect_ws/src/ultralytics_ros/src/tracker_with_cloud_node.cpp

COPY src/ /home/human_detect_ws/src/human_detection_fusion/src/
COPY include/ /home/human_detect_ws/src/human_detection_fusion/include/
COPY CMakeLists.txt /home/human_detect_ws/src/human_detection_fusion/CMakeLists.txt
COPY package.xml /home/human_detect_ws/src/human_detection_fusion/package.xml

WORKDIR /home/human_detect_ws
RUN . /opt/vulcanexus/humble/setup.bash && \
    rosdep install --from-paths src --ignore-src -r -y || true

# Build hri_msgs first so its generated headers are installed before the
# C++ packages that depend on them (colcon's same-workspace rosidl header
# generation requires a sourced install to be visible to downstream builds).
RUN . /opt/vulcanexus/humble/setup.bash && \
    colcon build --packages-select hri_msgs --cmake-args -DCMAKE_BUILD_TYPE=Release && \
    echo "hri_msgs build complete"

RUN . /opt/vulcanexus/humble/setup.bash && \
    . /home/human_detect_ws/install/setup.bash && \
    colcon build --packages-skip hri_msgs --cmake-args -DCMAKE_BUILD_TYPE=Release && \
    echo "Build complete"

RUN echo "source /opt/vulcanexus/humble/setup.bash" >> /root/.bashrc && \
    echo "source /home/human_detect_ws/install/setup.bash" >> /root/.bashrc

RUN mkdir -p /config /launch /rviz

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
