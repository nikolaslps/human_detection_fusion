#pragma once

#include <rclcpp/rclcpp.hpp>
#include "rclcpp/parameter_client.hpp"
#include <vision_msgs/msg/detection3_d_array.hpp>
#include <geometry_msgs/msg/point.hpp>
#include <std_msgs/msg/string.hpp>
#include <cohan_msgs/msg/tracked_agents.hpp>
#include <cohan_msgs/msg/tracked_segment.hpp>
#include <cohan_msgs/msg/tracked_segment_type.hpp>

#include <tf2_ros/transform_listener.h>
#include <tf2_ros/buffer.h>
#include <tf2_geometry_msgs/tf2_geometry_msgs.hpp>

#include <string>
#include <map>
#include <vector>

#include "fusion_utils.hpp"

namespace CoHANmsgBridge
{

class CoHANmsgBridge : public rclcpp::Node 
{
public:
    CoHANmsgBridge();

private:
    // Callbacks
    void topic_callback(const vision_msgs::msg::Detection3DArray::SharedPtr msg);
    void uwb_pos_callback(const geometry_msgs::msg::Point::SharedPtr msg, int id);
    void uwb_name_callback(const std_msgs::msg::String::SharedPtr msg, int id);

    // Helpers
    void setup_uwb_subscribers();
    cohan_msgs::msg::TrackedAgent create_agent(const geometry_msgs::msg::Pose& pose, uint64_t id, const std::string& name);

    // ROS Members
    std::shared_ptr<tf2_ros::Buffer> tf_buffer_;
    std::shared_ptr<tf2_ros::TransformListener> tf_listener_;

    std::shared_ptr<rclcpp::AsyncParametersClient> tracker_param_client_;
    void update_tracker_classes();
    
    rclcpp::Subscription<vision_msgs::msg::Detection3DArray>::SharedPtr subscription_;
    rclcpp::Publisher<cohan_msgs::msg::TrackedAgents>::SharedPtr publisher_;
    
    std::vector<rclcpp::Subscription<geometry_msgs::msg::Point>::SharedPtr> uwb_pos_subs_;
    std::vector<rclcpp::Subscription<std_msgs::msg::String>::SharedPtr> uwb_name_subs_;

    // Data Registry
    std::map<int, UWBWorker> uwb_registry_;

    // Constants
    static constexpr double SCORE_THRESHOLD = 0.8;
    static constexpr double FUSION_DISTANCE = 1.0; 
    std::string TARGET_FRAME;
};

}  // namespace CoHANmsgBridge