import re, glob, sys

BS = chr(92)


def lits(s):
    """Lista de (posición, contenido, largo de comillas) de cada string de GDScript, saltando comentarios."""
    out = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == '#':
            j = s.find('\n', i)
            i = n if j < 0 else j
            continue
        if c in '"\'':
            if s.startswith(c * 3, i):
                j = s.find(c * 3, i + 3)
                out.append((i, s[i + 3:j], 3))
                i = j + 3
                continue
            j = i + 1
            while s[j] != c:
                j += 2 if s[j] == BS else 1
            out.append((i, s[i + 1:j], 1))
            i = j + 1
            continue
        i += 1
    return out


def disp(l):
    if re.fullmatch(r'(res|user)://.*|[a-z0-9_./:-]*|%[^ ]*|#?[0-9a-fA-F]+', l):
        return False
    return bool(re.search(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]', l))


if __name__ == "__main__":
    tot = 0
    uniq = set()
    rows = []
    for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
        s = open(f, encoding="utf-8").read()
        d = [l for _, l, _ in lits(s) if disp(l)]
        uniq |= set(d)
        tot += len(d)
        rows.append((len(d), f))
    for r in sorted(rows, reverse=True):
        print(*r)
    print("total", tot, "unique", len(uniq), "chars", sum(len(u) for u in uniq))
