extends Node

const CONFIG_FILE = "project_builds_config.txt"
var local_config_file: String

var global_config: Dictionary
var local_config: Dictionary
var project_path: String
var from_plugin: bool
var auto_exit: bool

var first_load: bool
var initial_load: bool
var static_initialize_tasks: Array[Script]
var sensitive_settings: Array[String]

var tasks: Dictionary#[String, Dictionary]
var routines: Array[Dictionary]
var templates: Array[Dictionary]

var current_routine: Dictionary
var copied_task: Dictionary

var save_local_timer: Timer
var save_global_timer: Timer

var main: PackedScene

func _init() -> void:
	var task_path := get_res_path().path_join("Tasks")
	for task in DirAccess.get_files_at(task_path):
		if task.get_extension() == "tscn":
			register_task(task_path.path_join(task))
	
	var global_defaults = {"project_builder_path": "", "project_builder_executable": "", "custom_project_list": ""}
	
	var global_config_file := FileAccess.open("user://".path_join(CONFIG_FILE), FileAccess.READ)
	if global_config_file:
		global_config = str_to_var(global_config_file.get_as_text())
		global_config.merge(global_defaults)
	else:
		global_config = global_defaults
	
	save_local_timer = Timer.new()
	save_local_timer.wait_time = 0.5
	save_local_timer.one_shot = true
	add_child(save_local_timer)
	
	save_global_timer = save_local_timer.duplicate()
	add_child(save_global_timer)
	
	save_local_timer.timeout.connect(save_local_config)
	save_global_timer.timeout.connect(save_global_config)
	
	main = load("res://Scenes/Main.tscn")

func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		return
	
	var path := ProjectSettings.globalize_path("res://")
	if path != global_config["project_builder_path"]:
		global_config["project_builder_path"] = path
		queue_save_global_config()
	
	path = OS.get_executable_path()
	if path != global_config["project_builder_executable"]:
		global_config["project_builder_executable"] = path
		queue_save_global_config()

func get_project_config_path(project: String, config_file: ConfigFile = null) -> String:
	if not config_file:
		config_file = ConfigFile.new()
		config_file.load(project)
	
	var config_path: String = config_file.get_value("addons", "project_builder/config_path", "") # compat
	if config_path.is_empty():
		config_path = config_file.get_value("", "_project_builder_config_path", CONFIG_FILE)
	
	return config_path.trim_prefix("res://")

func load_project(path: String):
	project_path = path
	first_load = true
	
	local_config_file = get_project_config_path(project_path.path_join("project.godot"))
	var fa := FileAccess.open(project_path.path_join(local_config_file), FileAccess.READ)
	if fa:
		local_config = str_to_var(fa.get_as_text())
	else:
		local_config = {}
		local_config["routines"]  = Array([], TYPE_DICTIONARY, &"", null)
		local_config["templates"]  = Array([], TYPE_DICTIONARY, &"", null)
		initial_load = true

	routines = local_config["routines"]
	templates = local_config["templates"]

func register_task(scene: String):
	var data := Dictionary()
	var scene_base := scene.get_file().get_basename()
	data["scene"] = scene_base
	data["scene_cache"] = load(scene)
	
	var instance: Task = load(scene).instantiate()
	data["name"] = instance._get_task_name()
	if instance.has_static_configuration:
		static_initialize_tasks.append(instance.get_script())
	instance.free()
	
	tasks[scene_base] = data

func create_routine() -> Dictionary:
	var routine := Dictionary()
	routine["name"] = get_unique_name(routines, "New Routine", "%d")
	routine["on_fail"] = 0
	routine["tasks"] = []
	routines.append(routine)
	return routine

func reset_current_routine() -> void:
	current_routine = {}

func get_template(template_name: String) -> Dictionary:
	for template in templates:
		if template["name"] == template_name:
			return template
	return {}

func get_project_version() -> String:
	var project := ConfigFile.new()
	project.load(project_path.path_join("project.godot"))
	return project.get_value("application", "config/version", "")

func get_godot_path() -> String:
	var local_godot: String = local_config["godot_path"]
	if local_godot.is_empty():
		return global_config["godot_path"]
	else:
		return local_godot

func get_res_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	else:
		return OS.get_executable_path().get_base_dir()

func resolve_path(path: String) -> String:
	if path.is_absolute_path():
		return path
	else:
		return Data.project_path.path_join(path)

func get_unique_name(dataset: Array[Dictionary], base: String, format_suffix: String, initial_count := 1) -> String:
	var unique_name := base
	var format_base := base + " " + format_suffix
	var tries := initial_count
	
	while dataset.any(func(data: Dictionary) -> bool: return data["name"] == unique_name):
		tries += 1
		unique_name = format_base % tries
	
	return unique_name

func queue_save_local_config():
	save_local_timer.start()

func save_local_config():
	save_local_timer.stop()
	var fa := FileAccess.open(project_path.path_join(local_config_file), FileAccess.WRITE)
	fa.store_string(var_to_str(local_config))

func queue_save_global_config():
	save_global_timer.start()

func save_global_config():
	save_global_timer.stop()
	var fa := FileAccess.open("user://".path_join(CONFIG_FILE), FileAccess.WRITE)
	fa.store_string(var_to_str(global_config))

func _exit_tree() -> void:
	if not project_path.is_empty():
		save_local_config()
	save_global_config()
