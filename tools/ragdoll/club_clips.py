# -*- coding: utf-8 -*-
"""Три удара двуручной дубиной: собирает клипы two_handed_1..3.

Задаётся траектория самого оружия (угол древка и куда летит головка)
и стойка корпуса. Углы плеч, локтей, кисти и поворот оружия под это
решаются обратной кинематикой так, чтобы передняя ладонь лежала на
древке — тогда дубина действительно держится двумя руками.

Моменты попадания совпадают с _get_attack_hit_delay в player.gd:
0.22, 0.18 и 0.31 секунды.
"""
import io
import math
import numpy as np

import rig
import crouch
import club
import club_swing as cs

D = math.radians
WEAPON_SCALE = club.ATTACK_SCALE   # 1.35 * 0.75, как считает игра

BODY_PATHS = {
    "spine": crouch.BODY,
    "f_hip": crouch.F_HIP, "f_knee": crouch.F_KNEE, "f_ankle": crouch.F_ANK,
    "b_hip": crouch.B_HIP, "b_knee": crouch.B_KNEE, "b_ankle": crouch.B_ANK,
}

READY = dict(spine=0.05, f_hip=-0.18, f_knee=0.22, f_ankle=-0.08,
             b_hip=0.12, b_knee=0.18, b_ankle=-0.06)

# ── траектории ──────────────────────────────────────────────────────
# (время, угол древка, куда идёт задняя кисть, стойка)
# Угол: 0 — вправо, -90 — вверх, +90 — вниз. Кисти ведутся отдельно:
# если их не вести, руки липнут к груди и древко ложится поперёк тела.

SMASH = [            # удар 1: замах над головой, удар сверху. Попадание 0.22
    (0.00, D(-58), (15, -4), READY),
    (0.08, D(-140), (8, -20), dict(spine=-0.26, f_hip=-0.34, f_knee=0.40, f_ankle=-0.12,
                                   b_hip=0.24, b_knee=0.12, b_ankle=-0.04)),
    (0.22, D(48), (17, 0), dict(spine=0.44, f_hip=-0.64, f_knee=0.54, f_ankle=-0.22,
                                b_hip=0.42, b_knee=0.28, b_ankle=0.10)),
    (0.30, D(66), (16, 3), dict(spine=0.54, f_hip=-0.72, f_knee=0.72, f_ankle=-0.28,
                                b_hip=0.48, b_knee=0.44, b_ankle=0.14)),
    (0.40, D(-16), (13, -6), dict(spine=0.22, f_hip=-0.42, f_knee=0.44, f_ankle=-0.16,
                                  b_hip=0.28, b_knee=0.26, b_ankle=0.04)),
    (0.50, D(-58), (15, -4), READY),
]

SWEEP = [            # удар 2: короткий боковой наотмашь. Попадание 0.18
    (0.00, D(-58), (15, -4), READY),
    (0.06, D(-124), (7, -14), dict(spine=-0.20, f_hip=-0.28, f_knee=0.34, f_ankle=-0.10,
                                   b_hip=0.20, b_knee=0.14, b_ankle=-0.04)),
    (0.18, D(-6), (12, -7), dict(spine=0.26, f_hip=-0.52, f_knee=0.44, f_ankle=-0.18,
                                 b_hip=0.34, b_knee=0.24, b_ankle=0.08)),
    (0.26, D(34), (15, -2), dict(spine=0.34, f_hip=-0.46, f_knee=0.46, f_ankle=-0.16,
                                 b_hip=0.30, b_knee=0.28, b_ankle=0.06)),
    (0.38, D(-54), (14, -5), dict(spine=0.08, f_hip=-0.24, f_knee=0.26, f_ankle=-0.10,
                                  b_hip=0.16, b_knee=0.20, b_ankle=-0.04)),
    (0.46, D(-58), (15, -4), READY),
]

OVERHEAD = [         # удар 3: тяжёлый замах из-за головы. Попадание 0.31
    (0.00, D(-58), (15, -4), READY),
    (0.12, D(-134), (9, -19), dict(spine=-0.28, f_hip=-0.30, f_knee=0.36, f_ankle=-0.10,
                                   b_hip=0.26, b_knee=0.12, b_ankle=-0.06)),
    (0.22, D(-166), (5, -21), dict(spine=-0.38, f_hip=-0.26, f_knee=0.30, f_ankle=-0.08,
                                   b_hip=0.30, b_knee=0.10, b_ankle=-0.08)),
    (0.31, D(40), (18, -2), dict(spine=0.50, f_hip=-0.76, f_knee=0.62, f_ankle=-0.26,
                                 b_hip=0.50, b_knee=0.30, b_ankle=0.12)),
    (0.42, D(70), (16, 4), dict(spine=0.62, f_hip=-0.84, f_knee=0.86, f_ankle=-0.32,
                                b_hip=0.54, b_knee=0.52, b_ankle=0.18)),
    (0.54, D(-24), (13, -7), dict(spine=0.26, f_hip=-0.44, f_knee=0.46, f_ankle=-0.18,
                                  b_hip=0.30, b_knee=0.28, b_ankle=0.04)),
    (0.64, D(-58), (15, -4), READY),
]

