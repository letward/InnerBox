extends Node
## Sound effects and music.
##
## One AudioStreamPlayer per SFX voice (round-robin) so overlapping hits do not
## cut each other off, plus two music players for a crossfade between tracks.

const SFX_VOICES := 8
const AUDIO_DIR := "res://assets/audio/"

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _cache: Dictionary = {}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_on := false
var _current_track := ""
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_music_a = _make_music_player("MusicA")
	_music_b = _make_music_player("MusicB")


func _make_music_player(_label: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p


func _get_stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := AUDIO_DIR + name
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	if s is AudioStreamWAV:
		# loop seamlessly: the generator composes whole bars
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = 0
	_cache[name] = s
	return s


# --------------------------------------------------------------------------
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := _get_stream(name + ".wav")
	if s == null:
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_VOICES
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func music(track: String, fade: float = 0.8) -> void:
	if track == _current_track and _music_a.playing:
		return
	var file := "music_" + track + ".wav"
	var s := _get_stream(file)
	if s == null:
		return
	var incoming: AudioStreamPlayer
	var outgoing: AudioStreamPlayer
	if _music_a.playing and not _music_a.stopped:
		incoming = _music_b
		outgoing = _music_a
	elif _music_b.playing:
		incoming = _music_a
		outgoing = _music_b
	else:
		incoming = _music_a
		outgoing = _music_b
	incoming.stream = s
	incoming.volume_db = -40.0
	incoming.play()
	_current_track = track
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", -6.0, fade)
	if outgoing.playing:
		_fade_tween.tween_property(outgoing, "volume_db", -40.0, fade)
		_fade_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = 0.5) -> void:
	_current_track = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, fade)
			tw.tween_callback(p.stop)


func set_music_enabled(on: bool) -> void:
	_music_on = on
	if not on:
		stop_music()
	elif _current_track != "":
		music(_current_track)


func is_music_enabled() -> bool:
	return _music_on


func set_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(linear, 0.0001, 1.0)))
