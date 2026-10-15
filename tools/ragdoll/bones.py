# -*- coding: utf-8 -*-
"""Скелет для физики: точки суставов и толщина конечностей, снятые с рига."""
import numpy as np
import rig

W = rig.solve()[0]
P = lambda path, local=(0.0, 0.0): rig.point(W, path, local)

FRONT_HIP   = "Visuals/FrontHip"
FRONT_KNEE  = FRONT_HIP + "/FrontHipBreath/FrontThigh/FrontKnee"
FRONT_ANKLE = FRONT_KNEE + "/FrontKneeBreath/FrontShin/FrontAnkle"
FRONT_FOOT  = FRONT_ANKLE + "/FrontFoot"
BACK_HIP    = "Visuals/BackHip"
BACK_KNEE   = BACK_HIP + "/BackHipBreath/BackThigh/BackKnee"
BACK_ANKLE  = BACK_KNEE + "/BackKneeBreath/BackAnkle"
BACK_FOOT   = BACK_ANKLE + "/BackFoot"
BODY        = "Visuals/BodyBreath"
NECK        = BODY + "/NeckPivot"
HEAD        = NECK + "/HeadBreath"
HEAD_SPRITE = HEAD + "/Head"
B_SHOULDER  = BODY + "/BackShoulder"
B_ELBOW     = B_SHOULDER + "/BackElbow"
B_WRIST     = B_ELBOW + "/BackWrist"
F_AIM       = BODY + "/FrontArmAim"
F_SHOULDER  = F_AIM + "/FrontArmAttack"
F_ELBOW     = F_SHOULDER + "/FrontElbow"
F_WRIST     = F_ELBOW + "/FrontWrist"


def sprite_radius(path):
    """Половина узкой стороны непрозрачной части спрайта, в пикселях игры."""
    node = rig.NODES[path]
    x0, y0, x1, y1 = rig.opaque_bbox(node["texture"])
    scale = abs(rig.NODES["Visuals"]["scale"][0])
    return min(x1 - x0, y1 - y0) * scale / 2.0


def head_top():
    """Макушка: верх непрозрачной части головы."""
    node = rig.NODES[HEAD_SPRITE]
    img = rig.image(node['texture'])
    w, h = img.size
    x0, y0, x1, y1 = rig.opaque_bbox(node['texture'])
    return rig.point(W, HEAD_SPRITE, ((x0 + x1) / 2.0 - w / 2.0, y0 - h / 2.0))


def toe(ankle_path, foot_path):
    """Носок: дальний по X край непрозрачной части стопы."""
    node = rig.NODES[foot_path]
    img = rig.image(node["texture"])
    w, h = img.size
    x0, y0, x1, y1 = rig.opaque_bbox(node["texture"])
    return rig.point(W, foot_path, (x1 - w / 2.0, (y0 + y1) / 2.0 - h / 2.0))


FLOOR = rig.lowest_point()

# имя -> (позиция покоя, радиус столкновения, вес)
JOINTS = {
    "back_hip":      (P(BACK_HIP),    8.0, 2.2),
    "front_hip":     (P(FRONT_HIP),   8.0, 2.2),
    "neck":          (P(NECK),        6.0, 1.6),
    "head":          (P(HEAD_SPRITE), 7.0, 1.0),
    "head_top":      (head_top(),     6.0, 0.5),
    "b_shoulder":    (P(B_SHOULDER),  7.0, 1.4),
    "f_shoulder":    (P(F_SHOULDER),  7.0, 1.4),
    "b_elbow":       (P(B_ELBOW),     sprite_radius(B_SHOULDER + "/BackUpperArm"), 0.6),
    "f_elbow":       (P(F_ELBOW),     sprite_radius(F_SHOULDER + "/FrontUpperArm"), 0.6),
    "b_wrist":       (P(B_WRIST),     3.0, 0.4),
    "f_wrist":       (P(F_WRIST),     3.0, 0.4),
    "back_knee":     (P(BACK_KNEE),   sprite_radius(BACK_HIP + "/BackHipBreath/BackThigh"), 1.1),
    "front_knee":    (P(FRONT_KNEE),  sprite_radius(FRONT_HIP + "/FrontHipBreath/FrontThigh"), 1.1),
    # Радиусы стоп подогнаны так, чтобы стоящее тело касалось пола
    # всей ступнёй: иначе кукла стоит на носках и валится вперёд сама.
    "back_ankle":    (P(BACK_ANKLE),  FLOOR - P(BACK_ANKLE)[1],  0.7),
    "front_ankle":   (P(FRONT_ANKLE), FLOOR - P(FRONT_ANKLE)[1], 0.7),
    "back_toe":      (toe(BACK_ANKLE, BACK_FOOT),   FLOOR - toe(BACK_ANKLE, BACK_FOOT)[1],   0.4),
    "front_toe":     (toe(FRONT_ANKLE, FRONT_FOOT), FLOOR - toe(FRONT_ANKLE, FRONT_FOOT)[1], 0.4),
}

# Жёсткий корпус: все пары связаны между собой.
TORSO = ["back_hip", "front_hip", "neck", "b_shoulder", "f_shoulder"]

# Кости-цепочки: (a, b)
LIMBS = [
    ("neck", "head"),
    ("b_shoulder", "b_elbow"), ("b_elbow", "b_wrist"),
    ("f_shoulder", "f_elbow"), ("f_elbow", "f_wrist"),
    ("back_hip", "back_knee"), ("back_knee", "back_ankle"), ("back_ankle", "back_toe"),
    ("front_hip", "front_knee"), ("front_knee", "front_ankle"), ("front_ankle", "front_toe"),
]

if __name__ == "__main__":
    for name, (pos, radius, weight) in JOINTS.items():
        print("%-12s %7.2f %7.2f   r=%4.1f  m=%.1f" % (name, pos[0], pos[1], radius, weight))
    print()
    print("низ стоящей фигуры:", round(rig.lowest_point(), 2))
