class_name Coaster
extends Area2D

var current_cup: Area2D = null

func is_empty() -> bool:
	return current_cup == null or not is_instance_valid(current_cup)

func place_cup(cup: Area2D) -> void:
	current_cup = cup

func remove_cup() -> void:
	current_cup = null
