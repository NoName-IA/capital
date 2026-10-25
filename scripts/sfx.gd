class_name Sfx
extends Node
## Efectos de sonido, latido de peligro y música (tranquila y tensa, que se mezclan según el riesgo de quiebra).

const NAMES := ["coin", "angry", "fanfare", "record", "good", "bad", "rival", "ring", "month"]
const MUSIC_VOLUME := 0.35

var clips := {}
var players: Array[AudioStreamPlayer] = []
var next_ok := {}
var heart: AudioStreamPlayer
var music: AudioStreamPlayer
var tension: AudioStreamPlayer
var music_on := true
var danger := 0.0
var music_volume := 0.7
var effects_volume := 0.8


func _ready() -> void:
	for n in NAMES:
		clips[n] = load("res://sonidos/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	heart = _looping("heartbeat")
	music = _looping("musica")
	tension = _looping("tension")
	music.volume_db = linear_to_db(0.0001)
	tension.volume_db = linear_to_db(0.0001)
	heart.volume_db = linear_to_db(0.0001)
	music.play()
	tension.play()


func _looping(name: String) -> AudioStreamPlayer:
	var s: AudioStreamWAV = load("res://sonidos/%s.wav" % name).duplicate()
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


## Pasa suavemente de la música tranquila a la tensa según el peligro (0 a 1).
func update_music(level: float, dt: float) -> void:
	danger += (level - danger) * min(1.0, dt * 1.5)
	var on := MUSIC_VOLUME * music_volume * 1.4 if music_on else 0.0
	music.volume_db = linear_to_db(max(0.0001, on * (1 - danger)))
	tension.volume_db = linear_to_db(max(0.0001, on * danger))
