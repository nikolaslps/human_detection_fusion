# 05 — Role in the TRL6-7 Demonstrator

## Demonstrator at a glance

| Item | Value |
|---|---|
| Demonstrator | KIRO — *Demonstration of HRI-enabled solution at work* (ARISE D3) |
| Environment | IKH facilities, **ARISTOS assembly production area** — a live shop floor with dense layouts, narrow corridors, continuous worker presence, and variable lighting (not a lab or TEF) |
| Robot / platform | Custom IKH differential-drive mobile base carrying a UR10e arm |
| End user / scenario | Shop-floor assembly workers at IKH who need on-demand tool delivery during assembly tasks |
| System TRL | 6 |
| Demonstrator video | **[KIRO full system demonstration](https://www.youtube.com/watch?v=uGGcSsZhrGk)** |

## Problem the module addresses

For a mobile robot to navigate safely around workers in a shared industrial workspace, it must know
where those workers are — continuously, in 3-D, with enough confidence to drive social-cost layers
in a real-time planner. Camera alone is insufficient (no reliable depth); LiDAR alone cannot
identify which cluster is a person; UWB alone does not provide visual confirmation or allow
detection of unknown persons. `human_detection_fusion` solves this by fusing all three modalities:
YOLO provides visual person detection with tracking IDs; the Bpearl LiDAR provides metric depth
for 3-D projection; and UWB provides identity association, linking anonymous visual detections to
named workers from the FIWARE NGSI-LD context broker. The result is a per-person 3-D position
stream in the ROS4HRI format that the social planner can consume directly.

## Module role in the full pipeline

```
FIWARE Orion-LD context broker
    Worker:EMP-1 (mapPosition, nameTag)
    Worker:EMP-2 (mapPosition, nameTag)
            │ DDS↔NGSI-LD enabler (eProsima)
            │ rt/uwb/worker1[2], rt/uwb/worker1[2]_name_tag
            ▼
Physical sensors  +  UWB positions from FIWARE
  RealSense D455        │
  Bpearl LiDAR         │
            │           │
            ▼           ▼
  1. tracker_node (YOLO)              → /yolo_result (2-D bounding boxes + track IDs)
  2. tracker_with_cloud_node (LiDAR)  → /yolo_3d_result (3-D bounding boxes)
  3. yolo_uwb_fusion_node             → /humans/persons/tracked
                                         /humans/persons/<id>/position
            │
            ▼
        kiro_nav (CoHAN-Nav2 / HATeb)
          hri_to_cohan_bridge → /tracked_agents
          controller_server (HATeb) → /cmd_vel
```

In production at IKH, this module ran as a separate container on the robot's compute unit, feeding
position data continuously to `kiro_nav`. `kiro_nav`'s `hri_to_cohan_bridge` subscribed to the
ROS4HRI topics, converted them to `cohan_msgs/TrackedAgents`, and HATeb used those tracked agents
to compute socially-aware velocity commands.

## What was extracted as reusable vs what stays demonstrator-specific

| Demonstrator component | Reusable here (`human_detection_fusion`) | Stays demonstrator-specific |
|---|---|---|
| YOLO person detection | ✅ Packaged via `ultralytics_ros` (cloned in Dockerfile) | — |
| LiDAR-camera 3-D fusion | ✅ Packaged via `ultralytics_ros` `tracker_with_cloud_node` | — |
| UWB identity fusion | ✅ Packaged as `yolo_uwb_fusion_node` (`src/`) | — |
| ROS4HRI output interface | ✅ Outputs `hri_msgs/IdsList` + `PointOfInterest3DStamped` | — |
| FIWARE / NGSI-LD UWB input | ✅ Topic contract documented and consumed (DDS↔NGSI-LD bridge delivers `uwb/worker*` topics) | FIWARE Orion-LD instance + DDS bridge configuration live at KIRO system level, not in this repo |
| UWB hardware + anchor software | Topic contract only (`uwb/worker*`) | Physical UWB tags worn by workers + anchor base stations at IKH |
| cohan_msgs bridge (to kiro_nav) | Not in this module — `kiro_nav` does the conversion | Bridge logic is in `kiro_nav`'s `hri_to_cohan_bridge` |
| Mission controller | — | YASMIN FSM + IKH station-specific logic |
| Arm + gripper control | — | MoveIt2, vacuum gripper I/O, AprilTag pick logic |

## Validation evidence

From the KIRO TRL6-7 pilot at IKH's ARISTOS assembly area:

- Persons detected and tracked in real-time in a live shop-floor environment with variable
  lighting, moving workers, and cluttered backgrounds.
- Worker identities correctly assigned via UWB nearest-neighbour association across all test runs.
- `kiro_nav`'s CoHAN social planner successfully consumed the ROS4HRI output — **zero collisions**
  with workers across all navigation trials.
- The `examples/` simulation (PMB2 + HuNavSim + UWB simulator node) reproduces the full pipeline
  behavior and has been verified end-to-end in this repo's standalone Docker-packaged form.
