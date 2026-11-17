class_name PlayerProgression
extends RefCounted
## Gestiona la experiencia (XP) y el nivel del capitán.

signal xp_gained(amount: int, reason: String, current_xp: int, xp_to_next: int)
signal leveled_up(new_level: int, current_xp: int, xp_to_next: int)

var level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 25


func add_xp(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return

	current_xp += amount
	xp_gained.emit(amount, reason, current_xp, xp_to_next_level)

	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = _compute_next_threshold(level)
		leveled_up.emit(level, current_xp, xp_to_next_level)


func reset() -> void:
	level = 1
	current_xp = 0
	xp_to_next_level = _compute_next_threshold(1)


func _compute_next_threshold(lvl: int) -> int:
	# Escalado suave: 25, 35, 45, 55...
	return 25 + (lvl - 1) * 10
