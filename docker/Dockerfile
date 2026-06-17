FROM eprosima/vulcanexus:humble-desktop

ENV DEBIAN_FRONTEND=noninteractive
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp

RUN apt-get update && apt-get install -y \
	wget \
 	git \
    git-lfs \
 	bash-completion \
 	build-essential \
 	sudo \
 	nano \
 	&& rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
	python3-vcstool \
	python3-rosdep \
	python3-colcon-common-extensions \
    python3-pip \
	&& rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install \
    lap==0.4.0 \
    onnx==1.14.0 \
    urllib3==1.26.18 \
    numpy==1.23.4 \
    opencv-python==4.7.0.72 \
    ultralytics

RUN apt-get update && apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
    python3-pip \
    ros-humble-cv-bridge \
    ros-humble-vision-msgs \
    ros-humble-image-view \
    ros-humble-pcl-* \
    ros-humble-rmw-fastrtps-cpp \
    && apt-get clean && \
    rm -r /var/lib/apt/lists/*

WORKDIR /root/human_detect_ws

RUN echo "source /opt/vulcanexus/humble/setup.bash" >> ~/.bashrc
RUN echo "if [ -f /root/human_detect_ws/install/setup.bash ]; then source /root/human_detect_ws/install/setup.bash; fi" >> ~/.bashrc

# Default entrypoint
CMD ["/bin/bash"]