PLANS = [("two_handed_1", "Animation_2hnd_1", SMASH),
         ("two_handed_2", "Animation_2hnd_2", SWEEP),
         ("two_handed_3", "Animation_2hnd_3", OVERHEAD)]


def body_pose(**kw):
    out = {}
    for name, path in BODY_PATHS.items():
        out[path] = {"rotation": float(kw.get(name, 0.0))}
    out["Visuals"] = {"position": np.array([0.0, float(kw.get("y", 0.0))])}
    return out


def plant(body):
    """Сажает стойку на землю: ступни на уровне живого персонажа.
    Оружие в расчёт не идёт — дубина может висеть сколь угодно низко."""
    world, _ = rig.solve(body)
    bottom = -1e9
    for path in rig.ORDER:
        if not rig.NODES[path]["texture"] or "Pickaxe" in path:
            continue
        bottom = max(bottom, max(p[1] for p in crouch.corners(world, path)))
    body["Visuals"]["position"][1] -= bottom - crouch.GROUND
    return body


def unwrap(previous, value):
    """Поворот оружия должен идти непрерывно, иначе на кадре между
    ключами дубина прокрутится в обратную сторону."""
    while value - previous > math.pi:
        value -= 2.0 * math.pi
    while previous - value > math.pi:
        value += 2.0 * math.pi
    return value


def catmull(points, x):
    """Гладкая кривая через заданные точки (Catmull-Rom по времени)."""
    times = [p[0] for p in points]
    if x <= times[0]:
        return points[0][1]
    if x >= times[-1]:
        return points[-1][1]
    i = max(0, min(len(points) - 2, np.searchsorted(times, x) - 1))
    t0, t1 = times[i], times[i + 1]
    k = (x - t0) / (t1 - t0)
    p0 = points[max(0, i - 1)][1]
    p1, p2 = points[i][1], points[i + 1][1]
    p3 = points[min(len(points) - 1, i + 2)][1]
    return (0.5 * ((2.0 * p1) + (-p0 + p2) * k
                   + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * k * k
                   + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * k * k * k))


def resample(plan, step=0.018):
    """Уплотняет траекторию: между редкими ключами рука сходит с
    древка, потому что оружие и плечи интерполируются порознь.
    Поэтому обратная кинематика считается на каждом кадре."""
    fields = list(plan[0][3])
    angle_pts = [(t, a) for t, a, _, _ in plan]
    head_x = [(t, float(h[0])) for t, _, h, _ in plan]
    head_y = [(t, float(h[1])) for t, _, h, _ in plan]
    stance_pts = {f: [(t, float(s.get(f, 0.0))) for t, _, _, s in plan] for f in fields}

    end = plan[-1][0]
    times = sorted(set([t for t, _, _, _ in plan]
                       + list(np.arange(0.0, end, step)) + [end]))
    out = []
    for x in times:
        stance = {f: catmull(stance_pts[f], x) for f in fields}
        out.append((round(float(x), 4), catmull(angle_pts, x),
                    (catmull(head_x, x), catmull(head_y, x)), stance))
    return out


def build(plan):
    plan = resample(plan)
    start = np.array([-1.2, -0.8, 0.0, 0.0, -1.2, -0.8])
    keys = []
    previous_weapon = None
    worst = 0.0
    deepest = 0.0
    for t, angle, head, stance in plan:
        body = plant(body_pose(**stance))
        values, _ = cs.solve({"angle": angle, "head": None, "back_hand": head},
                             body, start)
        data = cs.measure(values, body)
        worst = max(worst, float(np.hypot(*(data["front_hand"] - data["front_target"]))))
        deepest = max(deepest, cs.body_overlap(data["butt"], data["head"])[1])
        if previous_weapon is not None:
            values[cs.IDX["weapon"]] = unwrap(previous_weapon, values[cs.IDX["weapon"]])
        previous_weapon = values[cs.IDX["weapon"]]
        # Слой отрисовки: когда дубина заведена назад, она должна
        # уходить ЗА тело, иначе выглядит так, будто проходит сквозь.
        layer = -1 if data["head"][0] < data["butt"][0] else 1
        keys.append((t, values, body, layer))
        start = values.copy()
    return keys, worst, deepest


