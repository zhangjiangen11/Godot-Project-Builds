extends Control

@onready var custom_list: HBoxContainer = %CustomList
@onready var projects: VBoxContainer = %Projects
@onready var over: Label = %Over

var user_arguments := OS.get_cmdline_user_args()

func _ready() -> void:
	var i := user_arguments.find("--open-project")
	if i > -1:
		if user_arguments.size() < i + 2:
			printerr("No project path provided with --open-project.")
		else:
			var project_path := user_arguments[i + 1]
			if DirAccess.dir_exists_absolute(project_path):
				Data.from_plugin = true
				load_project.call_deferred(project_path)
				return
			else:
				printerr("The project provided for --open-project does not exist.")
	
	i = user_arguments.find("--execute-routine")
	if i > -1:
		printerr("--execute-routine was provided, but no project was opened with --open-project.")
		get_tree().quit(1)
		return
	
	i = user_arguments.find("--exit")
	if i > -1:
		printerr("--exit argument provided, but no --execute-routine. It will be ignored.")
	
	custom_list.text = Data.global_config["custom_project_list"]
	load_project_list()

func load_project_list():
	for project in projects.get_children():
		project.queue_free()
	
	var projects_path: String = custom_list.text
	
	var i := user_arguments.find("--projects-file-path")
	if i > -1:
		if user_arguments.size() < i + 2:
			push_warning("--projects-file-path -- Missing projects file path.")
		else:
			over.show()
			projects_path = user_arguments[i + 1]
	
	if not FileAccess.file_exists(projects_path):
		var editor_data := OS.get_user_data_dir().get_base_dir().get_base_dir()
		projects_path = editor_data.path_join("projects.cfg")
	
	var project_list := ConfigFile.new()
	if project_list.load(projects_path) != OK:
		return
	
	for project in project_list.get_sections():
		var project_entry := preload("res://Nodes/ProjectEntry.tscn").instantiate()
		projects.add_child(project_entry)
		project_entry.set_project(project, load_project)

func load_project(project: String):
	Data.load_project(project)
	
	var i := user_arguments.find("--execute-routine")
	if i > -1:
		var j := user_arguments.find("--exit")
		if j > -1:
			Data.auto_exit = true
		
		if user_arguments.size() < i + 2:
			print("No routine name provided for --execute-routine.")
			print_routines_and_exit()
			return
		else:
			var routine_name := user_arguments[i + 1]
			for routine in Data.routines:
				if routine["name"] == routine_name:
					Data.current_routine = routine
					get_tree().change_scene_to_file("res://Scenes/Execution.tscn")
					return
			
			printerr("The routine provided for --execute-routine does not exist.")
			print_routines_and_exit()
			return
	
	i = user_arguments.find("--exit")
	if i > -1:
		printerr("--exit argument provided, but no --execute-routine. It will be ignored.")
	
	get_tree().change_scene_to_packed(Data.main)

func print_routines_and_exit():
	print("Available routines:")
	for routine in Data.routines:
		print(routine["name"])
	
	if Data.auto_exit:
		get_tree().quit(1)

func project_list_path_changed() -> void:
	Data.global_config["custom_project_list"] = custom_list.text
	Data.save_global_config()
	load_project_list()
