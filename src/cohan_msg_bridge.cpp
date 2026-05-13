#include "cohan_msg_bridge.hpp"

namespace CoHANmsgBridge {

CoHANmsgBridge::CoHANmsgBridge() : Node("cohan_msg_bridge") {
    tf_buffer_ = std::make_shared<tf2_ros::Buffer>(this->get_clock());
    tf_listener_ = std::make_shared<tf2_ros::TransformListener>(*tf_buffer_, this);

    this->declare_parameter<std::string>("planning_frame", "kiro_base_link");
    TARGET_FRAME = this->get_parameter("planning_frame").as_string();

    subscription_ = this->create_subscription<vision_msgs::msg::Detection3DArray>(
        "yolo_3d_result", 10, std::bind(&CoHANmsgBridge::topic_callback, this, std::placeholders::_1));

    publisher_ = this->create_publisher<cohan_msgs::msg::TrackedAgents>("tracked_agents", 10);

    setup_uwb_subscribers();
    RCLCPP_INFO(this->get_logger(), "Bridge Node with UWB Fusion Started.");
}

void CoHANmsgBridge::setup_uwb_subscribers() {
    for (int id : {1, 2}) {
        uwb_registry_[id] = UWBWorker();

        uwb_pos_subs_.push_back(this->create_subscription<geometry_msgs::msg::Point>(
            "uwb/worker" + std::to_string(id), 10,
            [this, id](const geometry_msgs::msg::Point::SharedPtr msg) { uwb_pos_callback(msg, id); }));

        uwb_name_subs_.push_back(this->create_subscription<std_msgs::msg::String>(
            "uwb/worker" + std::to_string(id) + "_name_tag", 10,
            [this, id](const std_msgs::msg::String::SharedPtr msg) { uwb_name_callback(msg, id); }));
    }
}

void CoHANmsgBridge::uwb_pos_callback(const geometry_msgs::msg::Point::SharedPtr msg, int id) {
    uwb_registry_[id].position = *msg;
    uwb_registry_[id].has_data = true;
}

void CoHANmsgBridge::uwb_name_callback(const std_msgs::msg::String::SharedPtr msg, int id) {
    uwb_registry_[id].name = msg->data;
}

void CoHANmsgBridge::topic_callback(const vision_msgs::msg::Detection3DArray::SharedPtr msg) {
    geometry_msgs::msg::TransformStamped transform;
    try {
        transform = tf_buffer_->lookupTransform(TARGET_FRAME, msg->header.frame_id, 
                                               msg->header.stamp, rclcpp::Duration::from_seconds(0.1));
    } catch (const tf2::TransformException & ex) { return; }

    auto output_msg = cohan_msgs::msg::TrackedAgents();
    output_msg.header.frame_id = TARGET_FRAME;
    output_msg.header.stamp = msg->header.stamp;

    std::set<int> fused_uwb_ids;
    int unknown_human_count = 0;

    // Process YOLO detections and attempt fusion
    for (const auto & detection : msg->detections) {
        if (detection.results.empty() || detection.results[0].hypothesis.class_id != "person" || 
            detection.results[0].hypothesis.score < SCORE_THRESHOLD) continue;

        geometry_msgs::msg::Pose transformed_pose;
        tf2::doTransform(detection.bbox.center, transformed_pose, transform);

        std::string agent_name = "";
        uint64_t final_id = 0;
        bool fused = false;
        
        // Euclidean distance check against UWB workers
        for (auto& [id, worker] : uwb_registry_) {
            if (worker.has_data) {
                double dist = FusionUtils::get_distance(transformed_pose.position, worker.position);
                if (dist < FUSION_DISTANCE) {
                    // FUSION ACCEPTED
                    agent_name = "worker_" + std::to_string(id);
                    final_id = id; 
                    fused_uwb_ids.insert(id);
                    fused = true;
                    break;
                }
            }
        }

        if (!fused) {
            unknown_human_count++;
            agent_name = "human_" + std::to_string(unknown_human_count);
            final_id = 100 + unknown_human_count; 
        }

        output_msg.agents.push_back(create_agent(transformed_pose, final_id, agent_name));
    }

    // Add UWB workers not matched with YOLO
    for (const auto& [id, worker] : uwb_registry_) {
        if (worker.has_data && fused_uwb_ids.find(id) == fused_uwb_ids.end()) {
            geometry_msgs::msg::Pose p;
            p.position = worker.position;
            
            std::string fallback_name = "worker_" + std::to_string(id);
            output_msg.agents.push_back(create_agent(p, id, fallback_name));
        }
    }

    if (!output_msg.agents.empty()) publisher_->publish(output_msg);
}

cohan_msgs::msg::TrackedAgent CoHANmsgBridge::create_agent(const geometry_msgs::msg::Pose& pose, uint64_t id, const std::string& name) {
    cohan_msgs::msg::TrackedAgent agent;
    agent.track_id = id;
    agent.name = name;
    agent.state = cohan_msgs::msg::TrackedAgent::STATIC;

    cohan_msgs::msg::TrackedSegment segment;
    segment.type = cohan_msgs::msg::TrackedSegmentType::TORSO;
    segment.pose.pose = pose;
    agent.segments.push_back(segment);
    return agent;
}

} // namespace CoHANmsgBridge

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<CoHANmsgBridge::CoHANmsgBridge>());
  rclcpp::shutdown();
  return 0;
}