class_name DataFiles
## Loading game content from data/ folders.


## Every .tres resource in a data folder (works in exported builds too).
static func load_all(dir: String) -> Array[Resource]:
	var found: Array[Resource] = []
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with(".tres"):
			found.append(load(dir.path_join(file)))
	return found
