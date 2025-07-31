class_name PlayerVoip extends Node

# since the refactoring of the VoIPConnection system, this class
# only forwards the respective voip calls to the VoIPConnection on
# the MultiplayerConnectionHandler (only one VoIPConnection Object
# exists, not one per peer!)

var _lobby_audiostreamplayer : AudioStreamPlayer
var _voip_peer_id : int = 0

func activate_lobby_output():
	if is_multiplayer_authority():
		return
	if _lobby_audiostreamplayer:
		printerr("can't activate lobby audiostreamplayer, it already is active?")
		return
	_lobby_audiostreamplayer = AudioStreamPlayer.new()
	add_child(_lobby_audiostreamplayer)

	# the voip peer might not have been set, yet (has to be
	# synchronized via the main connection!)
	while _voip_peer_id == 0:
		await get_tree().process_frame
	Global.ConnectionHandler.voip_connection.play_peer_on_audio_stream_player(_voip_peer_id, _lobby_audiostreamplayer)

func deactivate_lobby_output():
	if is_multiplayer_authority():
		return
	if _lobby_audiostreamplayer:
		if _voip_peer_id != 0:
			Global.ConnectionHandler.voip_connection.stop_peer_on_audio_stream_player(_lobby_audiostreamplayer)
		_lobby_audiostreamplayer.queue_free()
		_lobby_audiostreamplayer = null

func activate_output_on_audiostream(audiostream:AudioStreamPlayer3D):
	Global.ConnectionHandler.voip_connection.play_peer_on_audio_stream_player_3d(_voip_peer_id, audiostream)

func deactivate_output_on_audiostream(audiostream:AudioStreamPlayer3D):
	Global.ConnectionHandler.voip_connection.stop_peer_on_audio_stream_player(audiostream)
