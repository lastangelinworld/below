# -*- coding: utf-8 -*-
"""Рывок по Shift: выпад вместо статичного наклона.

Что было: уклонение давало импульс в сторону и вешало на спрайт
постоянный наклон в 14 градусов на всю полсекунды. Наклон задан в
координатах мира и не отражается вместе со спрайтом, да ещё и со
знаком минус — поэтому при рывке вперёд персонажа кренило назад.

Что здесь: два клипа, «рывок по направлению взгляда» и «рывок
назад». Толчок задней ногой, полёт с разведёнными ногами, приём на
переднюю ногу и возврат в стойку. Наклон корпуса остался за кодом:
он зависит от направления движения в мире, а не от позы, и в клипе
его держать нельзя.

Кадры, кроме фазы полёта, сажаются на землю расчётом: нижняя точка
силуэта совпадает с уровнем, на котором стоят ступни.
"""
import io
import numpy as np

import rig
import crouch

GROUND = crouch.GROUND
DURATION = 0.50            # совпадает с dodge_duration в player.gd

IDX = {name: i for i, name in enumerate(crouch.ORDER)}
N = len(crouch.ORDER)


def pose(**kw):
    values = np.zeros(N)
    for name, value in kw.items():
        values[IDX[name]] = value
    return values


# Ключевые позы рывка вперёд. d = +1; для рывка назад знаки махов
# меняются на обратные (см. flip).
#   visuals_y  — просадка тела, f_* — передняя нога, b_* — задняя.
KEYS = [
    (0.00, dict()),
    (0.07, dict(visuals_y=6.0, f_hip=-0.30, f_knee=0.75, f_ankle=-0.25,
                b_hip=0.25, b_knee=0.60, b_ankle=-0.20,
                b_shoulder=-0.55, b_elbow=-0.70, f_shoulder=-0.45, f_elbow=-0.60)),
    (0.16, dict(visuals_y=1.5, f_hip=-0.95, f_knee=0.55, f_ankle=-0.35,
                b_hip=0.70, b_knee=0.20, b_ankle=0.35,
                b_shoulder=0.75, b_elbow=-0.95, f_shoulder=0.60, f_elbow=-0.85)),
    (0.26, dict(visuals_y=-1.5, f_hip=-1.15, f_knee=0.85, f_ankle=-0.30,
                b_hip=0.80, b_knee=0.35, b_ankle=0.45,
                b_shoulder=0.95, b_elbow=-1.15, f_shoulder=0.80, f_elbow=-1.00)),
    (0.35, dict(visuals_y=7.0, f_hip=-0.60, f_knee=1.15, f_ankle=-0.45,
                b_hip=0.35, b_knee=0.85, b_ankle=-0.10,
                b_shoulder=0.35, b_elbow=-0.80, f_shoulder=0.25, f_elbow=-0.70)),
    (0.43, dict(visuals_y=3.0, f_hip=-0.25, f_knee=0.55, f_ankle=-0.20,
                b_hip=0.15, b_knee=0.40, b_ankle=-0.05,
                b_shoulder=0.10, b_elbow=-0.35, f_shoulder=0.05, f_elbow=-0.30)),
    (0.50, dict()),
]

AIRBORNE = {0.26: 4.0}     # на сколько пикселей тело отрывается от земли
LEAN = 0.26                # тот же наклон, что dodge_lean в player.gd


def lean_shape(t):
    """Повторяет _dodge_lean_shape из player.gd."""
    rise, fall = DURATION * 0.24, DURATION * 0.76
    if t <= rise:
        return t / rise
    if t >= fall:
        return max(0.0, (DURATION - t) / (DURATION - fall))
    return 1.0
SWINGING = ("f_hip", "b_hip", "b_shoulder", "f_shoulder")


def plant(values, lift=0.0, lean=0.0):
    """Сажает позу на землю, затем при нужде поднимает в воздух.

    Наклон корпуса учитывается при посадке, хотя в клип он не идёт:
    накренённое тело опускается ниже, и без этого ступни уходили
    в пол на два пикселя.
    """
    values = np.array(values, dtype=float)
    probe = values.copy()
    probe[IDX["visuals_rot"]] = lean
    world, _ = rig.solve(crouch.to_pose(probe))
    bottom = -1e9
    for path in rig.ORDER:
        if not rig.NODES[path]["texture"]:
            continue
        bottom = max(bottom, max(p[1] for p in crouch.corners(world, path)))
    values[IDX["visuals_y"]] -= bottom - GROUND + lift
    return values


