extends RefCounted
## Imprime los rectángulos de los centros comerciales, las fábricas y la oficina (para ubicar la red eléctrica).
func run(m) -> void:
	var c: City = m.city
	for i in 2:
		print("mall ", i, ": ", Mall.world_rect(i))
	for k in WorldBuilder.FACTORY_X:
		print("fábrica ", k, ": ", c.builder.factory_rect(k))
	print("hq: ", c.hq.spots.get("ceiling"))
	for p in [[-80, 1], [-55, 1], [121, -1], [99, -1]]:
		print("terreno ", p, ": ", Blueprints.plot_xf(p).origin)
