# -*- coding: utf-8 -*-
"""Удары двуручной дубиной: обе руки на древке.

Дубина висит на HandSocket задней кисти, поэтому её положение задаёт
задняя рука, а передняя подводится к древку обратной кинематикой.
Для каждого ключевого кадра задан желаемый угол оружия и куда смотрит
его головка; решатель подбирает плечи, локти, кисть и поворот самого
оружия так, чтобы это выполнялось, а передняя ладонь лежала на древке.
"""
import math
import numpy as np

import rig
import crouch
import club

# Степени свободы, которыми распоряжается решатель.
DOF = [
    ("b_shoulder", club.B_SH, -3.10, 1.80),
    ("b_elbow", club.B_EL, -2.40, 0.20),
    ("b_wrist", club.B_WR, -1.20, 1.20),
    ("weapon", club.PICKAXE, -3.14, 3.14),
    ("f_shoulder", club.F_SH, -3.10, 1.80),
    ("f_elbow", club.F_EL, -2.40, 0.20),
]
NAMES = [name for name, _, _, _ in DOF]
IDX = {name: i for i, name in enumerate(NAMES)}

BACK_GRIP = club.GRIP_FRACTION     # доля длины от торца: задняя кисть
FRONT_GRIP = 0.30                  # верхняя (ближняя) кисть

# Туловище, сквозь которое древку проходить нельзя: отрезок от таза
# до шеи с запасом по радиусу. Голова считается отдельным кругом.
TORSO_A = np.array([0.5, 11.0])
TORSO_B = np.array([2.0, -14.0])
TORSO_R = 8.5
HEAD_C = np.array([2.5, -18.0])
HEAD_R = 7.5


def _segment_distance(p, a, b):
    ab = b - a
    k = float(np.clip(((p - a) @ ab) / float(ab @ ab), 0.0, 1.0))
    return float(np.hypot(*(p - (a + ab * k))))


def body_overlap(butt, head, samples=13):
    """Насколько глубоко древко залезает в туловище и голову."""
    worst = 0.0
    total = 0.0
    for i in range(samples):
        k = i / (samples - 1.0)
        p = butt + (head - butt) * k
        deep = max(TORSO_R - _segment_distance(p, TORSO_A, TORSO_B),
                   HEAD_R - float(np.hypot(*(p - HEAD_C))))
        if deep > 0.0:
            total += deep * deep
            worst = max(worst, deep)
    return total / samples, worst


def build_pose(values, body):
    """Собирает позу рига: руки с оружием плюс поза корпуса."""
    pose = {path: {"rotation": float(values[i])} for i, (_, path, _, _) in enumerate(DOF)}
    pose.update(body)
    return pose


def measure(values, body):
    world, _ = rig.solve(build_pose(values, body))
    butt, head, angle = club.club_axis(world)
    length = float(np.hypot(*(head - butt)))
    axis = (head - butt) / length
    return {
        "world": world,
        "butt": butt,
        "head": head,
        "angle": angle,
        "axis": axis,
        "length": length,
        "front_hand": club.front_hand(world),
        "front_target": butt + axis * FRONT_GRIP * length,
    }


def wrap(a):
    return (a + math.pi) % (2.0 * math.pi) - math.pi


def cost(values, target, body, reference):
    data = measure(values, body)
    penalty = 0.0
    # 1. Передняя ладонь обязана лежать на древке — это и есть «двумя руками».
    penalty += 6.0 * float(np.sum((data["front_hand"] - data["front_target"]) ** 2))
    # 2. Оружие смотрит туда, куда задумано.
    penalty += 900.0 * wrap(data["angle"] - target["angle"]) ** 2
    # 3. Головка дубины идёт по задуманной дуге.
    if target.get("head") is not None:
        penalty += 1.2 * float(np.sum((data["head"] - np.asarray(target["head"])) ** 2))
    # 4. Древко не проходит сквозь туловище и голову.
    overlap, _ = body_overlap(data["butt"], data["head"])
    penalty += 2.5 * overlap
    # 5. Кисти идут туда, куда ведёт рисунок удара.
    if target.get("back_hand") is not None:
        back = club.back_hand(data["world"])
        penalty += 2.0 * float(np.sum((back - np.asarray(target["back_hand"])) ** 2))
    # 6. Локти держатся естественно: не выворачиваются сильнее нужного
    # и не выезжают вперёд кистей — иначе дальняя рука читается как
    # лишний сустав, торчащий из груди.
    world = data["world"]
    back_elbow = rig.point(world, club.B_EL)
    front_elbow = rig.point(world, club.F_EL)
    back_hand = club.back_hand(world)
    front_hand = data["front_hand"]
    penalty += 0.25 * float(values[IDX["b_elbow"]]) ** 2
    penalty += 0.25 * float(values[IDX["f_elbow"]]) ** 2
    penalty += 0.8 * max(0.0, back_elbow[0] - back_hand[0] + 2.0) ** 2
    penalty += 0.8 * max(0.0, front_elbow[0] - front_hand[0] + 2.0) ** 2
    # Локоть ниже кисти: рука, поднятая вверх, сгибается вниз.
    penalty += 0.3 * max(0.0, back_elbow[1] - back_hand[1] - 14.0) ** 2
    # 7. Дубина не уходит под землю.
    for point in (data["head"], data["butt"]):
        penalty += 1.5 * max(0.0, float(point[1]) - (crouch.GROUND - 1.0)) ** 2
    # 8. Пределы суставов и близость к заданной позе.
    for i, (name, _, lo, hi) in enumerate(DOF):
        value = values[i]
        penalty += 2500.0 * (max(0.0, lo - value) ** 2 + max(0.0, value - hi) ** 2)
    penalty += 0.03 * float(np.sum((np.asarray(values) - reference) ** 2))
    return penalty


def solve(target, body, start, rounds=400):
    best = np.array(start, dtype=float)
    best_cost = cost(best, target, body, start)
    step = 0.35
    for _ in range(rounds):
        improved = False
        for i in range(len(best)):
            for delta in (step, -step):
                trial = best.copy()
                trial[i] += delta
                value = cost(trial, target, body, start)
                if value < best_cost - 1e-9:
                    best, best_cost = trial, value
                    improved = True
        if not improved:
            step *= 0.6
            if step < 0.002:
                break
    return best, best_cost


def report(values, target, body, label=""):
    data = measure(values, body)
    gap = float(np.hypot(*(data["front_hand"] - data["front_target"])))
    _, deep = body_overlap(data["butt"], data["head"])
    print("%-14s угол %7.1f° (цель %7.1f°)  ладонь мимо древка %.2f px  в тело на %.1f px  головка %s" % (
        label, math.degrees(data["angle"]), math.degrees(target["angle"]), gap, deep,
        np.round(data["head"], 1)))
    return data
