# -*- coding: utf-8 -*-
"""Собирает клипы crouch и crouch_walk и пишет их в player.tscn.

Поза приседа подобрана численно (см. crouch.py): персонаж садится на
носки, колени уходят вперёд, корпус наклоняется, голова смотрит перед
собой. Каждый кадр сажается на землю точно: считается нижняя точка
силуэта и всё тело сдвигается ровно настолько, насколько надо.
"""
import io
import math
import numpy as np

import rig
import crouch

CELL = 32.0
TARGET_HEIGHT = 32.0      # силуэт в приседе, чтобы влезал в клетку
CEILING = 35.7            # потолок силуэта на любом кадре шага
SPINE_CAP = 0.95


def silhouette(pose):
    world, _ = rig.solve(pose)
    return crouch.silhouette(world)


def cost(values, reference, target_top):
    pose = crouch.to_pose(values)
    world, _ = rig.solve(pose)
    top, bottom = crouch.silhouette(world)

    penalty = 3.0 * max(0.0, target_top - top) ** 2 + 0.2 * (top - target_top) ** 2
    # Носки на земле, пятки разрешено отрывать — иначе колени
    # выезжают на грудь и силуэт превращается в ком.
    for foot in (crouch.F_FOOT, crouch.B_FOOT):
        toe = max(crouch.corners(world, foot), key=lambda p: p[0])
        penalty += 6.0 * (toe[1] - crouch.GROUND) ** 2
    penalty += 8.0 * max(0.0, bottom - crouch.GROUND) ** 2
    feet_x = 0.5 * (rig.point(world, crouch.F_ANK)[0] + rig.point(world, crouch.B_ANK)[0])
    penalty += 0.35 * (crouch.centre_of_mass(world)[0] - feet_x) ** 2
    # Колено не выше плеча: иначе бедро накрывает торс.
    penalty += 1.2 * max(0.0, rig.point(world, crouch.B_SH)[1]
                         - rig.point(world, crouch.F_KNEE)[1]) ** 2
    for name, value in zip(crouch.ORDER, values):
        _, lo, hi = crouch.DOF[name]
        if name == "spine":
            hi = SPINE_CAP
        penalty += 2500.0 * (max(0.0, lo - value) ** 2 + max(0.0, value - hi) ** 2)
    penalty += 0.12 * float(np.sum((np.asarray(values) - reference) ** 2))
    return penalty


def solve(reference, target_top, rounds=400):
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


#                 rot   x     y   f_hip f_knee f_ank b_hip b_knee b_ank spine  head  bsh   bel   fsh   fel
START = np.array([0.0, 0.0, 16.0, -1.60, 2.30, -0.30, -1.40, 2.15, -0.35,
                  0.85, -0.55, 0.50, -1.00, 0.40, -0.95])

IDX = {name: i for i, name in enumerate(crouch.ORDER)}


def plant(values):
    """Сажает позу на землю: сдвигает всё тело так, чтобы низ силуэта
    совпал с уровнем, на котором стоят ступни живого персонажа."""
    values = np.array(values, dtype=float)
    top, bottom = silhouette(crouch.to_pose(values))
    values[IDX["visuals_y"]] -= bottom - crouch.GROUND
    return values


# Поза отобрана глазами из нескольких решений подбора: голова
# держится отдельно от груди, колени впереди, руки опущены.
# visuals_rot держим в нуле: этот поворот задан в координатах мира и
# не отражается вместе со спрайтом — при взгляде влево наклон ушёл бы
# в обратную сторону. Наклон корпуса и головы вместо дорожек анимации
# выставляет player.gd, потому что эти два узла скрипт пишет каждый
# кадр сам (наклон к курсору) и анимация с ним дралась бы.
CROUCH = np.array([0.00, 0.00, 13.41, -1.77, 2.42, -0.65, -2.00, 2.40, 1.03,
                   0.99, -0.71, 0.83, -1.00, 0.35, -0.95])


def base_pose():
    return plant(CROUCH), 0.0


def breathing(base, count=5, period=2.6):
    """Клип crouch: та же поза, но тело чуть дышит."""
    keys = []
    for i in range(count):
        phase = 2.0 * math.pi * i / (count - 1)
        values = base.copy()
        # Дыхание только «вниз»: вверх силуэт расти не должен,
        # иначе макушка выходит за потолок в один блок.
        swell = (1.0 - math.cos(phase)) * 0.5
        values[IDX["visuals_y"]] += 0.35 * swell
        values[IDX["spine"]] += 0.030 * swell
        values[IDX["head"]] -= 0.025 * swell
        values[IDX["b_shoulder"]] += 0.035 * swell
        values[IDX["f_shoulder"]] += 0.030 * swell
        keys.append((period * i / (count - 1), plant(values)))
    return keys


