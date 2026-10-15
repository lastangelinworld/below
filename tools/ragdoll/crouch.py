# -*- coding: utf-8 -*-
"""Подбор позы приседа: ищем, как сложить персонажа в одну клетку.

Высота клетки 32 пикселя, стоящая фигура — 62. Поза подбирается
численно: минимизируем высоту силуэта при условиях «обе ступни стоят
на земле всей подошвой», «центр тяжести над опорой» и «суставы не
выворачиваются за анатомические пределы».
"""
import math
import numpy as np

import rig

GROUND = rig.lowest_point()          # 37.35: где стоят ступни живого тела
CELL = 32.0                          # высота клетки мира
TARGET_TOP = GROUND - (CELL - 1.0)   # макушка должна быть не выше этого

F_HIP = "Visuals/FrontHip"
F_KNEE = F_HIP + "/FrontHipBreath/FrontThigh/FrontKnee"
F_ANK = F_KNEE + "/FrontKneeBreath/FrontShin/FrontAnkle"
F_FOOT = F_ANK + "/FrontFoot"
B_HIP = "Visuals/BackHip"
B_KNEE = B_HIP + "/BackHipBreath/BackThigh/BackKnee"
B_ANK = B_KNEE + "/BackKneeBreath/BackAnkle"
B_FOOT = B_ANK + "/BackFoot"
BODY = "Visuals/BodyBreath"
HEAD = BODY + "/NeckPivot/HeadBreath"
B_SH = BODY + "/BackShoulder"
B_EL = B_SH + "/BackElbow"
F_SH = BODY + "/FrontArmAim/FrontArmAttack"
F_EL = F_SH + "/FrontElbow"

# параметр -> (узел, нижний предел, верхний предел)
# Бёдра прикреплены к узлу Visuals и сами по себе не опускаются:
# чтобы тело присело, нужно опустить весь риг (visuals_y), сложив ноги
# так, чтобы ступни остались на земле. Именно этого не хватало
# запечённому клипу crouch — он гнул колени, не опуская таз.
DOF = {
    "visuals_rot": (None, -1.70, 1.70),
    "visuals_x": (None, -12.0, 12.0),
    "visuals_y": (None, 0.0, 30.0),
    "f_hip": (F_HIP, -2.00, 0.55),
    "f_knee": (F_KNEE, -0.08, 2.45),
    "f_ankle": (F_ANK, -0.70, 1.15),
    "b_hip": (B_HIP, -2.00, 0.55),
    "b_knee": (B_KNEE, -0.08, 2.45),
    "b_ankle": (B_ANK, -0.70, 1.15),
    "spine": (BODY, -0.50, 1.55),
    "head": (HEAD, -0.70, 0.70),
    "b_shoulder": (B_SH, -2.80, 1.80),
    "b_elbow": (B_EL, -2.40, 0.05),
    "f_shoulder": (F_SH, -2.80, 1.80),
    "f_elbow": (F_EL, -2.40, 0.05),
}
ORDER = list(DOF)


def to_pose(values, extra=None):
    pose = {}
    shift = np.zeros(2)
    turn = 0.0
    for name, value in zip(ORDER, values):
        if name == "visuals_rot":
            turn = float(value)
            continue
        if name == "visuals_x":
            shift[0] = float(value)
            continue
        if name == "visuals_y":
            shift[1] = float(value)
            continue
        pose[DOF[name][0]] = {"rotation": float(value)}
    pose["Visuals"] = {"position": shift, "rotation": turn}
    if extra:
        for path, data in extra.items():
            pose.setdefault(path, {}).update(data)
    return pose


def corners(world, path):
    node = rig.NODES[path]
    img = rig.image(node["texture"])
    w, h = img.size
    x0, y0, x1, y1 = rig.opaque_bbox(node["texture"])
    return [rig.point(world, path, (cx - w / 2.0, cy - h / 2.0))
            for cx, cy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1))]


def silhouette(world):
    top, bottom = 1e9, -1e9
    for path in rig.ORDER:
        if not rig.NODES[path]["texture"]:
            continue
        for p in corners(world, path):
            top = min(top, p[1])
            bottom = max(bottom, p[1])
    return top, bottom


