"""Efectos de sonido de la cinemática del final (Finale), hechos con matemática (sin grabaciones):

  fin_tono     · el teléfono: dos notas suaves de campana, como un teléfono moderno
  fin_golpe    · el golpe grave del título del capítulo (con eco largo)
  fin_campana  · la campanita del ascensor (dos notas, «ding-dong»)
  fin_puertas  · las puertas del ascensor deslizándose (soplido suave)
  fin_obturador· el obturador de la cámara de fotos (dos clics y un zumbido corto)
  fin_giro     · el diario girando (soplido que sube)
  fin_impacto  · el diario cayendo: golpe grave con un brillo arriba

Uso: python tools/sonidos_final.py  (escribe los .wav en assets/sonidos)
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sonidos")


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    k = 0.85 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))
    print(name, round(len(samples) / RATE, 2), "s")


def env(t, attack, decay):
    return min(1.0, t / attack) * math.exp(-t / decay) if attack > 0 else math.exp(-t / decay)


def bell(f, t, decay):
    # campana: fundamental y parciales inarmónicos que se apagan más rápido
    return (math.sin(2 * math.pi * f * t) * env(t, 0.004, decay)
            + 0.45 * math.sin(2 * math.pi * f * 2.76 * t) * env(t, 0.002, decay * 0.45)
            + 0.25 * math.sin(2 * math.pi * f * 5.4 * t) * env(t, 0.001, decay * 0.25))


def noise_filtered(n, cutoff_fn, seed=1):
    random.seed(seed)
    out, y = [], 0.0
    for i in range(n):
        a = min(1.0, cutoff_fn(i / RATE))
        y += a * (random.uniform(-1, 1) - y)
        out.append(y)
    return out


def tono():
    n = int(RATE * 2.2)
    out = []
    for i in range(n):
        t = i / RATE
        s = bell(880, t, 0.5) + (bell(1318.5, t - 0.22, 0.55) if t > 0.22 else 0)
        s += 0.6 * ((bell(880, t - 1.1, 0.5) if t > 1.1 else 0) + (bell(1318.5, t - 1.32, 0.55) if t > 1.32 else 0))
        out.append(s)
    return out


def golpe():
    n = int(RATE * 3.2)
    noise = noise_filtered(n, lambda t: 0.02)
    out = []
    for i in range(n):
        t = i / RATE
        f = 48 + 30 * math.exp(-t * 6)
        s = math.sin(2 * math.pi * f * t) * env(t, 0.005, 0.9)
        s += 0.35 * math.sin(2 * math.pi * 96 * t) * env(t, 0.01, 0.5)
        s += 0.5 * noise[i] * env(t, 0.002, 0.25)
        for d, g in [(0.35, 0.3), (0.7, 0.15)]:   # eco
            if t > d:
                td = t - d
                s += g * math.sin(2 * math.pi * 48 * td) * env(td, 0.005, 0.7)
        out.append(s)
    return out


def campana():
    n = int(RATE * 2.0)
    return [bell(1046.5, i / RATE, 0.7) + (bell(830.6, i / RATE - 0.32, 0.9) if i / RATE > 0.32 else 0) for i in range(n)]


def puertas():
    n = int(RATE * 1.1)
    noise = noise_filtered(n, lambda t: 0.04 + 0.05 * math.sin(math.pi * t / 1.1), seed=3)
    out = []
    for i in range(n):
        t = i / RATE
        e = math.sin(math.pi * min(1.0, t / 1.1)) ** 1.5
        out.append(noise[i] * e + 0.08 * math.sin(2 * math.pi * 70 * t) * e)
    return out


def obturador():
    n = int(RATE * 0.5)
    noise = noise_filtered(n, lambda t: 0.6, seed=5)
    out = []
    for i in range(n):
        t = i / RATE
        s = noise[i] * (env(t, 0.0005, 0.012) + (env(t - 0.09, 0.0005, 0.018) if t > 0.09 else 0))
        s += 0.25 * math.sin(2 * math.pi * 2400 * t) * (env(t - 0.02, 0.002, 0.03) if t > 0.02 else 0)
        out.append(s)
    return out


def giro():
    n = int(RATE * 1.15)
    noise = noise_filtered(n, lambda t: 0.02 + 0.25 * (t / 1.15) ** 2, seed=7)
    out = []
    for i in range(n):
        t = i / RATE
        e = (t / 1.15) ** 1.6
        wob = 0.6 + 0.4 * math.sin(2 * math.pi * (3 + 9 * t) * t)   # aleteo del papel girando
        out.append(noise[i] * e * wob)
    return out


def impacto():
    n = int(RATE * 2.4)
    noise = noise_filtered(n, lambda t: 0.3 * math.exp(-t * 8) + 0.02, seed=9)
    out = []
    for i in range(n):
        t = i / RATE
        f = 55 + 60 * math.exp(-t * 18)
        s = 1.2 * math.sin(2 * math.pi * f * t) * env(t, 0.002, 0.45)
        s += 0.7 * noise[i] * env(t, 0.001, 0.08)
        s += 0.18 * bell(1567.98, t, 1.1)   # el brillo arriba
        out.append(s)
    return out


if __name__ == "__main__":
    for name, fn in [("fin_tono", tono), ("fin_golpe", golpe), ("fin_campana", campana), ("fin_puertas", puertas),
                     ("fin_obturador", obturador), ("fin_giro", giro), ("fin_impacto", impacto)]:
        write(name, fn())