def frames(flip=False):
    out = []
    for t, data in KEYS:
        values = pose(**data)
        if flip:
            for name in SWINGING:
                values[IDX[name]] = -values[IDX[name]]
        if not data:
            out.append((t, values))        # стойка — без посадки
            continue
        tilt = LEAN * lean_shape(t) * (-1.0 if flip else 1.0)
        out.append((t, plant(values, AIRBORNE.get(t, 0.0), tilt)))
    return out


TRACKS = [
    ("Visuals:position", "visuals_xy", 2),
    (crouch.B_SH + ":rotation", "b_shoulder", 3),
    (crouch.B_EL + ":rotation", "b_elbow", 3),
    (crouch.F_SH + ":rotation", "f_shoulder", 3),
    (crouch.F_EL + ":rotation", "f_elbow", 3),
    (crouch.F_HIP + ":rotation", "f_hip", 3),
    (crouch.F_KNEE + ":rotation", "f_knee", 3),
    (crouch.F_ANK + ":rotation", "f_ankle", 3),
    (crouch.B_HIP + ":rotation", "b_hip", 3),
    (crouch.B_KNEE + ":rotation", "b_knee", 3),
    (crouch.B_ANK + ":rotation", "b_ankle", 3),
]


def num(v):
    return "%g" % round(float(v), 4)


def clip(anim_id, name, keys):
    times = [t for t, _ in keys]
    out = ['[sub_resource type="Animation" id="%s"]' % anim_id,
           'resource_name = "%s"' % name,
           "length = %s" % num(times[-1])]
    stamps = ", ".join(num(t) for t in times)
    ones = ", ".join("1" for _ in times)
    for n, (path, source, interp) in enumerate(TRACKS):
        if source == "visuals_xy":
            text = ", ".join("Vector2(%s, %s)" % (num(v[IDX["visuals_x"]]), num(v[IDX["visuals_y"]]))
                             for _, v in keys)
        else:
            text = ", ".join(num(v[IDX[source]]) for _, v in keys)
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


def report(keys, label):
    for t, values in keys:
        world, _ = rig.solve(crouch.to_pose(values))
        low = -1e9
        high = 1e9
        for path in rig.ORDER:
            if not rig.NODES[path]["texture"]:
                continue
            ys = [p[1] for p in crouch.corners(world, path)]
            low = max(low, max(ys))
            high = min(high, min(ys))
        print("  %-14s t=%.2f  низ %6.2f (земля %.2f)  высота %5.2f" % (
            label, t, low, GROUND, low - high))


def main():
    forward = frames(flip=False)
    backward = frames(flip=True)
    report(forward, "вперёд")

    text = io.open(rig.SCENE, encoding="utf-8").read()
    for anim_id in ("Animation_dodge_fw", "Animation_dodge_bw",
                    "Animation_roll_cw", "Animation_roll_ccw"):
        start = text.find('[sub_resource type="Animation" id="%s"]' % anim_id)
        if start != -1:
            end = text.index("[sub_resource", start + 10)
            text = text[:start] + text[end:]

    anchor = '[sub_resource type="AnimationLibrary" id="AnimationLibrary_mtric"]'
    text = text.replace(anchor,
                        clip("Animation_dodge_fw", "dodge_forward", forward)
                        + clip("Animation_dodge_bw", "dodge_back", backward)
                        + anchor)

    entry = '&"death": SubResource("Animation_death_1"),'
    for line in ('\n&"dodge_back": SubResource("Animation_dodge_bw"),',
                 '\n&"dodge_forward": SubResource("Animation_dodge_fw"),'):
        if line.strip().split(":")[0] not in text:
            text = text.replace(entry, entry + line)
    io.open(rig.SCENE, "w", encoding="utf-8", newline="\n").write(text)
    print("player.tscn обновлён")


if __name__ == "__main__":
    main()
