class_name DataFiles
## Loading game content from data/ folders. Everything is kept once loaded: load() and
## listing a folder go to the disk (or the web build's pack) on every call, which made the game
## lag when done every frame.

static var _loaded := {}
static var _folders := {}


## Every .tres resource in a data folder (works in exported builds too).
static func load_all(dir: String) -> Array[Resource]:
	if not _folders.has(dir):
		var found: Array[Resource] = []
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".tres"):
				found.append(res(dir.path_join(file)))
		_folders[dir] = found
	return (_folders[dir] as Array[Resource]).duplicate()


## The resource at `path` (res://...), loaded once and kept.
static func res(path: String) -> Resource:
	var hit: Resource = _loaded.get(path)
	if hit == null:
		hit = load(path)
		if hit:
			_loaded[path] = hit
	return hit