STRIDE = 15.0      # на сколько пикселей нога уезжает за шаг
LIFT = 4.2         # на сколько поднимается стопа в переносе
BOB = 0.7          # просадка таза на опорной ноге


def foot_low(world, path):
    """Самая нижняя точка подошвы."""
    return max(p[1] for p in crouch.corners(world, path))


def leg_targets(phase):
    """Куда должны приехать лодыжки на этой фазе цикла.

    Опорная нога полцикла равномерно уезжает назад (тело идёт
    вперёд), вторая полцикла переносится вперёд с подъёмом стопы.
    """
    out = {}
    for name, shift in (("front", 0.0), ("back", 0.5)):
        local = (phase + shift) % 1.0
        if local < 0.5:                      # опора
            x = STRIDE * (0.5 - local * 2.0) * 0.5
            lift = 0.0
        else:                                # перенос
            k = (local - 0.5) * 2.0
            x = STRIDE * (-0.5 + k) * 0.5
            # Стопа отрывается резко и так же резко ставится:
            # на пологой синусоиде между ключами она успевает
            # чиркнуть по полу.
            lift = LIFT * math.sin(math.pi * k) ** 0.45
        out[name] = (x, lift)
    return out


LEG_DOF = ["visuals_y", "f_hip", "f_knee", "f_ankle", "b_hip", "b_knee", "b_ankle"]


def walk_cost(values, base, targets, target_top):
    pose = crouch.to_pose(values)
    world, _ = rig.solve(pose)
    penalty = 0.0
    base_world, _ = rig.solve(crouch.to_pose(base))
    for name, ankle, foot in (("front", crouch.F_ANK, crouch.F_FOOT),
                              ("back", crouch.B_ANK, crouch.B_FOOT)):
        shift, lift = targets[name]
        want = rig.point(base_world, ankle) + np.array([shift, -lift])
        got = rig.point(world, ankle)
        penalty += 4.0 * float(np.sum((got - want) ** 2))
        # Опорная стопа стоит на земле, перенесённая висит над ней.
        penalty += (6.0 if lift < 0.1 else 2.0) * (foot_low(world, foot) - (crouch.GROUND - lift)) ** 2
    top, bottom = crouch.silhouette(world)
    # Потолок важнее точности шага: в проход высотой в клетку
    # персонаж обязан влезать на любом кадре.
    penalty += 25.0 * max(0.0, target_top - top) ** 2
    penalty += 10.0 * max(0.0, bottom - crouch.GROUND) ** 2
    for name, value in zip(crouch.ORDER, values):
        _, lo, hi = crouch.DOF[name]
        penalty += 2500.0 * (max(0.0, lo - value) ** 2 + max(0.0, value - hi) ** 2)
    moved = np.asarray(values) - base
    penalty += 0.05 * float(np.sum(moved ** 2))
    return penalty


def walk_solve(start, base, targets, target_top, rounds=260):
    best = np.array(start, dtype=float)
    best_cost = walk_cost(best, base, targets, target_top)
    step = 0.3
    indices = [IDX[name] for name in LEG_DOF]
    for _ in range(rounds):
        improved = False
        for i in indices:
            scale = 3.0 if crouch.ORDER[i] == "visuals_y" else 1.0
            for delta in (step * scale, -step * scale):
                trial = best.copy()
                trial[i] += delta
                value = walk_cost(trial, base, targets, target_top)
                if value < best_cost - 1e-9:
                    best, best_cost = trial, value
                    improved = True
        if not improved:
            step *= 0.6
            if step < 0.003:
                break
    return best, best_cost


def walking(base, count=19, period=0.42):
    """Клип crouch_walk: утиный шаг. Ноги ставятся туда, куда нужно,
    углы суставов под это решаются обратной кинематикой — поэтому шаг
    получается широким, а силуэт не подпрыгивает."""
    keys = []
    previous = base.copy()
    ceiling_top = crouch.GROUND - CEILING
    for i in range(count):
        phase = i / (count - 1)
        values = previous.copy()
        # Руки качаются в противоход ногам, таз слегка проседает.
        swing = math.sin(2.0 * math.pi * phase)
        values[IDX["b_shoulder"]] = base[IDX["b_shoulder"]] - 0.22 * swing
        values[IDX["f_shoulder"]] = base[IDX["f_shoulder"]] + 0.22 * swing
        values[IDX["b_elbow"]] = base[IDX["b_elbow"]] - 0.12 * swing
        values[IDX["f_elbow"]] = base[IDX["f_elbow"]] + 0.12 * swing
        values[IDX["visuals_y"]] = base[IDX["visuals_y"]] + BOB * (
            1.0 - math.cos(4.0 * math.pi * phase)) * 0.5

        fixed, score = walk_solve(values, base, leg_targets(phase), ceiling_top)
        previous = fixed.copy()
        # Полпикселя вниз: делим пополам расхождение между «макушка
        # задевает потолок» и «ступня тонет в полу».
        fixed = fixed.copy()
        fixed[IDX["visuals_y"]] += 0.5
        keys.append((period * phase, fixed))
    keys[-1] = (keys[-1][0], keys[0][1].copy())
    return keys


