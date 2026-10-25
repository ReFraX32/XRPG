class_name StatEffect
extends Resource

## A single mutation applied to one player stat by an upgrade.
## Kept as its own resource so upgrades stay fully data-driven:
## balancing a stat means editing a .tres, never script code.

enum Op {
	ADD,      ## final = current + value
	MULTIPLY, ## final = current * value
}

@export var stat: StringName = &""
@export var op: Op = Op.ADD
@export var value: float = 0.0


func _init(p_stat: StringName = &"", p_op: Op = Op.ADD, p_value: float = 0.0) -> void:
	stat = p_stat
	op = p_op
	value = p_value


func apply_to(values: Dictionary) -> void:
	if not values.has(stat):
		push_warning("StatEffect targets unknown stat '%s'" % stat)
		return
	match op:
		Op.ADD:
			values[stat] += value
		Op.MULTIPLY:
			values[stat] *= value


func describe() -> String:
	match op:
		Op.ADD:
			var sign_char := "+" if value >= 0.0 else ""
			return "%s%s %s" % [sign_char, _trim_number(value), stat]
		Op.MULTIPLY:
			var percent := roundi((value - 1.0) * 100.0)
			var sign_char := "+" if percent >= 0.0 else ""
			return "%s%d%% %s" % [sign_char, percent, stat]
	return ""


static func _trim_number(p_value: float) -> String:
	return ("%f" % p_value).rstrip("0").rstrip(".")
