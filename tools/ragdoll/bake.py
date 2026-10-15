# -*- coding: utf-8 -*-
"""Перевод позиций тряпичной куклы обратно в повороты узлов рига."""
import math
import numpy as np

import rig, bones, sim

V = "Visuals"
BODY = bones.BODY
HEAD = bones.HEAD
B_SH, B_EL = bones.B_SHOULDER, bones.B_ELBOW
F_SH, F_EL = bones.F_SHOULDER, bones.F_ELBOW
F_HIP, F_KNEE, F_ANK = bones.FRONT_HIP, bones.FRONT_KNEE, bones.FRONT_ANKLE
B_HIP, B_KNEE, B_ANK = bones.BACK_HIP, bones.BACK_KNEE, bones.BACK_ANKLE

# (узел, начало кости, конец кости, предки чьи повороты уже учтены)
CHAIN = [
    (BODY,  "hip_mid",    "neck",        [V]),
    (HEAD,  "neck",       "head_top",    [V, BODY]),
    (B_SH,  "b_shoulder", "b_elbow",     [V, BODY]),
    (B_EL,  "b_elbow",    "b_wrist",     [V, BODY, B_SH]),
    (F_SH,  "f_shoulder", "f_elbow",     [V, BODY]),
    (F_EL,  "f_elbow",    "f_wrist",     [V, BODY, F_SH]),
    (F_HIP, "front_hip",  "front_knee",  [V]),
    (F_KNEE, "front_knee", "front_ankle", [V, F_HIP]),
    (F_ANK, "front_ankle", "front_toe",  [V, F_HIP, F_KNEE]),
    (B_HIP, "back_hip",   "back_knee",   [V]),
    (B_KNEE, "back_knee", "back_ankle",  [V, B_HIP]),
    (B_ANK, "back_ankle", "back_toe",    [V, B_HIP, B_KNEE]),
]

RIG_HIP_MID = np.array([(45.0 - 19.0) / 2.0, 116.0])     # середина таза в единицах рига
SCALE = abs(rig.NODES[V]["scale"][0])


def _pt(body, pos, name):
    if name == "hip_mid":
        return (pos[body.i("back_hip")] + pos[body.i("front_hip")]) / 2.0
    return pos[body.i(name)]


def rest_angles(body):
    out = {}
    for node, a, b, _ in CHAIN:
        v = _pt(body, body.rest, b) - _pt(body, body.rest, a)
        out[node] = math.atan2(v[1], v[0])
    return out


def wrap(a):
    return (a + math.pi) % (2.0 * math.pi) - math.pi


def pose_from(body, pos, rest):
    """Одна поза рига: {путь: {'rotation': ...}} плюс сдвиг Visuals."""
    front = pos[body.i("front_hip")]
    back = pos[body.i("back_hip")]
    v = front - back
    vrot = wrap(math.atan2(v[1], v[0]) - math.pi)

    cos, sin = math.cos(vrot), math.sin(vrot)
    offset = SCALE * RIG_HIP_MID
    hip_mid = (front + back) / 2.0
    vpos = hip_mid - np.array([cos * offset[0] - sin * offset[1],
                               sin * offset[0] + cos * offset[1]])

    pose = {V: {"rotation": vrot, "position": vpos}}
    angles = {V: vrot}
    for node, a, b, parents in CHAIN:
        d = _pt(body, pos, b) - _pt(body, pos, a)
        want = math.atan2(d[1], d[0])
        local = wrap(want - rest[node] - sum(angles[p] for p in parents))
        pose[node] = {"rotation": local}
        angles[node] = local
    return pose


def bake(body, frames):
    rest = rest_angles(body)
    return [(t, pose_from(body, pos, rest)) for t, pos in frames]


def check(body, frames, poses):
    """Сверяем прямую кинематику рига с позициями куклы."""
    worst = 0.0
    names = {BODY: "neck", HEAD: "head_top", B_SH: "b_elbow", B_EL: "b_wrist",
             F_SH: "f_elbow", F_EL: "f_wrist", F_HIP: "front_knee",
             F_KNEE: "front_ankle", B_HIP: "back_knee", B_KNEE: "back_ankle"}
    targets = {bones.NECK: "neck", bones.B_ELBOW: "b_elbow", bones.B_WRIST: "b_wrist",
               bones.F_ELBOW: "f_elbow", bones.F_WRIST: "f_wrist",
               bones.FRONT_KNEE: "front_knee", bones.FRONT_ANKLE: "front_ankle",
               bones.BACK_KNEE: "back_knee", bones.BACK_ANKLE: "back_ankle",
               bones.FRONT_HIP: "front_hip", bones.BACK_HIP: "back_hip"}
    for (t, pos), (_, pose) in zip(frames, poses):
        world, _ = rig.solve(pose)
        for path, joint in targets.items():
            got = rig.point(world, path)
            want = pos[body.i(joint)]
            worst = max(worst, float(np.hypot(*(got - want))))
    return worst


if __name__ == "__main__":
    body, frames = sim.run()
    poses = bake(body, frames)
    print("кадров:", len(poses))
    print("максимальное расхождение рига и куклы: %.4f пикселя" % check(body, frames, poses))
