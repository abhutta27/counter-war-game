class_name Helpers
extends RefCounted
## Helpers.gd
## General static utilities for safe node operations, time formatting, and physics math.

## Formats seconds into MM:SS.MS string
static func format_time_minutes_seconds(seconds: float) -> String:
	var total_sec: int = int(seconds)
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	var ms: int = int((seconds - total_sec) * 10.0)
	return "%02d:%02d.%d" % [mins, secs, ms]

## Safely searches tree for first node in group
static func get_first_node_in_group(tree: SceneTree, group_name: String) -> Node:
	if not tree:
		return null
	var nodes := tree.get_nodes_in_group(group_name)
	return nodes[0] if nodes.size() > 0 else null

## Returns flat 2D distance on XZ plane between two 3D points
static func horizontal_distance(from: Vector3, to: Vector3) -> float:
	var diff := to - from
	return Vector2(diff.x, diff.z).length()

## Clamps angle in degrees between min and max
static func clamp_angle_deg(angle_deg: float, min_deg: float, max_deg: float) -> float:
	return clampf(angle_deg, min_deg, max_deg)