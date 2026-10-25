extends SceneTree

## Dev tool: checks whether a UID resolves from the on-disk cache.
## Run: godot --headless -s tests/uid_probe.gd

func _init() -> void:
	var uid_text := "uid://cusumss6ccdhq"
	var id := ResourceUID.text_to_id(uid_text)
	print("id: %d" % id)
	print("has_id: %s" % ResourceUID.has_id(id))
	var path := ResourceUID.get_id_path(id)
	print("path: %s" % path)
	quit(0)
