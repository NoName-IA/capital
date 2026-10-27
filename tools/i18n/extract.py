"""Junta todas las frases visibles del juego (en español) en i18n_keys.json: [[id, frase, archivo], ...]."""
import os, re, glob, json, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lits import lits, disp

SKIP_FILES = {"scripts/economy/fmt.gd", "scripts/systems/lang.gd"}
# Textos que no se ven (nombres de nodos, fuentes, acciones, etc.)
NOT_SHOWN = {"Segoe UI", "Arial", "sans-serif", "Head", "Calle", "Capital"}

out = []
seen = set()
for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
    fn = f.replace(chr(92), "/")
    if fn in SKIP_FILES:
        continue
    s = open(f, encoding="utf-8").read()
    for pos, l, q in lits(s):
        if not disp(l) or l in seen or l in NOT_SHOWN:
            continue
        line_start = s.rfind("\n", 0, pos) + 1
        line = s[line_start:s.find("\n", pos)]
        if "print(" in line or "push_warning" in line or "push_error" in line or "get_node(" in line \
                or "has_method(" in line or "call(\"" in line and l in line.split("call(\"")[1][:len(l) + 1]:
            continue
        if re.fullmatch(r"[A-Z][a-z]+[A-Z][A-Za-z]*", l):   # NombresDeClase
            continue
        seen.add(l)
        out.append([len(out), l, fn])
sys.stdout.reconfigure(encoding="utf-8")
json.dump(out, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(out), sum(len(o[1]) for o in out))
