#pragma once

#include <geometry_msgs/msg/point.hpp>
#include <string>
#include <cmath>

namespace YoloUWBFusion {

struct UWBWorker {
    geometry_msgs::msg::Point position;
    std::string name = "unknown_worker";
    bool has_data = false;
};

class FusionUtils {
public:
    static double get_distance(const geometry_msgs::msg::Point& p1, const geometry_msgs::msg::Point& p2) {
        return std::sqrt(std::pow(p1.x - p2.x, 2) + std::pow(p1.y - p2.y, 2));
    }
};

} // namespace YoloUWBFusion