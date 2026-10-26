class_name Sfx
extends Node
## Efectos de sonido, latido de peligro y música: una lista de canciones en orden aleatorio (sin repetir la última),
## con un fundido entre una y otra. Con riesgo de quiebra la música baja para que se oiga el latido.

const NAMES := ["coin", "angry", "fanfare", "record", "good", "bad", "rival", "ring", "month", "hover", "select"]
const MUSIC_VOLUME := 0.35
const FADE := 2.5   # segundos de fundido al terminar una canción y empezar la otra
## [archivo en assets/sonidos/musica, título, artista] (los créditos se ven en el botón de info del juego)
const SONGS := [["rain", "Rain", "Royalty free"], ["biscuit", "biscuit", "LuKremBo"],
		["bread", "bread", "LuKremBo"], ["chocolate", "chocolate", "LuKremBo"], ["onion", "onion", "LuKremBo"]]

var clips := {}
var players: Array[AudioStreamPlayer] = []
var next_ok := {}
var heart: AudioStreamPlayer
var music: AudioStreamPlayer
var song := -1          # índice en SONGS de la que suena
var queue: Array[int] = []
var fade := 1.0         # 0 a 1: fundido de entrada y salida de cada canción
var music_on := true
var danger := 0.0
var music_volume := 0.7
var effects_volume := 0.8


func _ready() -> void:
	for n in NAMES:
		clips[n] = load("res://assets/sonidos/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	heart = _looping("heartbeat")
	music = AudioStreamPlayer.new()
	add_child(music)
	music.volume_db = linear_to_db(0.0001)
	heart.volume_db = linear_to_db(0.0001)
	next_song()


## Pasa a la próxima canción de la lista. Cuando se acaba la lista se baraja de nuevo, sin que la primera sea la
## misma que acaba de sonar.
func next_song() -> void:
	if queue.is_empty():
		for i in SONGS.size():
			queue.append(i)
		queue.shuffle()
		if queue.size() > 1 and queue[0] == song:
			queue.append(queue.pop_front())
	song = queue.pop_front()
	music.stream = load("res://assets/sonidos/musica/%s.mp3" % SONGS[song][0])
	fade = 0.0
	music.play()


func now_playing() -> Array:
	return SONGS[song] if song >= 0 else []


func _looping(name: String) -> AudioStreamPlayer:
	var s: AudioStreamWAV = load("res://assets/sonidos/%s.wav" % name).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	add_child(p)
	return p


func play(name: String, volume := 1.0, pitch := 1.0) -> void:
	var clip = clips.get(name)
	var now := Time.get_ticks_msec()
	volume *= effects_volume * 1.25
	if clip == null or volume < 0.03 or now < next_ok.get(name, 0):
		return
	next_ok[name] = now + 70
	for p in players:
		if not p.playing:
			p.stream = clip
			p.volume_db = linear_to_db(volume)
			p.pitch_scale = pitch
			p.play()
			return


func heartbeat(volume: float, pitch: float) -> void:
	if volume > 0 and not heart.playing:
		heart.play()
	heart.volume_db = linear_to_db(max(0.0001, volume * effects_volume))
	heart.pitch_scale = pitch


## Volumen de la música: fundido al empezar y al terminar cada canción, y más bajo según el peligro (0 a 1).
func update_music(level: float, dt: float) -> void:
	danger += (level - danger) * min(1.0, dt * 1.5)
	var left := music.stream.get_length() - music.get_playback_position() if music.playing else 0.0
	if not music.playing or left < 0.05:
		next_song()
		left = music.stream.get_length()
	fade = minf(1.0, fade + dt / FADE)
	var k := minf(fade, clampf(left / FADE, 0.0, 1.0))
	var on := MUSIC_VOLUME * music_volume * 1.4 if music_on else 0.0
	music.volume_db = linear_to_db(max(0.0001, on * k * (1 - 0.6 * danger)))
