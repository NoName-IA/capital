"""Convierte  "texto %s" % ARGS  en  Lang.f("texto %s", ARGS)  en los .gd del juego."""
import os, re, glob, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lits import lits, disp

SKIP = {"scripts/economy/fmt.gd", "scripts/systems/lang.gd"}
OPEN = {"(": ")", "[": "]", "{": "}"}
BS = chr(92)


def skip_string(s, i):
    q = s[i]
    if s.startswith(q * 3, i):
        return s.find(q * 3, i + 3) + 3
    j = i + 1
    while s[j] != q:
        j += 2 if s[j] == BS else 1
    return j + 1


def match_close(s, i):
    """i apunta a ( [ o {: devuelve el índice después del cierre."""
    stack = [OPEN[s[i]]]
    j = i + 1
    while stack:
        c = s[j]
        if c in "\"'":
            j = skip_string(s, j)
            continue
        if c == "#":
            j = s.find("\n", j)
            continue
        if c in OPEN:
            stack.append(OPEN[c])
        elif c == stack[-1]:
            stack.pop()
        j += 1
    return j


def operand_end(s, i):
    """Fin de la expresión que sigue al operador % (una expresión "postfija": nombre.campo(...)[...], (…), […], número o string)."""
    if s[i] in "[(":
        j = match_close(s, i)
    elif s[i] in "\"'":
        j = skip_string(s, i)
    else:
        m = re.match(r"-?[A-Za-z0-9_]+(\.[0-9]+)?", s[i:])
        if not m:
            raise ValueError("operando raro: " + s[i:i + 30])
        j = i + m.end()
    while j < len(s):
        if s[j] == "." and re.match(r"\.[A-Za-z_]", s[j:j + 2]):
            m = re.match(r"\.[A-Za-z_][A-Za-z0-9_]*", s[j:])
            j += m.end()
        elif s[j] in "([":
            j = match_close(s, j)
        else:
            break
    return j


def transform(s):
    out = []
    last = 0
    count = 0
    for pos, l, q in lits(s):
        if pos < last or not disp(l) or q != 1:
            continue
        end = pos + len(l) + 2
        m = re.match(r"[ \t]*%[ \t]*", s[end:])
        if not m or s[end + m.end() - 1] == "=":
            continue
        line_start = s.rfind("\n", 0, pos) + 1
        if "print(" in s[line_start:pos] or "push_warning(" in s[line_start:pos] or "push_error(" in s[line_start:pos]:
            continue
        a = end + m.end()
        b = operand_end(s, a)
        out.append(s[last:pos])
        out.append("Lang.f(" + s[pos:end] + ", " + s[a:b] + ")")
        last = b
        count += 1
    out.append(s[last:])
    return "".join(out), count


if __name__ == "__main__":
    total = 0
    for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
        if f.replace(chr(92), "/") in SKIP:
            continue
        s = open(f, encoding="utf-8", newline="").read()
        t, n = transform(s)
        if n:
            open(f, "w", encoding="utf-8", newline="").write(t)
            print(n, f)
            total += n
    print("total", total)
