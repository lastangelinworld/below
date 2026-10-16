# -*- coding: utf-8 -*-
"""Приводит все дорожки поворота к одному типу интерполяции.

Зачем. В player.tscn одни и те же узлы крутятся в разных клипах с
разными типами интерполяции (1 — линейно, 2 — кубически, 3 — по
кратчайшему углу). Godot на это ругается:

    'two_handed_1', Value Track: '...:rotation' has different
    interpolation types ... Blending prioritizes angle interpolation,
    so the blending result uses the shortest path

На практике это ломает позы: при переходе между клипами и при
одновременной работе двух AnimationPlayer углы уезжают на полный
оборот. Замер в движке после удара дубиной: BackElbow = 3.89,
FrontArmAttack = 5.03, FrontElbow = 5.64 — вместо значений из клипа.
Само по себе +2π выглядит так же, но следующий переход доворачивает
руку длинным путём, и персонаж «ломается».

Что делает. Разворачивает значения каждой дорожки так, чтобы между
соседними ключами было не больше 180° (то есть поведение «по
кратчайшему углу» зашивается прямо в данные), и ставит всем дорожкам
поворота линейную интерполяцию. После этого тип у всех одинаковый и
смешивать нечего.
"""
import io
import math
import re

import rig

TRACK = re.compile(
    r'(tracks/(\d+)/path = NodePath\("([^"]+)"\)\n)'
    r'(tracks/\2/interp = )(\d+)(\n)'
    r'(tracks/\2/loop_wrap = \w+\ntracks/\2/keys = \{\n'
    r'"times": PackedFloat32Array\([^)]*\),\n'
    r'"transitions": PackedFloat32Array\([^)]*\),\n'
    r'"update": \d+,\n'
    r'"values": \[)([^\]]*)(\]\n\})'
)
NUMBER = re.compile(r"-?\d+\.?\d*(?:e[-+]?\d+)?")


def _float(value):
    """Всегда с точкой: «0» Godot читает как целое, дорожка становится
    целочисленной и углы округляются (1.80 превращается в 2.0)."""
    text = "%.6g" % round(float(value), 6)
    if "e" in text or "E" in text:
        return "%.6f" % float(value)
    if "." not in text:
        text += ".0"
    return text


def unwrap(values):
    """Убирает скачки больше 180° между соседними ключами."""
    out = [values[0]]
    for value in values[1:]:
        previous = out[-1]
        while value - previous > math.pi:
            value -= 2.0 * math.pi
        while previous - value > math.pi:
            value += 2.0 * math.pi
        out.append(value)
    return out


def fix(text):
    changed_interp = 0
    changed_values = 0

    def repl(m):
        nonlocal changed_interp, changed_values
        path = m.group(3)
        if not path.endswith(":rotation"):
            return m.group(0)
        interp = int(m.group(5))
        raw = m.group(8)
        numbers = [float(x) for x in NUMBER.findall(raw)]
        fixed = unwrap(numbers)
        if any(abs(a - b) > 1e-9 for a, b in zip(numbers, fixed)):
            changed_values += 1
        if interp != 1:
            changed_interp += 1
        body = ", ".join(_float(v) for v in fixed)
        return (m.group(1) + m.group(4) + "1" + m.group(6)
                + m.group(7) + body + m.group(9))

    return TRACK.sub(repl, text), changed_interp, changed_values


def main():
    text = io.open(rig.SCENE, encoding="utf-8").read()
    fixed, interp_count, values_count = fix(text)
    io.open(rig.SCENE, "w", encoding="utf-8", newline="\n").write(fixed)
    print("дорожек поворота переведено на линейную интерполяцию: %d" % interp_count)
    print("дорожек, где значения развернули без скачков: %d" % values_count)


if __name__ == "__main__":
    main()
