class_name ObjectPool
extends Node2D

## Generic scene object pool. Pooled nodes are instantiated once, parented
## here, and recycled forever; nothing is freed during play, so the garbage
## collector stays idle while the horde churns.
##
## Pooled scenes may opt into lifecycle hooks:
##   on_acquire() -> void   called when handed out by acquire()
##   on_release() -> void   called when returned by release()
## Hooks must fully hide/deactivate the node (shapes via set_deferred, since
## releases often happen inside physics callbacks).

@export var scene: PackedScene
## Pre-warmed instances created in _ready to avoid first-wave hitching.
@export var initial_size: int = 0
## Hard ceiling on live instances; acquire() returns null when exhausted.
@export var max_size: int = 300

var active_count: int = 0

var _free: Array[Node] = []


func _ready() -> void:
	for i in initial_size:
		var node := _instantiate()
		if node != null:
			_free.append(node)


func acquire() -> Node:
	var node := _free.pop_back() as Node
	if node == null or not is_instance_valid(node):
		node = _instantiate()
	if node == null:
		return null
	if node.has_method("on_acquire"):
		node.on_acquire()
	active_count += 1
	return node


func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _free.has(node):
		return  # double release: the node is already parked
	if node.has_method("on_release"):
		node.on_release()
	active_count = maxi(0, active_count - 1)
	_free.append(node)


## Creates a new parked instance. Callers decide whether it goes to _free
## (prewarm, release) or straight to an acquire; it must never be in both
## states at once, or acquire() can hand the same node out twice.
func _instantiate() -> Node:
	if scene == null:
		push_error("ObjectPool has no scene assigned")
		return null
	if get_child_count() >= max_size:
		return null
	var node := scene.instantiate()
	add_child(node)
	node.visible = false
	if node.has_method("on_release"):
		node.on_release()
	return node