# ── запись клипов ───────────────────────────────────────────────────
TRACKS = [
    (club.B_SH + ":rotation", "b_shoulder"),
    (club.B_EL + ":rotation", "b_elbow"),
    (club.B_WR + ":rotation", "b_wrist"),
    (club.PICKAXE + ":rotation", "weapon"),
    (club.F_SH + ":rotation", "f_shoulder"),
    (club.F_EL + ":rotation", "f_elbow"),
    (crouch.BODY + ":rotation", "spine"),
    (crouch.F_HIP + ":rotation", "f_hip"),
    (crouch.F_KNEE + ":rotation", "f_knee"),
    (crouch.F_ANK + ":rotation", "f_ankle"),
    (crouch.B_HIP + ":rotation", "b_hip"),
    (crouch.B_KNEE + ":rotation", "b_knee"),
    (crouch.B_ANK + ":rotation", "b_ankle"),
]


def num(v):
    return "%g" % round(float(v), 4)


def track(index, path, interp, times, values, kind="float"):
    """kind: float | vector | int. Целые значения пишутся ступенькой —
    слой отрисовки нельзя интерполировать дробью."""
    out = ['tracks/%d/type = "value"' % index,
           "tracks/%d/imported = false" % index,
           "tracks/%d/enabled = true" % index,
           'tracks/%d/path = NodePath("%s")' % (index, path),
           "tracks/%d/interp = %d" % (index, interp),
           "tracks/%d/loop_wrap = true" % index,
           "tracks/%d/keys = {" % index,
           '"times": PackedFloat32Array(%s),' % ", ".join(num(t) for t in times),
           '"transitions": PackedFloat32Array(%s),' % ", ".join("1" for _ in times),
           '"update": %d,' % (1 if kind == "int" else 0)]
    if kind == "vector":
        out.append('"values": [%s]' % ", ".join(
            "Vector2(%s, %s)" % (num(v[0]), num(v[1])) for v in values))
    elif kind == "int":
        out.append('"values": [%s]' % ", ".join(str(int(v)) for v in values))
    else:
        out.append('"values": [%s]' % ", ".join(num(v) for v in values))
    out.append("}")
    return "\n".join(out)


def clip(anim_id, name, keys):
    times = [t for t, _, _, _ in keys]
    out = ['[sub_resource type="Animation" id="%s"]' % anim_id,
           'resource_name = "%s"' % name,
           "length = %s" % num(times[-1])]
    index = 0
    for path, source in TRACKS:
        if source in cs.IDX:
            values = [v[cs.IDX[source]] for _, v, _, _ in keys]
        else:
            values = [b[BODY_PATHS[source]]["rotation"] for _, _, b, _ in keys]
        # Поворот оружия — линейно: он проходит больше полуоборота,
        # и «кратчайшим путём» дубина крутилась бы назад.
        interp = 1 if source == "weapon" else 3
        out.append(track(index, path, interp, times, values))
        index += 1
    out.append(track(index, "Visuals:position", 2, times,
                     [b["Visuals"]["position"] for _, _, b, _ in keys], kind="vector"))
    index += 1
    out.append(track(index, club.SPRITE + ":z_index", 1, times,
                     [z for _, _, _, z in keys], kind="int"))
    index += 1
    # Постоянные дорожки: иначе остаются значения от ударов киркой.
    out.append(track(index, club.B_SH + ":position", 1, [times[0]],
                     [np.array([70.0, -183.0])], kind="vector"))
    index += 1
    out.append(track(index, club.F_WR + ":scale", 1, [times[0]],
                     [np.array([1.0, 1.0])], kind="vector"))
    return "\n".join(out) + "\n\n"


def main():
    club.install_club(scale=WEAPON_SCALE)
    print("оружие: длина %.1f px, смещение посадки (%.3f, %.3f)" % (
        np.hypot(*(club.club_axis(rig.solve()[0])[1] - club.club_axis(rig.solve()[0])[0])),
        *club.mount_offset()))

    text = io.open(rig.SCENE, encoding="utf-8").read()
    for name, anim_id, plan in PLANS:
        keys, worst, deepest = build(plan)
        print("%-14s кадров %d, длина %.2f с, ладонь мимо древка не больше %.3f px, "
              "древко заходит в тело не глубже %.1f px" % (
                  name, len(keys), keys[-1][0], worst, deepest))
        start = text.index('[sub_resource type="Animation" id="%s"]' % anim_id)
        end = text.index("[sub_resource", start + 10)
        text = text[:start] + clip(anim_id, name, keys) + text[end:]
    io.open(rig.SCENE, "w", encoding="utf-8", newline="\n").write(text)
    print("player.tscn обновлён")


if __name__ == "__main__":
    main()
