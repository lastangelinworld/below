# -*- coding: utf-8 -*-
"""Двуручная дубина: замеры хвата и обратная кинематика обеих рук.

Оружие в риге висит на HandSocket задней кисти, поэтому его положение
целиком задаёт задняя рука. Передняя руку к нему не привязана никак —
отсюда и «держит одной рукой». Здесь считается, где проходит древко,
и под него решаются обе руки.
"""
import math
import numpy as np

import rig
import crouch

GROUND = crouch.GROUND

SOCKET = ("Visuals/BodyBreath/BackShoulder/BackElbow/BackWrist/HandSocket")
PICKAXE = SOCKET + "/Pickaxe"
SPRITE = PICKAXE + "/PickaxeSprite"
CLUB_TEXTURE = "Texture/tex skel/bone_greatclub.png"

B_SH = crouch.B_SH
B_EL = crouch.B_EL
B_WR = B_EL + "/BackWrist"
F_SH = crouch.F_SH
F_EL = crouch.F_EL
F_WR = F_EL + "/FrontWrist"
F_HAND = F_WR + "/FrontHand"
BODY = crouch.BODY
AIM = "Visuals/BodyBreath/FrontArmAim"

# Итоговый масштаб спрайта в замахе: игра умножает базовый на 1.35
# для двуручного оружия и ещё на attack_weapon_scale предмета (0.75).
DUAL_SCALE = 1.35
ITEM_SCALE = 0.75
ATTACK_SCALE = DUAL_SCALE * ITEM_SCALE


BASE_POSITION = np.array([27.226019, -0.15496254])
# Намотанная рукоять занимает доли 0.074..0.367 длины текстуры —
# обе кисти должны лежать внутри неё, а не на голой кости.
GRIP_FRACTION = 0.11       # нижняя (дальняя) кисть

_mounted_offset = None


def install_club(scale=None, mounted=True):
    """Ставит в риг дубину так, как её покажет игра в замахе.

    mounted=True досаживает оружие так, чтобы древко проходило ровно
    через кисть: в сцене оно подвешено под кирку и висит в стороне.
    """
    global _mounted_offset
    if scale is None:
        scale = ATTACK_SCALE
    node = rig.NODES[SPRITE]
    node["texture"] = CLUB_TEXTURE
    node["scale"] = np.array([0.2, 0.2]) * scale
    node["position"] = BASE_POSITION.copy()
    # Оружие висит в самом хвосте очереди отрисовки (задняя рука за
    # торсом), поэтому древко пропадало за телом. Ставим абсолютный
    # слой: перед торсом, но под передней рукой — кисть ложится
    # поверх древка.
    node["z_index"] = 1
    node["z_as_relative"] = False
    # Дальняя рука на двуручном хвате поднимается перед торсом,
    # иначе её кулак на рукояти не виден (так же делает player.gd).
    rig.NODES[B_SH]["z_index"] = 2
    rig.NODES[B_SH]["z_as_relative"] = False
    if not mounted:
        _mounted_offset = None
        return node
    _mounted_offset = _compute_offset()
    node["position"] = BASE_POSITION + _mounted_offset
    return node


def mount_offset():
    """attack_weapon_offset для предмета — то же смещение."""
    return None if _mounted_offset is None else _mounted_offset.copy()


def _compute_offset(fraction=GRIP_FRACTION):
    """Сдвиг спрайта, при котором древко проходит через кисть.

    Смещение задаётся в системе узла Pickaxe и поворачивается вместе
    с кистью, поэтому считается один раз в любой позе.
    """
    world, _ = rig.solve()
    butt, head, _ = club_axis(world)
    length = float(np.hypot(*(head - butt)))
    axis = (head - butt) / length
    want = back_hand(world) + axis * (0.5 - fraction) * length
    shift = want - rig.point(world, SPRITE)
    basis = world[PICKAXE][:2, :2]
    return np.linalg.solve(basis, shift)


def club_points(world, local_x):
    """Точка на древке: local_x в пикселях текстуры от её центра."""
    return rig.point(world, SPRITE, (local_x, 0.0))


def club_axis(world):
    """Концы дубины и её угол в мире."""
    butt = club_points(world, -251.0)
    head = club_points(world, 251.0)
    return butt, head, math.atan2(head[1] - butt[1], head[0] - butt[0])


def front_hand(world):
    """Центр передней кисти — точка, которой она берётся за древко."""
    return rig.point(world, F_HAND)


BACK_HAND = "Visuals/BodyBreath/BackShoulder/BackElbow/BackWrist/BackHand"


def back_hand(world):
    """Центр НАРИСОВАННОГО кулака дальней руки.

    Узел HandSocket, на котором висит оружие, и сам кулак разнесены:
    непрозрачная часть спрайта смещена от начала координат почти на
    десять пикселей. Если сажать древко по сокету, дубина оказывается
    рядом с кулаком, а не в нём.
    """
    node = rig.NODES[BACK_HAND]
    img = rig.image(node["texture"])
    w, h = img.size
    x0, y0, x1, y1 = rig.opaque_bbox(node["texture"])
    return rig.point(world, BACK_HAND, ((x0 + x1) / 2.0 - w / 2.0,
                                        (y0 + y1) / 2.0 - h / 2.0))


if __name__ == "__main__":
    install_club()
    world, _ = rig.solve()
    butt, head, angle = club_axis(world)
    print("дубина в покое:")
    print("  торец  %s" % np.round(butt, 2))
    print("  голова %s" % np.round(head, 2))
    print("  длина  %.1f px, угол %.1f°" % (np.hypot(*(head - butt)), math.degrees(angle)))
    print("  задняя кисть %s" % np.round(back_hand(world), 2))
    print("  передняя кисть %s" % np.round(front_hand(world), 2))
    # Где на древке оказывается задняя кисть
    along = (back_hand(world) - butt) @ ((head - butt) / np.hypot(*(head - butt)))
    print("  задняя кисть стоит на древке в %.0f%% от торца" % (
        100.0 * along / np.hypot(*(head - butt))))
