#include "yolo_uwb_fusion_node.hpp"

namespace YoloUWBFusion {

YoloUWBFusionNode::YoloUWBFusionNode() : Node("yolo_uwb_fusion_node") {
    tf_buffer_ = std::make_shared<tf2_ros::Buffer>(this->get_clock());
    tf_listener_ = std::make_shared<tf2_ros::TransformListener>(*tf_buffer_, this);

    this->declare_parameter<std::string>("planning_frame", "kiro_base_link");
    TARGET_FRAME = this->get_parameter("planning_frame").as_string();

    this->declare_parameter<std::string>("uwb_frame", "map");
    UWB_FRAME = this->get_parameter("uwb_frame").as_string();

    subscription_ = this->create_subscription<vision_msgs::msg::Detection3DArray>(
        "yolo_3d_result", 10,
        std::bind(&YoloUWBFusionNode::topic_callback, this, std::placeholders::_1));

    tracked_pub_ = this->create_publisher<hri_msgs::msg::IdsList>(
        "/humans/persons/tracked", 10);

    tracker_param_client_ = std::make_shared<rclcpp::AsyncParametersClient>(this, "tracker_node");
    update_tracker_classes();

    setup_uwb_subscribers();
    RCLCPP_INFO(this->get_logger(), "YOLO+UWB Fusion Node started.");
}

void YoloUWBFusionNode::setup_uwb_subscribers() {
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

void YoloUWBFusionNode::update_tracker_classes() {
    if (!tracker_param_client_->wait_for_service(std::chrono::seconds(2))) {
        RCLCPP_ERROR(this->get_logger(), "Tracker node service not found!");
        return;
    }
    std::vector<int64_t> new_classes = {0};
    auto future = tracker_param_client_->set_parameters(
        {rclcpp::Parameter("classes", new_classes)},
        [this](std::shared_future<std::vector<rcl_interfaces::msg::SetParametersResult>> future) {
            auto results = future.get();
            if (results[0].successful) {
                RCLCPP_INFO(this->get_logger(), "Successfully changed classes to 0");
            } else {
                RCLCPP_ERROR(this->get_logger(), "Failed to set classes: %s", results[0].reason.c_str());
            }
        });
}

void YoloUWBFusionNode::uwb_pos_callback(const geometry_msgs::msg::Point::SharedPtr msg, int id) {
    uwb_registry_[id].position = *msg;
    uwb_registry_[id].has_data = true;
}

void YoloUWBFusionNode::uwb_name_callback(const std_msgs::msg::String::SharedPtr msg, int id) {
    uwb_registry_[id].name = msg->data;
}

rclcpp::Publisher<hri_msgs::msg::PointOfInterest3DStamped>::SharedPtr
YoloUWBFusionNode::get_or_create_position_pub(const std::string& person_id) {
    auto it = position_pubs_.find(person_id);
    if (it != position_pubs_.end()) return it->second;

    auto pub = this->create_publisher<hri_msgs::msg::PointOfInterest3DStamped>(
        "/humans/persons/" + person_id + "/position", 10);
    position_pubs_[person_id] = pub;
    return pub;
}

geometry_msgs::msg::Point YoloUWBFusionNode::transformUWBPosition(const geometry_msgs::msg::Point& pt) {
    if (UWB_FRAME == TARGET_FRAME) return pt;

    geometry_msgs::msg::PointStamped stamped_in, stamped_out;
    stamped_in.header.frame_id = UWB_FRAME;
    stamped_in.header.stamp = this->now();
    stamped_in.point = pt;

    try {
        tf_buffer_->transform(stamped_in, stamped_out, TARGET_FRAME, tf2::durationFromSec(0.1));
        return stamped_out.point;
    } catch (const tf2::TransformException& ex) {
        RCLCPP_WARN(this->get_logger(), "UWB TF transform %s→%s failed: %s",
                    UWB_FRAME.c_str(), TARGET_FRAME.c_str(), ex.what());
        return pt;
    }
}

void YoloUWBFusionNode::topic_callback(const vision_msgs::msg::Detection3DArray::SharedPtr msg) {
    geometry_msgs::msg::TransformStamped transform;
    try {
        transform = tf_buffer_->lookupTransform(TARGET_FRAME, msg->header.frame_id,
                                               msg->header.stamp, rclcpp::Duration::from_seconds(0.1));
    } catch (const tf2::TransformException & ex) { return; }

    auto now = msg->header.stamp;
    std::vector<std::string> tracked_ids;
    std::set<int> fused_uwb_ids;
    int unknown_count = 0;

    for (const auto & detection : msg->detections) {
        if (detection.results.empty() ||
            detection.results[0].hypothesis.class_id != "person" ||
            detection.results[0].hypothesis.score < SCORE_THRESHOLD) continue;

        geometry_msgs::msg::Pose transformed_pose;
        tf2::doTransform(detection.bbox.center, transformed_pose, transform);

        std::string person_id;
        float confidence = static_cast<float>(detection.results[0].hypothesis.score);
        bool fused = false;

        for (auto& [id, worker] : uwb_registry_) {
            if (worker.has_data) {
                auto uwb_in_target = transformUWBPosition(worker.position);
                double dist = FusionUtils::get_distance(transformed_pose.position, uwb_in_target);
                if (dist < FUSION_DISTANCE) {
                    person_id = "worker_" + std::to_string(id);
                    fused_uwb_ids.insert(id);
                    fused = true;
                    break;
                }
            }
        }

        if (!fused) {
            unknown_count++;
            person_id = "human_" + std::to_string(unknown_count);
        }

        hri_msgs::msg::PointOfInterest3DStamped poi;
        poi.header.stamp = now;
        poi.header.frame_id = TARGET_FRAME;
        poi.x = static_cast<float>(transformed_pose.position.x);
        poi.y = static_cast<float>(transformed_pose.position.y);
        poi.z = static_cast<float>(transformed_pose.position.z);
        poi.c = confidence;

        get_or_create_position_pub(person_id)->publish(poi);
        tracked_ids.push_back(person_id);
    }

    // UWB-only workers not matched by YOLO
    for (const auto& [id, worker] : uwb_registry_) {
        if (!worker.has_data || fused_uwb_ids.count(id)) continue;

        std::string person_id = "worker_" + std::to_string(id);

        auto uwb_in_target = transformUWBPosition(worker.position);
        hri_msgs::msg::PointOfInterest3DStamped poi;
        poi.header.stamp = now;
        poi.header.frame_id = TARGET_FRAME;
        poi.x = static_cast<float>(uwb_in_target.x);
        poi.y = static_cast<float>(uwb_in_target.y);
        poi.z = static_cast<float>(uwb_in_target.z);
        poi.c = 1.0f;

        get_or_create_position_pub(person_id)->publish(poi);
        tracked_ids.push_back(person_id);
    }

    if (!tracked_ids.empty()) {
        hri_msgs::msg::IdsList ids_msg;
        ids_msg.header.stamp = now;
        ids_msg.header.frame_id = TARGET_FRAME;
        ids_msg.ids = tracked_ids;
        tracked_pub_->publish(ids_msg);
    }
}

}  // namespace YoloUWBFusion

int main(int argc, char * argv[])
{
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<YoloUWBFusion::YoloUWBFusionNode>());
    rclcpp::shutdown();
    return 0;
}
