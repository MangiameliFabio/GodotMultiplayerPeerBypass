extends CompositeNode

class_name Game

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.GameInstance = self

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func initialize_game():
	pass

func start_game():
	pass
