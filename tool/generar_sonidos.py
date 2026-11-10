#!/usr/bin/env python3
"""Genera los sonidos ORIGINALES de la app (sintetizados, sin muestras externas).

Uso:  python3 tool/generar_sonidos.py
Escribe WAV mono de 16 bits a 22050 Hz en assets/sonidos/:
  - miau.wav      maullido sintético (glissando con armónicos tipo formante)
  - ronroneo.wav  ronroneo grave modulado a ~25 Hz, 1.5 s, apto para bucle
  - trino.wav     chirrido/trino de pajarito
  - pop.wav       "pop" corto para cuando el michi atrapa algo
Solo usa la biblioteca estándar (wave, math, random, struct).
"""

import math
import os
import random
import struct
import wave

TASA = 22050
CARPETA = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sonidos"
)


def guardar(nombre, muestras):
    pico = max(1e-9, max(abs(m) for m in muestras))
    escala = 0.85 / pico
    ruta = os.path.normpath(os.path.join(CARPETA, nombre))
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TASA)
        datos = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, m * escala)) * 32767))
            for m in muestras
        )
        w.writeframes(datos)
    print(f"{ruta}: {len(muestras) / TASA:.2f} s, {os.path.getsize(ruta)} bytes")


def suavizar(t, duracion, ataque, caida):
    """Envolvente con ataque y caída senoidales."""
    if t < ataque:
        return math.sin(0.5 * math.pi * t / ataque)
    if t > duracion - caida:
        return max(0.0, math.sin(0.5 * math.pi * (duracion - t) / caida))
    return 1.0


def miau():
    dur = 0.75
    n = int(TASA * dur)
    fase = 0.0
    out = []
    for i in range(n):
        t = i / TASA
        x = t / dur
        # "mi-a-u": sube rápido, se mantiene y baja.
        f0 = 480 + 380 * math.sin(math.pi * min(1.0, x * 1.4)) - 120 * x
        f0 *= 1 + 0.012 * math.sin(2 * math.pi * 6 * t)  # vibrato
        fase += 2 * math.pi * f0 / TASA
        # Formante que se abre ("a") y luego se cierra ("u").
        brillo = 0.25 + 0.75 * math.sin(math.pi * min(1.0, x * 1.2))
        s = 0.0
        for k in range(1, 9):
            fk = f0 * k
            # Resonancias aproximadas cerca de ~900 Hz y ~2200 Hz.
            r = math.exp(-(((fk - 900 * brillo - 400) / 500) ** 2)) + 0.5 * math.exp(
                -(((fk - 2200 * brillo) / 700) ** 2)
            )
            s += (0.6 / k + r) * math.sin(k * fase)
        out.append(s * suavizar(t, dur, 0.05, 0.25))
    return out


def ronroneo():
    dur = 1.5
    n = int(TASA * dur)
    rnd = random.Random(7)
    ruido = 0.0
    fase = 0.0
    out = []
    for i in range(n):
        t = i / TASA
        # Ruido marrón filtrado (paso bajo simple).
        ruido = 0.97 * ruido + 0.03 * rnd.uniform(-1, 1)
        fase += 2 * math.pi * 50 / TASA
        # Modulación a 25 Hz (número entero de ciclos en 1.5 s => bucle limpio).
        mod = 0.3 + 0.7 * math.sin(math.pi * 25 * t) ** 2
        # "Respiración": inhalar/exhalar, periodo = duración total.
        resp = 0.7 + 0.3 * math.sin(2 * math.pi * t / dur)
        s = (6 * ruido + 0.35 * math.sin(fase) + 0.15 * math.sin(2 * fase)) * mod * resp
        out.append(s)
    # Fundido corto en los extremos para que el bucle no haga "clic".
    m = int(0.03 * TASA)
    for i in range(m):
        g = i / m
        out[i] *= g
        out[n - 1 - i] *= g
    return out


def trino():
    out = []
    fase = 0.0
    for nota in range(4):
        dur = 0.09
        n = int(TASA * dur)
        for i in range(n):
            t = i / TASA
            f = 2600 + 1400 * (t / dur) + 200 * nota
            f += 250 * math.sin(2 * math.pi * 40 * t)
            fase += 2 * math.pi * f / TASA
            env = suavizar(t, dur, 0.01, 0.05)
            out.append((math.sin(fase) + 0.2 * math.sin(2 * fase)) * env)
        out.extend([0.0] * int(0.035 * TASA))
    return out


def pop():
    dur = 0.12
    n = int(TASA * dur)
    rnd = random.Random(3)
    fase = 0.0
    out = []
    for i in range(n):
        t = i / TASA
        f = 900 * math.exp(-t * 30) + 180
        fase += 2 * math.pi * f / TASA
        env = math.exp(-t * 38) * min(1.0, t / 0.002)
        chasquido = rnd.uniform(-1, 1) * math.exp(-t * 400) * 0.4
        out.append(math.sin(fase) * env + chasquido)
    return out


if __name__ == "__main__":
    os.makedirs(CARPETA, exist_ok=True)
    guardar("miau.wav", miau())
    guardar("ronroneo.wav", ronroneo())
    guardar("trino.wav", trino())
    guardar("pop.wav", pop())
