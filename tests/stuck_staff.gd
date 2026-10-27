extends RefCounted
## Empleados trabados: locales llenos de gente caminando un buen rato; cuenta cuántos se quedan quietos con una
## tarea a medio caminar (antes se quedaban uno frente al otro o girando en el lugar).

func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	var g: Game = m.app.game
	g.next_choice_day = 100000
	g.cash += 5000000
	for i in 6:
		g.open_location(["cafe", "burger", "cafe"][i % 3], 1 if i < 3 else 2)
	for l in g.locations:
		l.employees = 30
	await m.frames(10)
	for s in c.stores.values():
		s.sync_staff()
	m.app.paused = false
	var still := {}       # persona -> segundos caminando sin avanzar
	var worst := 0.0
	var events := 0
	var last := {}
	for f in 3600:
		await m.frames(1)
		for s in c.stores.values():
			for p in s.staff:
				var job = s.jobs.get(p)
				var walking: bool = job != null and job.steps[job.i].to != null and not job.get("arrived", false)
				var moved: float = (p.position - last.get(p, p.position)).length()
				last[p] = p.position
				if walking and moved < 0.001:
					still[p] = still.get(p, 0.0) + 1.0 / 60.0
					if still[p] > 6.0 and still[p] - 1.0 / 60.0 <= 6.0:
						events += 1
						var nx = job.path[0] if job.has("path") and not job.path.is_empty() else null
						var dirv = (nx - p.position) if nx != null else Vector3.ZERO
						print("  trabado: tam ", s.loc.size, " pos ", p.position.snappedf(0.01), " sig ", nx, " meta ", job.get("goal"),
								" bloq ", snappedf(job.get("blocked", 0.0), 0.01), " pasa ", snappedf(job.get("pass", 0.0), 0.01),
								" giro ", snappedf(absf(wrapf(atan2(dirv.x, dirv.z) - p.rotation.y, -PI, PI)), 0.01),
								" paso ", job.steps[job.i].do, " sirviendo ", snappedf(p.serve_t, 0.01), " largo ", job.path.size() if job.has("path") else -1)
					worst = maxf(worst, still[p])
				else:
					still[p] = 0.0
	var n := 0
	for s in c.stores.values():
		n += s.staff.size()
	print("STAFF ", n, " · trabados >6 s: ", events, " · peor espera: ", snappedf(worst, 0.1), " s")
