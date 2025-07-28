extends "BaseScriptTask.gd"

func _init() -> void:
	add_expected_argument("source", "Directory to clear.")
	add_variadic_argument("filters", "List of filters.")
	
	if not fetch_arguments():
		return
	
	var directory_path: String = arguments["source"]
	var include_filters: PackedStringArray
	var exclude_filters: PackedStringArray
	
	var mode := 0
	for arg: String in arguments["filters"]:
		if arg == "--include":
			mode = 1
		elif arg == "--exclude":
			mode = 2
		else:
			if mode == 1:
				include_filters.append(arg)
			elif mode == 2:
				exclude_filters.append(arg)
	
	DirAccess.make_dir_recursive_absolute("user://Trash")
	
	var counter: int
	var fail_counter: int
	for file in DirAccess.get_files_at(directory_path):
		var skip := not include_filters.is_empty()
		for filter in include_filters:
			if file.match(filter):
				skip = false
				break
		
		if not skip:
			for filter in exclude_filters:
				if file.match(filter):
					skip = true
					break
		
		if skip:
			continue
		
		print("Removing file: %s" % file)
		var error := DirAccess.rename_absolute(directory_path.path_join(file), "user://Trash".path_join(file))
		if error == OK:
			counter += 1
		else:
			fail_counter += 1
			printerr("Failed! Error: %d" % error)
	
	if fail_counter > 0:
		print("Cleanup finished. Cleared %d files, %d files failed." % [counter, fail_counter])
	elif counter > 0:
		print("Cleanup finished successfully. Cleared %d files." % counter)
	else:
		print("No files to cleanup.")
	
	quit(OK)
