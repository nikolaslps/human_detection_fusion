#!/bin/bash

CONTAINER_NAME="kiro_human_detect_vulcanexus"
WS_NAME="human_detect_ws"
SRC_NAME="src"

echo -e "\e[36m=====================================================\e[0m"
echo -e "\e[36m      KIRO HUMAN DETECTION: Master Setup System      \e[0m"
echo -e "\e[36m=====================================================\e[0m"

REPO_ROOT="$(pwd)"
if [ ! -f "package.xml" ] || [ ! -d "docker" ]; then
    echo -e "\e[31mError: Please run this script from the repository root directory!\e[0m"
    echo -e "e.g., ./docker/setup_human_detect.sh"
    exit 1
fi

echo -e "\e[33m[1/3] Creating local shared workspace '$WS_NAME'...\e[0m"
mkdir -p "$WS_NAME/$SRC_NAME"

echo -e "\e[33m[2/4] Copying local package to workspace...\e[0m"
if [ -d "$WS_NAME/$SRC_NAME/human_detection_fusion" ]; then
    echo -e "\e[32m  -> Local package already copied. Refreshing source...\e[0m"
    rm -rf "$WS_NAME/$SRC_NAME/human_detection_fusion"
fi
mkdir -p "$WS_NAME/$SRC_NAME/human_detection_fusion"
rsync -av . "$WS_NAME/$SRC_NAME/human_detection_fusion" --exclude="$WS_NAME" --exclude=".git" > /dev/null

echo -e "\e[33m[2/3] Cloning repositories to host ...\e[0m"
cd "$WS_NAME/$SRC_NAME"

if [ ! -d "ultralytics_ros" ]; then
    echo -e "\e[33m  -> Cloning ultralytics_ros (feature-compressed-image)...\e[0m"
    GIT_LFS_SKIP_SMUDGE=1 git clone -b feature-compressed-image https://github.com/nikolaslps/ultralytics_ros.git
fi

if [ ! -d "CoHAN-Nav2" ]; then
    echo -e "\e[33m  -> Cloning CoHAN-Nav2 (v2)...\e[0m"
    git clone -b v2 https://github.com/sphanit/CoHAN-Nav2.git # Need this for cohan_msgs
fi

cd "$REPO_ROOT"

# Build the Docker Image
echo -e "\e[33m[3/3] Building the Docker image '$CONTAINER_NAME'...\e[0m"
if [ -f "docker/Dockerfile" ]; then
    docker build -t "$CONTAINER_NAME" -f docker/Dockerfile docker/
else
    echo -e "\e[31mError: Dockerfile not found in docker/ directory!\e[0m"
    exit 1
fi

echo -e "\e[33m[4/4] Building ROS 2 Workspace inside the container...\e[0m"

docker run --rm \
    --volume "$(pwd)/$WS_NAME:/root/$WS_NAME:rw" \
    $CONTAINER_NAME \
    bash -c "source /opt/vulcanexus/humble/setup.bash && \
            cd /root/$WS_NAME && \
            colcon build --symlink-install --packages-select ultralytics_ros cohan_msgs human_detection_fusion 
            source install/setup.bash"

echo -e "\e[36m==================================================\e[0m"
echo -e "\e[32mSUCCESS: Selected packages built inside container.\e[0m"
echo -e "\e[36mTo run: ./docker/run_human_detect.bash\e[0m"
echo -e "\e[36m==================================================\e[0m"