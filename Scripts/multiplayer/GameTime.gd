extends Node

var _server_time_offset : int

const NUMBER_OF_PACKETS_PER_SYNC : int = 10
var _synced_time_packets : Array[Dictionary]
var _sync_in_progress : bool

var GameTime : float :
	get: return (Time.get_ticks_msec() + _server_time_offset) / 1000.0

var _seconds_to_physics_sync : float = 10

var _physics_sync_base_times : PackedFloat32Array
var _physics_sync_base_times_ring_index : int
var _last_physics_process_time : float
var _physics_frame_num : int
var PhysicsFrame : int :
	get: return _physics_frame_num


var _interval_tick_timers : Dictionary = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -1
	multiplayer.connected_to_server.connect(on_connected_to_server)
	_physics_sync_base_times.resize(10)
	_physics_sync_base_times.fill(GameTime)
	#add_child(load("res://Scripts/GameTimeViz.tscn").instantiate())


func _physics_process(_delta: float) -> void:
	_physics_frame_num += 1
	var current_time := GameTime
	if current_time - _last_physics_process_time > get_physics_process_delta_time() * 0.8:
		var time_of_first_physics_frame : float = GameTime - _physics_frame_num * get_physics_process_delta_time()
		_physics_sync_base_times[_physics_sync_base_times_ring_index] = time_of_first_physics_frame
		_physics_sync_base_times_ring_index += 1
		if _physics_sync_base_times_ring_index >= _physics_sync_base_times.size():
			_physics_sync_base_times_ring_index = 0


func on_connected_to_server():
	send_sync_request()


func send_sync_request():
	if _sync_in_progress:
		printerr("A time sync is currently in progress! Can't start a new one.")
		return
	_sync_in_progress = true
	var current_time : int
	for i in NUMBER_OF_PACKETS_PER_SYNC:
		current_time = Time.get_ticks_msec()
		sync_request.rpc_id(1, current_time)
		await get_tree().create_timer(0.2).timeout

	await get_tree().create_timer(0.5).timeout
	current_time = Time.get_ticks_msec()
	if _synced_time_packets.is_empty():
		printerr("could not sync the game_time!")
		_sync_in_progress = false
		return
	var server_time_sum : int = 0
	for sync_packet in _synced_time_packets:
		var packet_server_time : int = sync_packet.server_time + (current_time - sync_packet.received_time)
		server_time_sum += packet_server_time
	@warning_ignore("integer_division")
	var estimated_server_time : int = server_time_sum / _synced_time_packets.size()
	_server_time_offset = estimated_server_time - current_time
	CompositeNode.SetGameTimeServerOffset(_server_time_offset)
	_synced_time_packets.clear()
	_sync_in_progress = false
	print("time sync done. game_time: %s" % GameTime)


@rpc("any_peer")
func sync_request(own_time_code:int):
	var sender_id := multiplayer.get_remote_sender_id()
	sync_request_answer.rpc_id(sender_id, own_time_code, Time.get_ticks_msec())


@rpc("any_peer")
func sync_request_answer(own_time_code:int, server_game_time:int):
	var current_time : int = Time.get_ticks_msec()
	var time_since_sent : float = (current_time - own_time_code) / 1000.0
	var estimated_server_time : int = server_game_time + int((time_since_sent / 2.0) * 1000)
	if _server_time_offset == 0:
		# the local game time hasn't been updated at all, yet. so
		# even the first estimate is way better!
		_server_time_offset = estimated_server_time - current_time
		CompositeNode.SetGameTimeServerOffset(_server_time_offset)
	_synced_time_packets.append({
		"server_time" : estimated_server_time,
		"received_time" : current_time
	})

@rpc("any_peer")
func physics_frame_sync(physics_sync_base_time:float):
	_physics_frame_num = floori((GameTime - physics_sync_base_time) / get_physics_process_delta_time())

func _process(delta:float):
	for timer in _interval_tick_timers.values():
		timer.update()
	if multiplayer.is_server():
		_seconds_to_physics_sync -= delta
		if _seconds_to_physics_sync <= 0:
			_seconds_to_physics_sync += 5
			var sum : float = 0
			for t in _physics_sync_base_times: sum += t
			sum /= _physics_sync_base_times.size()
			physics_frame_sync.rpc(sum)


func get_interval_timer(interval : float) -> IntervalTickTimer:
	var timer = _interval_tick_timers.get(interval)
	if not timer:
		timer = IntervalTickTimer.new(interval)
		_interval_tick_timers.set(interval, timer)
	return timer


class IntervalTickTimer extends RefCounted:
	var _interval : float
	var _next_tick_time : float
	signal tick

	func _init(init_interval : float) -> void:
		_interval = init_interval
		_next_tick_time = GameTime.GameTime + _interval

	func update():
		if _next_tick_time <= GameTime.GameTime:
			_next_tick_time += _interval
			tick.emit()
