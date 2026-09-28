extends SceneTree
## Prints every saved property of every data/ resource, one per line. Run it on the
## project and on an exported .pck and compare: they must match, or the export
## changed game data (it once reset every building's `terrain` to the default).
##   godot --headless --path . --script res://tools/dump_data.gd
##   godot --headless --main-pack build/site/play/index.pck --script <abs path>/dump_data.gd


func _initialize() -> void:
	for dir in ResourceLoader.list_directory("res://data"):
		var folder := "res://data".path_join(dir)
		for file in ResourceLoader.list_directory(folder):
			if not file.ends_with(".tres"):
				continue
			var res := load(folder.path_join(file))
			for prop in res.get_property_list():
				if prop.usage & PROPERTY_USAGE_STORAGE and prop.name not in ["resource_path", "script"]:
					var value: Variant = res.get(prop.name)
					if value is Resource:
						value = value.resource_path  # not its object id, which differs per run
					print("DATA %s %s=%s" % [folder.path_join(file), prop.name, value])
	quit()
