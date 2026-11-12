extends RefCounted
## La alfombra persa del vestíbulo de la oficina (sin mostrador en el medio), en el garaje y en la torre de lujo.
## Godot --path . -- --scenario=res://tests/shot_office_rug.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", true)
	await m.frames(5)
	c.tutorial.stop()
	m.app.paused = true
	for tier in [0, 3]:
		m.app.game.office_look = tier
		c.set_office_look(tier)
		await m.frames(3)
		c.first_person = true
		c.player.position = Blueprints.to_world(City.HQ, 0, 2.6)
		c.yaw = 0.0
		c.pitch = 30.0
		c.player.rotation.y = 0.0
		await m.frames(20)
		await m.shot(ProjectSettings.globalize_path("res://tests/shots/alfombra_oficina_%d.png" % tier))