# ── запись в сцену ──────────────────────────────────────────────────
TRACKS = [
    ("Visuals:position", "visuals_xy"),
    (crouch.B_SH + ":rotation", "b_shoulder"),
    (crouch.B_EL + ":rotation", "b_elbow"),
    (crouch.F_SH + ":rotation", "f_shoulder"),
    (crouch.F_EL + ":rotation", "f_elbow"),
    (crouch.F_HIP + ":rotation", "f_hip"),
    (crouch.F_KNEE + ":rotation", "f_knee"),
    (crouch.F_ANK + ":rotation", "f_ankle"),
    (crouch.B_HIP + ":rotation", "b_hip"),
    (crouch.B_KNEE + ":rotation", "b_knee"),
    (crouch.B_ANK + ":rotation", "b_ankle"),
]


def num(v):
    return "%g" % round(float(v), 4)


def clip(anim_id, name, keys, loop=True):
    times = [t for t, _ in keys]
    out = ['[sub_resource type="Animation" id="%s"]' % anim_id,
           'resource_name = "%s"' % name,
           "length = %s" % num(times[-1])]
    if loop:
        out.append("loop_mode = 1")
    stamps = ", ".join(num(t) for t in times)
    ones = ", ".join("1" for _ in times)
    for n, (path, source) in enumerate(TRACKS):
        if source == "visuals_xy":
            text = ", ".join("Vector2(%s, %s)" % (num(v[IDX["visuals_x"]]), num(v[IDX["visuals_y"]]))
                             for _, v in keys)
            interp = 2
        else:
            text = ", ".join(num(v[IDX[source]]) for _, v in keys)
            interp = 3
        out += ['tracks/%d/type = "value"' % n,
                "tracks/%d/imported = false" % n,
                "tracks/%d/enabled = true" % n,
                'tracks/%d/path = NodePath("%s")' % (n, path),
                "tracks/%d/interp = %d" % (n, interp),
                "tracks/%d/loop_wrap = true" % n,
                "tracks/%d/keys = {" % n,
                '"times": PackedFloat32Array(%s),' % stamps,
                '"transitions": PackedFloat32Array(%s),' % ones,
                '"update": 0,',
                '"values": [%s]' % text,
                "}"]
    return "\n".join(out) + "\n\n"


def check(keys, label):
    worst_high, worst_low, worst_gap = 0.0, 0.0, 0.0
    for t, values in keys:
        top, bottom = silhouette(crouch.to_pose(values))
        worst_high = max(worst_high, bottom - top)
        worst_low = max(worst_low, abs(bottom - crouch.GROUND))
        worst_gap = max(worst_gap, bottom - crouch.GROUND)
    print("%-12s кадров %d, высота до %.2f px (клетка %.0f), от земли до %.2f px" % (
        label, len(keys), worst_high, CELL, worst_low))
    return worst_high


def main():
    base, score = base_pose()
    top, bottom = silhouette(crouch.to_pose(base))
    print("поза приседа: высота %.2f px, цена %.2f" % (bottom - top, score))
    idle = breathing(base)
    walk = walking(base)
    check(idle, "crouch")
    check(walk, "crouch_walk")

    text = io.open(rig.SCENE, encoding="utf-8").read()
    for anim_id, name, keys in (("Animation_run_3c", "crouch", idle),
                                ("Animation_run_4d", "crouch_walk", walk)):
        start = text.index('[sub_resource type="Animation" id="%s"]' % anim_id)
        end = text.index("[sub_resource", start + 10)
        text = text[:start] + clip(anim_id, name, keys) + text[end:]
    io.open(rig.SCENE, "w", encoding="utf-8", newline="\n").write(text)
    print("player.tscn обновлён")
    print("в player.gd прописать: наклон корпуса %+.2f, головы %+.2f" % (
        base[IDX["spine"]], base[IDX["head"]]))


if __name__ == "__main__":
    main()
