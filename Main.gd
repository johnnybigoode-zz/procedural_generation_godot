extends Node2D

var Room = preload("res://Room.tscn")

var tile_size = 32
var num_rooms = 50
var min_size = 4
var max_size = 10
var hspread = 400 #how horizontal should be the rooms - in pixels
var cull = 0.5 #percent of rooms to be removed

var path # AStar pathfinding object
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
	for room in $Rooms.get_children():
		draw_rect(Rect2(room.position - room.size, room.size * 2),
			Color(32, 228, 0), false)
			
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
		for n in $Rooms.get_children():
			n.queue_free()
		path = null
		make_rooms()
	
		
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
		