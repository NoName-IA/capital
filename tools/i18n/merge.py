"""Junta las tandas tr/*.json en assets/idiomas/<código>.json y revisa los marcadores."""
import json, glob, re, sys, os
sys.stdout.reconfigure(encoding="utf-8")
SP = os.path.dirname(os.path.abspath(__file__))
CODES = ["en", "zh", "ru", "pt", "de"]
BS = chr(92)
SPEC = re.compile(r"%(?:(\d+)\$)?[-+0#]*\d*(?:\.\d+)?([sdifxXc_%])")
BRACES = re.compile(r"\{[a-z]*\}")


def unescape(s):
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == BS and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", BS: BS}.get(n, BS + n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def args_used(s):
    """Cuántos valores consume la plantilla (los %% no cuentan)."""
    seq = 0
    top = 0
    for m in SPEC.finditer(s):
        if m.group(2) == "%":
            continue
        if m.group(1):
            top = max(top, int(m.group(1)))
        else:
            seq += 1
    return max(seq, top)


keys = {k[0]: k[1] for k in json.load(open(os.path.join(SP, "keys.json"), encoding="utf-8"))}
out = {c: {} for c in CODES}
problems = 0
done = set()
for f in sorted(glob.glob(os.path.join(SP, "tr", "*.json"))):
    data = json.load(open(f, encoding="utf-8"))
    for sid, vals in data.items():
        i = int(sid)
        src = unescape(keys[i])
        done.add(i)
        if len(vals) != len(CODES):
            print("FALTAN IDIOMAS", i, src[:50])
            problems += 1
            continue
        want = args_used(src)
        braces = sorted(BRACES.findall(src))
        for c, v in zip(CODES, vals):
            if "%" in src and args_used(v) != want and "%%" in src + v or ("%" in src and args_used(v) != want and want > 0):
                print("MARCADORES", c, i, repr(src[:60]), "->", repr(v[:60]))
                problems += 1
            if sorted(BRACES.findall(v)) != braces:
                print("LLAVES", c, i, repr(src[:60]), "->", repr(v[:60]))
                problems += 1
            out[c][src] = v
extra = json.load(open(os.path.join(SP, "extra.json"), encoding="utf-8"))   # frases nuevas, por su texto en español
for src, vals in extra.items():
    for c, v in zip(CODES, vals):
        if args_used(v) != args_used(src):
            print("MARCADORES extra", c, repr(src[:60]))
            problems += 1
        out[c][src] = v
os.makedirs("assets/idiomas", exist_ok=True)
for c in CODES:
    json.dump(out[c], open("assets/idiomas/%s.json" % c, "w", encoding="utf-8", newline="\n"), ensure_ascii=False,
            indent=0, sort_keys=True)
missing = [i for i in keys if i not in done]
print("traducidas", len(done), "de", len(keys), "· problemas", problems)
if "--missing" in sys.argv:
    for i in missing:
        print(i, keys[i])
