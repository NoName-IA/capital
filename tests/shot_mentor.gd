extends RefCounted
## El mentor del tutorial (tu personaje ya millonario) hablando en la ciudad y con la tablet abierta.
## Godot --path . -- --scenario=res://tests/shot_mentor.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", false)
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.start()
	await m.frames(90)   # que salga la foto y se escriba la frase
	await m.shot(ProjectSettings.globalize_path(OUT + "mentor_1.png"))
	print("hablando: ", c.tutorial.talking(), " · frase ", c.tutorial.talk_i)
	var p0 := c.player.position
	c.tutorial.advance()
	c.tutorial.advance()
	await m.frames(20)
	print("hablando después de 2 Enter: ", c.tutorial.talking(), " · se movió: ", c.player.position.distance_to(p0) > 0.01)
	c.player.position += Vector3(6, 0, 0)
	await m.frames(40)
	print("paso: ", Tutorial.STEPS[c.tutorial.step], " · hablando: ", c.tutorial.talking())
	await m.shot(ProjectSettings.globalize_path(OUT + "mentor_2.png"))
	# Con la tablet abierta
	c.tutorial.start(5)   # precio
	c.overlays.show("admin")
	await m.frames(60)
	await m.shot(ProjectSettings.globalize_path(OUT + "mentor_tablet.png"))
	print("tablet: hablando ", c.tutorial.talking(), " paso ", Tutorial.STEPS[c.tutorial.step], " guardado ", g.tutorial_step)
	c.tutorial.stop()
