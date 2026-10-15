# -*- coding: utf-8 -*-
"""Модель рига игрока: разбор player.tscn, прямая кинематика, отрисовка.

Все вычисления ведутся в системе координат узла Player (пиксели игры):
начало — центр персонажа, ось Y вниз, пол на уровне FLOOR_Y.
"""
import io, os, re
import numpy as np
from PIL import Image

# Корень проекта — две папки вверх от tools/ragdoll.
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCENE = os.path.join(ROOT, "entities", "player", "player.tscn")

# Капсула: position (1, 4), height 60 -> низ на 4 + 30.
FLOOR_Y = 34.0


def _vec(text):
    m = re.match(r"Vector2\(\s*([-\d.e+]+)\s*,\s*([-\d.e+]+)\s*\)", text)
    return np.array([float(m.group(1)), float(m.group(2))])


def parse_scene():
    text = io.open(SCENE, encoding="utf-8").read()

    textures = {}
    for m in re.finditer(r'\[ext_resource type="Texture2D"[^\]]*path="res://([^"]+)"[^\]]*id="([^"]+)"', text):
        textures[m.group(2)] = m.group(1)

    nodes = {}
    order = []
    block = text[text.index('[node name="Visuals" type="Node2D" parent="."'):]
    block = block[:block.index('[node name="Camera2D"')]

    for chunk in re.split(r"\n(?=\[node )", block):
        head = re.match(r'\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"', chunk)
        if head is None:
            continue
        name, kind, parent = head.groups()
        path = "Visuals" if parent == "." else parent + "/" + name
        node = {
            "name": name, "type": kind, "path": path,
            "parent": None if parent == "." else parent,
            "position": np.zeros(2), "rotation": 0.0, "scale": np.ones(2),
            "z_index": 0, "z_as_relative": True, "texture": None, "visible": True,
        }
        for key, value in re.findall(r"^(\w+) = (.+)$", chunk, re.M):
            if key == "position":
                node["position"] = _vec(value)
            elif key == "rotation":
                node["rotation"] = float(value)
            elif key == "scale":
                node["scale"] = _vec(value)
            elif key == "z_index":
                node["z_index"] = int(value)
            elif key == "z_as_relative":
                node["z_as_relative"] = value.strip() == "true"
            elif key == "texture":
                node["texture"] = textures[re.match(r'ExtResource\("([^"]+)"\)', value).group(1)]
        nodes[path] = node
        order.append(path)

    return nodes, order


NODES, ORDER = parse_scene()


def mat(position, rotation, scale):
    c, s = np.cos(rotation), np.sin(rotation)
    m = np.eye(3)
    m[0, 0], m[0, 1] = c * scale[0], -s * scale[1]
    m[1, 0], m[1, 1] = s * scale[0], c * scale[1]
    m[0, 2], m[1, 2] = position
    return m


def solve(pose=None):
    """pose: {путь: {"rotation": rad, "position": Vector2}} — переопределения."""
    pose = pose or {}
    world = {}
    zorder = {}
    for path in ORDER:
        node = NODES[path]
        over = pose.get(path, {})
        local = mat(over.get("position", node["position"]),
                    over.get("rotation", node["rotation"]),
                    over.get("scale", node["scale"]))
        parent = node["parent"]
        world[path] = local if parent is None else world[parent] @ local
        if node["z_as_relative"] and parent is not None:
            zorder[path] = zorder[parent] + node["z_index"]
        else:
            zorder[path] = node["z_index"]
    return world, zorder


def point(world, path, local=(0.0, 0.0)):
    v = world[path] @ np.array([local[0], local[1], 1.0])
    return v[:2]


_IMAGES = {}
_BBOX = {}


def image(rel):
    if rel not in _IMAGES:
        img = Image.open(os.path.join(ROOT, rel.replace("/", os.sep))).convert("RGBA")
        _IMAGES[rel] = img
        alpha = np.array(img)[:, :, 3]
        ys, xs = np.nonzero(alpha > 16)
        _BBOX[rel] = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return _IMAGES[rel]


def opaque_bbox(rel):
    image(rel)
    return _BBOX[rel]


# ── отрисовка ───────────────────────────────────────────────────────
VIEW = (-90.0, -70.0, 90.0, 70.0)   # x0, y0, x1, y1 в пикселях игры
ZOOM = 4


def canvas_matrix():
    x0, y0, _, _ = VIEW
    m = np.eye(3)
    m[0, 0] = m[1, 1] = ZOOM
    m[0, 2] = -x0 * ZOOM
    m[1, 2] = -y0 * ZOOM
    return m


def render(pose=None, background=(18, 18, 22, 255), ground=True):
    world, zorder = solve(pose)
    x0, y0, x1, y1 = VIEW
    size = (int((x1 - x0) * ZOOM), int((y1 - y0) * ZOOM))
    out = Image.new("RGBA", size, background)
    cam = canvas_matrix()

    sprites = [p for p in ORDER if NODES[p]["texture"] and NODES[p]["visible"]]
    sprites.sort(key=lambda p: (zorder[p], ORDER.index(p)))

    for path in sprites:
        img = image(NODES[path]["texture"])
        w, h = img.size
        centre = np.eye(3)
        centre[0, 2], centre[1, 2] = -w / 2.0, -h / 2.0
        full = cam @ world[path] @ centre
        inv = np.linalg.inv(full)
        layer = img.transform(size, Image.AFFINE,
                              (inv[0, 0], inv[0, 1], inv[0, 2],
                               inv[1, 0], inv[1, 1], inv[1, 2]),
                              resample=Image.BICUBIC)
        out.alpha_composite(layer)

    if ground:
        gy = int((FLOOR_Y - y0) * ZOOM)
        band = Image.new("RGBA", (size[0], max(1, size[1] - gy)), (60, 70, 60, 150))
        out.alpha_composite(band, (0, gy))
    return out


def lowest_point(pose=None):
    """Самая нижняя непрозрачная точка всей фигуры, в пикселях игры."""
    world, _ = solve(pose)
    worst = -1e9
    for path in ORDER:
        rel = NODES[path]["texture"]
        if not rel:
            continue
        img = image(rel)
        w, h = img.size
        bx0, by0, bx1, by1 = opaque_bbox(rel)
        for cx, cy in ((bx0, by0), (bx1, by0), (bx0, by1), (bx1, by1)):
            p = point(world, path, (cx - w / 2.0, cy - h / 2.0))
            worst = max(worst, p[1])
    return worst


if __name__ == "__main__":
    print("узлов:", len(NODES))
    world, _ = solve()
    for name, path in (("таз", "Visuals/BodyBreath"),
                       ("шея", "Visuals/BodyBreath/NeckPivot"),
                       ("перед. бедро", "Visuals/FrontHip"),
                       ("перед. колено", "Visuals/FrontHip/FrontHipBreath/FrontThigh/FrontKnee"),
                       ("перед. стопа", "Visuals/FrontHip/FrontHipBreath/FrontThigh/FrontKnee/FrontKneeBreath/FrontShin/FrontAnkle"),
                       ("зад. стопа", "Visuals/BackHip/BackHipBreath/BackThigh/BackKnee/BackKneeBreath/BackAnkle")):
        print("%-14s %s" % (name, np.round(point(world, path), 2)))
    print("низ фигуры:", round(lowest_point(), 2), " пол:", FLOOR_Y)
    render().save("rest_pose.png")
    print("rest_pose.png сохранён")
