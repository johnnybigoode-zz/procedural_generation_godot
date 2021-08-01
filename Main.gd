extends Node2D

var Room = preload("res://Room.tscn")
var Player = preload("res://Character.tscn")
var font = preload("res://assets/RobotoBold120.tres")
onready var Map = $TileMap

var tile_size = 32
var num_rooms = 50
var min_size = 4
var max_size = 10
var hspread = 400 #how horizontal should be the rooms - in pixels
var cull = 0.5 #percent of rooms to be removed

var path # AStar pathfinding object
var start_room = null
var end_room = null
var play_mode = null
var player = null

func _ready():
	randomize()
	make_rooms()
	
func make_rooms():
	for i in range(num_rooms):
		var pos = Vector2(rand_range(-hspread, hspread),0)
		var r = Room.instance()
		var w = min_size + randi() % (max_size - min_size)
		var h = min_size + randi() % (max_size - min_size)
		r.make_room(pos, Vector2(w, h) * tile_size)
		$Rooms.add_child(r)
	#wait for movement to stop
	yield(get_tree().create_timer(1.1), 'timeout')
	#cull rooms
	var room_positions = []
	for room in $Rooms.get_children():
		if randf() < cull:
			room.queue_free()
		else:
			room.mode = RigidBody2D.MODE_STATIC
			room_positions.append(Vector3(room.position.x, room.position.y, 0))
			
	yield(get_tree(), 'idle_frame')
	#generate a minimun spannig tree connecting the rooms
	path = find_mst(room_positions)

func _draw():
	if start_room:
		draw_string(font, start_room.position - Vector2(125,0),"start",Color(3,4,8))
	if end_room:
		draw_string(font, end_room.position - Vector2(125,0),"end",Color(3,4,8))
	if play_mode:
		return 
	for room in $Rooms.get_children():
		draw_rect(Rect2(room.position - room.size, room.size * 2),
			Color(0, 1, 0), false)
			
	if path:
		for point in path.get_points():
			for connection in path.get_point_connections(point):
				var point_position = path.get_point_position(point)
				var connection_position = path.get_point_position(connection)
				draw_line(Vector2(point_position.x, point_position.y),
					Vector2(connection_position.x, connection_position.y),
					Color(1, 1, 0), 20, true)

func _process(delta):
	update()
	
func _input(event):
	if event.is_action_pressed('ui_select'):
		if play_mode:
			player.queue_free()
			play_mode = false
		for n in $Rooms.get_children():
			n.queue_free()
		path = null
		start_room = null
		end_room = null
		make_rooms()
	if event.is_action_pressed('ui_focus_next'):
		make_map()
	if event.is_action_pressed('ui_cancel'):
		player = Player.instance()
		add_child(player)
		player.position = start_room.position
		play_mode = true
	
func find_mst(nodes):
	# Prim's algorithm
	var path = AStar.new()
	path.add_point(path.get_available_point_id(), nodes.pop_front())
	
	while nodes:
		var min_distance = INF #minimun distance so far
		var min_point = null #position of minimum distance
		var current_position = null
		
		for id in path.get_points():
			var point_from_path = path.get_point_position(id)
			for point_from_nodes in nodes:
				if point_from_path.distance_to(point_from_nodes) < min_distance:
					min_distance = point_from_path.distance_to(point_from_nodes)
					min_point = point_from_nodes
					current_position = point_from_path
		var free_id = path.get_available_point_id()
		path.add_point(free_id, min_point)
		path.connect_points(path.get_closest_point(current_position), free_id)
		nodes.erase(min_point)
	return path
	
func make_map():
	#create TileMap from generated rooms and path
	Map.clear()
	
	#fill tilemap with walls, then carve empty rooms
	var full_rect = Rect2()
	for room in $Rooms.get_children():
		var r = Rect2(room.position - room.size, 
			room.get_node("CollisionShape2D").shape.extents * 2)
			
		full_rect = full_rect.merge(r)
	var topleft = Map.world_to_map(full_rect.position)
	var bottomright = Map.world_to_map(full_rect.end)
	for x in range(topleft.x, bottomright.x):
		for y in range(topleft.y, bottomright.y):
			Map.set_cell(x, y, 1)
	
	#carve rooms
	var corridors = []
	for room in $Rooms.get_children():
		var s = (room.size / tile_size).floor()
		var pos = Map.world_to_map(room.position)
		var ul = (room.position / tile_size).floor() - s
		for x in range(2, s.x * 2 - 1):
			for y in range(2, s.y * 2 - 1):
				Map.set_cell(ul.x + x, ul.y + y, 0)
		
		var p = path.get_closest_point(
			Vector3(room.position.x, room.position.y,0)
		)
		
		for conn in path.get_point_connections(p):
			if not conn in corridors:
				var start = Map.world_to_map(
					Vector2(path.get_point_position(p).x,
						path.get_point_position(p).y))
				var end = Map.world_to_map(
					Vector2(path.get_point_position(conn).x,
						path.get_point_position(conn).y))
				carve_path(start, end)
			corridors.append(p)
			
func carve_path(pos1, pos2):
	#carve a path between two points
	var x_diff = sign(pos2.x - pos1.x)
	var y_diff = sign(pos2.y - pos1.y)
	
	if x_diff == 0: x_diff = pow(-1.0, randi() % 2)
	if y_diff == 0: y_diff = pow(-1.0, randi() % 2)
	
	var x_y = pos1
	var y_x = pos2
	if(randi() % 2) > 0:
		x_y = pos2
		y_x = pos1
		
	for x in range(pos1.x, pos2.x, x_diff):
		Map.set_cell(x, x_y.y, 0)
		Map.set_cell(x, x_y.y+y_diff, 0)
	for y in range(pos1.y, pos2.y, y_diff):
		Map.set_cell(y_x.x, y, 0)
		Map.set_cell(y_x.x+x_diff, y, 0)
	