extends KinematicBody2D

export var id = 0
export var speed = 250

var velocity = Vector2()

#remove print statements

func _ready():
	print("Player spawned")

func _input(event):
	if event.is_action_pressed('scroll_up'):
		$Camera2D.zoom = $Camera2D.zoom - Vector2(0.1, 0.1)
	if event.is_action_pressed('scroll_down'):
		$Camera2D.zoom = $Camera2D.zoom + Vector2(0.1, 0.1)

func print_pos():
	print(get_node("/root/Main/TileMap").world_to_map(self.position))

func get_input():	
	velocity = Vector2()
	if Input.is_action_pressed('ui_right'):
		velocity.x += 1
		print_pos()
	if Input.is_action_pressed('ui_left'):
		velocity.x -= 1
		print_pos()
	if Input.is_action_pressed('ui_up'):
		velocity.y -= 1
		print_pos()
	if Input.is_action_pressed('ui_down'):
		velocity.y += 1
		print_pos()
	velocity = velocity.normalized() * speed

func _physics_process(delta):
	get_input()
	velocity = move_and_slide(velocity)
