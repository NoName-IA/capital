# Traducciones

El juego se escribe en español; `scripts/systems/lang.gd` traduce al dibujar con `assets/idiomas/<código>.json`.

- `keys.json`: las frases del juego con su número (no regenerarlo: los números de `tr/` dependen de él).
- `tr/*.json`: traducciones por número → [en].
- `extra.json`: frases agregadas después, por su texto en español → [en].
- `python tools/i18n/merge.py` (desde la carpeta del juego) arma `assets/idiomas/*.json` y revisa los marcadores
  (%s, %d, {p}...). Con `--missing` lista lo que falta.
- Frases nuevas con valores: usar `Lang.f("texto %s", [valor])`; textos fijos se traducen solos al dibujarse.
  Para una frase nueva, agregarla a `extra.json` con su traducción al inglés.
- En las traducciones, `%2$s` usa el segundo valor y `%_` se salta uno (plurales con "s").
