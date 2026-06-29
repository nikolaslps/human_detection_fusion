#pragma once

#include <rclcpp/rclcpp.hpp>
#include "rclcpp/parameter_client.hpp"
#include <vision_msgs/msg/detection3_d_array.hpp>
#include <geometry_msgs/msg/point.hpp>
#include <geometry_msgs/msg/point_stamped.hpp>
#include <std_msgs/msg/string.hpp>
#include <hri_msgs/msg/ids_list.hpp>
#include <hri_msgs/msg/point_of_interest3_d_stamped.hpp>

#include <tf2_ros/transform_listener.h>
#include <tf2_ros/buffer.h>
#include <tf2/time.h>
#include <tf2_geometry_msgs/tf2_geometry_msgs.hpp>

#include <string>
#include <map>
#include <vector>

#include "fusion_utils.hpp"

namespace YoloUWBFusion
{

class YoloUWBFusionNode : public rclcpp::Node
{
public:
    YoloUWBFusionNode();

private:
    void topic_callback(const vision_msgs::msg::Detection3DArray::SharedPtr msg);
    void uwb_pos_callback(const geometry_msgs::msg::Point::SharedPtr msg, int id);
    void uwb_name_callback(const std_msgs::msg::String::SharedPtr msg, int id);

    void setup_uwb_subscribers();
    void update_tracker_classes();
    geometry_msgs::msg::Point transformUWBPosition(const geometry_msgs::msg::Point& pt);
    rclcpp::Publisher<hri_msgs::msg::PointOfInterest3DStamped>::SharedPtr
        get_or_create_position_pub(const std::string& person_id);

    std::shared_ptr<tf2_ros::Buffer> tf_buffer_;
    std::shared_ptr<tf2_ros::TransformListener> tf_listener_;
    std::shared_ptr<rclcpp::AsyncParametersClient> tracker_param_client_;

    rclcpp::Subscription<vision_msgs::msg::Detection3DArray>::SharedPtr subscription_;
    rclcpp::Publisher<hri_msgs::msg::IdsList>::SharedPtr tracked_pub_;
    std::map<std::string, rclcpp::Publisher<hri_msgs::msg::PointOfInterest3DStamped>::SharedPtr> position_pubs_;

    std::vector<rclcpp::Subscription<geometry_msgs::msg::Point>::SharedPtr> uwb_pos_subs_;
    std::vector<rclcpp::Subscription<std_msgs::msg::String>::SharedPtr> uwb_name_subs_;

    std::map<int, UWBWorker> uwb_registry_;

    static constexpr double SCORE_THRESHOLD = 0.8;
    static constexpr double FUSION_DISTANCE = 1.0;
    std::string TARGET_FRAME;
    std::string UWB_FRAME;
};

}  // namespace YoloUWBFusion
