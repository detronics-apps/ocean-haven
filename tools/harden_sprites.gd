extends SceneTree
## Pixel-crisp copies of the animal and item SVGs that have sloping edges. Godot draws an SVG's
## polygons smoothed (half see-through pixels round the edge, colours blended where two shapes
## meet), which looks soft beside the rest of the art. For each such SVG this renders it as the
## importer does (scale 1), makes every pixel solid or clear and its colour one of the SVG's own
## (the drawing's and its outline's), and saves it as a PNG beside it; the data, scenes and
## scripts that used the SVG then use the PNG. The SVG stays the drawing: after redrawing one
## (or re-running tools/outline_sprites.py or make_young_birds.py), run this again:
##   godot --headless --path . --script res://tools/harden_sprites.gd
##   godot --headless --path . --import

const FOLDERS := ["res://assets/animals", "res://assets/items"]
const USERS := ["res://data", "res://scenes", "res://scripts"]
## The vet room keeps its own detailed pictures (the owner: it's a close-up inside a building).
const SKIP := ["res://assets/animals/vet"]


func _initialize() -> void:
	var made: Array[String] = []
	for folder: String in FOLDERS:
		for path: String in _files(folder, ".svg"):
			if not SKIP.any(func(s: String) -> bool: return path.begins_with(s)) and _harden(path):
				made.append(path)
	var pointed := 0
	for folder: String in USERS:
		for file: String in _files(folder, ".tres") + _files(folder, ".tscn") + _files(folder, ".gd"):
			pointed += _repoint(file, made)
	print("%d crisp PNGs; %d files now use them" % [made.size(), pointed])
	quit()


## The SVG's crisp PNG, if it has soft edges (false: it's already crisp, or empty).
func _harden(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var image := Image.new()
	if image.load_svg_from_string(text, 1.0) != OK:
		return false
	var soft := false
	for y in image.get_height():
		for x in image.get_width():
			var a := image.get_pixel(x, y).a
			soft = soft or (a > 0.02 and a < 0.98)
	if not soft:
		return false
	var palette: Array[Color] = []
	var found := RegEx.create_from_string("(?:fill|stroke)=\"(#[0-9a-fA-F]{6})\"")
	for m in found.search_all(text):
		var c := Color(m.get_string(1))
		if not palette.has(c):
			palette.append(c)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var best := c
			var best_d := INF
			for p: Color in palette:
				var d := Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length_squared()
				if d < best_d:
					best_d = d
					best = p
			image.set_pixel(x, y, Color(best, 1.0))
	image.save_png(ProjectSettings.globalize_path(path.get_basename() + ".png"))
	return true


## Points a data file, scene or script at the PNGs instead of the SVGs (a resource line loses
## the SVG's uid, so the path is what's loaded). How many it changed (0 or 1).
func _repoint(file: String, made: Array[String]) -> int:
	var text := FileAccess.get_file_as_string(file)
	var before := text
	for svg: String in made:
		if not text.contains(svg):
			continue
		var lines := text.split("\n")
		for i in lines.size():
			if lines[i].contains(svg):
				lines[i] = lines[i].replace(svg, svg.get_basename() + ".png")
				if lines[i].begins_with("[ext_resource"):
					lines[i] = RegEx.create_from_string(" uid=\"uid://[a-z0-9]+\"").sub(lines[i], "")
		text = "\n".join(lines)
	if text == before:
		return 0
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_string(text)
	return 1


func _files(dir: String, ending: String) -> Array[String]:
	var list: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ending):
			list.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		list.append_array(_files(dir + "/" + d, ending))
	return list