def foot_contact(world, path):
    """Насколько низ подошвы отличается от уровня земли, спереди и сзади."""
    pts = sorted(corners(world, path), key=lambda p: -p[1])[:2]
    return [p[1] - GROUND for p in pts]


MASS = {"Visuals/BodyBreath/Torso": 6.0,
        "Visuals/BodyBreath/NeckPivot/HeadBreath/Head": 1.5,
        F_HIP + "/FrontHipBreath/FrontThigh": 1.2,
        B_HIP + "/BackHipBreath/BackThigh": 1.2}


def centre_of_mass(world):
    total, acc = 0.0, np.zeros(2)
    for path, m in MASS.items():
        acc += m * rig.point(world, path)
        total += m
    return acc / total


def cost(values, reference, target_top=TARGET_TOP):
    pose = to_pose(values)
    world, _ = rig.solve(pose)
    top, bottom = silhouette(world)

    penalty = 0.0
    # 1. Силуэт должен уместиться в клетку.
    # ось Y направлена вниз: «слишком высокий» — это top МЕНЬШЕ цели.
    penalty += 3.0 * max(0.0, target_top - top) ** 2 + 0.2 * (top - target_top) ** 2
    # 2. Обе ступни стоят на земле всей подошвой.
    for foot in (F_FOOT, B_FOOT):
        for gap in foot_contact(world, foot):
            penalty += 6.0 * gap * gap
    # 3. Ничто не проваливается в пол.
    penalty += 8.0 * max(0.0, bottom - GROUND) ** 2
    # 4. Центр тяжести над ступнями.
    feet_x = 0.5 * (rig.point(world, F_ANK)[0] + rig.point(world, B_ANK)[0])
    penalty += 0.35 * (centre_of_mass(world)[0] - feet_x) ** 2
    # 5. Пределы суставов и близость к задуманной позе.
    for name, value in zip(ORDER, values):
        _, lo, hi = DOF[name]
        penalty += 2500.0 * (max(0.0, lo - value) ** 2 + max(0.0, value - hi) ** 2)
    penalty += 0.12 * float(np.sum((np.asarray(values) - reference) ** 2))
    return penalty


def solve(reference, target_top=TARGET_TOP, rounds=400):
    """Покоординатный спуск с уменьшающимся шагом."""
    best = np.array(reference, dtype=float)
    best_cost = cost(best, reference, target_top)
    step = 0.35
    for _ in range(rounds):
        improved = False
        for i in range(len(best)):
            for delta in (step, -step):
                trial = best.copy()
                trial[i] += delta
                value = cost(trial, reference, target_top)
                if value < best_cost - 1e-9:
                    best, best_cost = trial, value
                    improved = True
        if not improved:
            step *= 0.6
            if step < 0.002:
                break
    return best, best_cost


REFERENCE = np.array([
    0.0,                   # разворот всего тела (для положения лёжа)
    0.0, 14.0,             # весь риг опускается
    -1.55, 2.20, 0.80,     # передняя нога: глубокий сгиб
    -1.35, 2.05, 0.75,     # задняя нога
    1.20,                  # складывается вперёд в тазу
    -0.60,                 # голова смотрит вперёд, а не в пол
    0.55, -1.20,           # дальняя рука свисает к коленям
    0.45, -1.10,           # ближняя рука
])


def report(values, label="присед"):
    world, _ = rig.solve(to_pose(values))
    top, bottom = silhouette(world)
    feet = [round(g, 2) for foot in (F_FOOT, B_FOOT) for g in foot_contact(world, foot)]
    print("%-12s высота %5.2f (макушка %6.2f, низ %6.2f)  ступни %s" % (
        label, bottom - top, top, bottom, feet))
    for name, value in zip(ORDER, values):
        print("    %-11s %+6.3f" % (name, value))
    return top, bottom


if __name__ == "__main__":
    print("пол %.2f, цель для макушки %.2f (клетка %.0f px)" % (GROUND, TARGET_TOP, CELL))
    values, score = solve(REFERENCE)
    print("цена %.3f" % score)
    report(values)
