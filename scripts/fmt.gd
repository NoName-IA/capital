class_name Fmt
## Números como se escriben en español: punto para los miles y coma para los decimales.


## 1234567.891 con 2 decimales -> "1.234.567,89"
static func num(x: float, decimals := 0) -> String:
	var neg := x < 0
	x = absf(x)
	var s := ("%." + str(decimals) + "f") % x
	var parts := s.split(".")
	var whole: String = parts[0]
	var out := ""
	var count := 0
	for i in range(whole.length() - 1, -1, -1):
		out = whole[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	if decimals > 0:
		out += "," + parts[1]
	return ("-" if neg and out.replace("0", "").replace(".", "").replace(",", "") != "" else "") + out


## $1.234.567 (o $1,23 M desde un millón).
static func money(x: float, decimals := 0) -> String:
	var sign := "-" if x < 0 else ""
	x = absf(x)
	if decimals == 0 and x >= 1e6:
		return "%s$%s M" % [sign, num(x / 1e6, 2)]
	return "%s$%s" % [sign, num(x, decimals)]


## 0.125 -> "12,5%"
static func pct(x: float, decimals := 1) -> String:
	return num(x * 100.0, decimals) + "%"


## Montos cortos para botones y tarjetas: $950, $2,5 k, $45 k, $1,2 M, $1.000 M.
static func short(x: float) -> String:
	var sign := "-" if x < 0 else ""
	x = absf(x)
	if x >= 1e8:
		return "%s$%s M" % [sign, num(x / 1e6)]
	if x >= 1e6:
		return "%s$%s M" % [sign, num(x / 1e6, 1)]
	if x >= 1e4:
		return "%s$%s k" % [sign, num(x / 1e3)]
	if x >= 1e3:
		var k := ("%.1f" % (x / 1e3)).rstrip("0").rstrip(".").replace(".", ",")
		return "%s$%s k" % [sign, k]
	return "%s$%s" % [sign, num(x)]
