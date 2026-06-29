# 01 — ARISE Context

## What this module is

`human_detection_fusion` is the **Human Detection and Tracking** reusable module produced by the
**KIRO** experiment (*Key Intelligent & Interactive Robotic Operator*), funded under the ARISE 1st
Open Call (Horizon Europe, GA 101135784, lead **IKNOWHOW SA**). It packages, as open and
independently runnable software, the human detection and tracking stack of the KIRO TRL6-7
demonstrator: a containerized ROS 2 / Vulcanexus pipeline that fuses YOLO visual detections with
Bpearl LiDAR depth and UWB worker identity data to produce per-person 3-D positions in the
[ROS4HRI](https://wiki.ros.org/hri) format.

## KIRO in one paragraph

KIRO is an HRI-enabled mobile manipulator (UR10e arm on a mobile base) that delivers tools to
shop-floor operators on demand. A worker requests a tool by voice/app; an LLM agent and the FIWARE
Orion-LD context broker resolve the request into a mission; a ROS 2 mission controller (a YASMIN
state machine) then drives socially-aware navigation, tool recognition + picking, and a socially /
ergonomically aware handover. This module is the **perception layer** of that loop — it continuously
monitors the workspace for workers and publishes their 3-D positions so that the social navigation
planner (`kiro_nav`) can route around them. KIRO reached **TRL 6** in a pilot at IKH's ARISTOS
assembly area.

## Where this module sits in the demonstrator

`human_detection_fusion` is the upstream producer of all human-tracking data in KIRO:

```
Physical sensors        FIWARE Orion-LD context broker
  RealSense D455             │
  Bpearl LiDAR               │   Worker entities (EMP-1, EMP-2)
  UWB anchor tags ──────────►│   DDS↔NGSI-LD enabler (eProsima)
                             │       │ rt/uwb/worker1[2]
                             │       │ rt/uwb/worker1[2]_name_tag
                             ▼       ▼
                  human_detection_fusion  (THIS MODULE)
                    YOLO detections + LiDAR depth
                    fused with UWB worker identity
                             │
              /humans/persons/tracked  (hri_msgs/IdsList)
              /humans/persons/<id>/position  (PointOfInterest3DStamped)
                             │
                             ▼
                         kiro_nav
                  (CoHAN-Nav2 / HATeb social planner)
                             │
                         /cmd_vel  → robot base
```

`human_detection_fusion` does not know or care about the current mission — it publishes person
positions continuously. The social planner decides how to use that information.

## What is open here

The complete human detection and tracking capability is open: the `yolo_uwb_fusion_node` C++ source,
launch files, Dockerfile, `run.sh` / `run.sh --sim` entry points, and the full `examples/` demo
paired with the companion [`pmb2_hunav_simulation`](../../pmb2_hunav_simulation) repo
(`kiro_sensors` branch). The YOLO and LiDAR-camera fusion components rely on the open
[`ultralytics_ros`](https://github.com/nikolaslps/ultralytics_ros) wrapper cloned at image-build
time. What remains demonstrator-specific — the mission controller, grasping logic, robot
localization tuning, and the UWB hardware installation at IKH.

## ARISE middleware alignment (summary)

| Concern | This module |
|---|---|
| **ROS 2 / Vulcanexus** | ✅ Core interface. Vulcanexus Humble; the full pipeline is exposed over standard ROS 2 topics (Fast DDS). |
| **ROS4HRI / ROS4RI** | ✅ Upstream producer. Publishes `hri_msgs/IdsList` on `/humans/persons/tracked` and `hri_msgs/PointOfInterest3DStamped` per person. See [`02_interfaces.md`](02_interfaces.md#ros4hri--ros4ri-alignment). |
| **FIWARE / NGSI-LD** | ✅ Applied for UWB inputs. Worker positions and identity tags arrive from FIWARE NGSI-LD `Worker` entities via the DDS↔NGSI-LD enabler. See [`02_interfaces.md`](02_interfaces.md#fiware--ngsi-ld--dds-enabler). |
| **DDS↔NGSI-LD enabler** | ✅ Applied. The eProsima DDS Router bridges `Worker.mapPosition` and `Worker.nameTag` NGSI-LD attributes as DDS topics (`rt/uwb/worker1`, etc.), received natively by this module as ROS 2 topics. |

## Target platforms

| Target platform category | Tested on | Expected compatibility | Not supported or unknown |
|---|---|---|---|
| Mobile robot / AMR / AGV | IKH's custom differential-drive mobile robot (RealSense D455 + Bpearl LiDAR + UWB) at IKH's premises. PMB2 in simulation via `pmb2_hunav_simulation` (`kiro_sensors` branch). | Any mobile robot that publishes a colour camera image, a 3-D point cloud, and UWB position data on the expected topics | Not tested on platforms without UWB (UWB workers not matched visually are still published from UWB alone if no visual detection is available) |
| Sensors | Intel RealSense D455, Bpearl 3D LiDAR, UWB anchor tags. Simulated: Gazebo VLP-16 lidar + RealSense D435 plugin + UWB sim node. | Any RGB-D camera + PointCloud2 LiDAR providing the standard topic contract | Monocular 2-D cameras (no depth for 3-D projection) |
| Simulation | Gazebo Classic 11 via `pmb2_hunav_simulation` (`kiro_sensors` branch) | — | Gazebo Ignition/Fortress, Isaac Sim, Webots not tested |

## Off-the-shelf capabilities

Available immediately from a fresh checkout + `docker build`:

- YOLO-based person detection with tracking IDs on a live camera stream.
- LiDAR-camera projection for 3-D bounding boxes per tracked person.
- UWB identity fusion: visual detections are matched to known UWB workers by nearest-neighbour
  association, producing named person IDs (e.g. `worker_1`) instead of anonymous track IDs.
- A working ROS4HRI output interface (`/humans/persons/tracked` + per-person position topics)
  consumable by any social navigation planner.
- Two operating modes via one flag (`run.sh` vs. `run.sh --sim`): real-robot operation (paired
  with IKH's UWB + sensor stack) or simulation against the companion repo for `examples/`.

Maturity: the full pipeline was run and tested at IKH's premises as part of the KIRO TRL6-7
stack; the standalone Docker-packaged form has been verified end-to-end against the companion
simulation repo (see `docs/03`, `docs/04`).

## ROS4HRI / ROS4RI applicability

Applied — this module is the **upstream producer** of the ROS4HRI position sub-interface:

- **`/humans/persons/tracked`** (`hri_msgs/IdsList`) — list of active person IDs.
- **`/humans/persons/<id>/position`** (`hri_msgs/PointOfInterest3DStamped`) — one topic per tracked
  person, published dynamically as persons appear.

The module does not implement the full ROS4HRI person lifecycle (no `/humans/persons/<id>/face`,
`/body`, `/voice` etc.) — it publishes the position sub-interface that social navigation planners
require. Downstream consumers (`kiro_nav`'s `hri_to_cohan_bridge`) subscribe to these topics
following the standard ROS4HRI convention without any custom integration. Full details:
[`02_interfaces.md`](02_interfaces.md#ros4hri--ros4ri-alignment).
