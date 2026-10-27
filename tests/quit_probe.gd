extends RefCounted
## Abre el juego, espera un poco y sale: el juego tiene que cerrarse sin caerse (código de salida 0).

func run(m) -> void:
	await m.frames(120)
