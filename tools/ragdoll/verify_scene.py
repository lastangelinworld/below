# -*- coding: utf-8 -*-
"""Читает клип обратно из player.tscn и проверяет, что он делает."""
import io
import re
import numpy as np
from PIL import Image, ImageDraw

import rig, sim, export


def read_clip(name):
    text = io.open(export.SCENE, encoding="utf-8").read()
    start = text.index('resource_name = "%s"' % name)
    end = text.index("[sub_resource", start)
    block = text[start:end]
    tracks = {}
    for match in re.finditer(
            r'tracks/(\d+)/path = NodePath\("([^"]+)"\).*?'
            r'"times": PackedFloat32Array\(([^)]*)\).*?"values": \[(.*?)\]\n\}',
            block, re.S):
        path = match.group(2)
        times = np.array([float(x) for x in match.group(3).split(",")])
        raw = match.group(4)
        if "Vector2" in raw:
            values = np.array([[float(a), float(b)] for a, b in
                               re.findall(r"Vector2\(([-\d.e]+), ([-\d.e]+)\)", raw)])
        else:
            values = np.array([float(x) for x in raw.split(",")])
        tracks[path] = (times, values)
    length = float(re.search(r"length = ([\d.]+)", block).group(1))
    return length, tracks


def pose_at(tracks, t):
    pose = {}
    for path, (times, values) in tracks.items():
        node, prop = path.split(":")
        if values.ndim == 1:
            value = float(np.interp(t, times, values))
        else:
            value = np.array([np.interp(t, times, values[:, 0]),
                              np.interp(t, times, values[:, 1])])
        pose.setdefault(node, {})[prop] = value
    return pose


def main():
    for name in ("death", "death_mirrored"):
        length, tracks = read_clip(name)
        print("%-15s длина %.2f с, дорожек %d" % (name, length, len(tracks)))
        lows = []
        for t in np.linspace(0, length, 80):
            lows.append(rig.lowest_point(pose_at(tracks, t)))
        print("   нижняя точка: мин %.2f, макс %.2f, в конце %.2f (пол %.2f)" % (
            min(lows), max(lows), lows[-1], sim.GROUND))
        pose = pose_at(tracks, 0.0)
        print("   старт: поворот %.3f, сдвиг %s" % (
            pose["Visuals"]["rotation"], np.round(pose["Visuals"]["position"], 2)))
        pose = pose_at(tracks, length)
        print("   финал: поворот %.3f, сдвиг %s" % (
            pose["Visuals"]["rotation"], np.round(pose["Visuals"]["position"], 2)))

    # Картинка обоих направлений
    rig.VIEW = (-95.0, -70.0, 95.0, 55.0)
    rig.ZOOM = 3
    imgs = []
    for name, flip in (("death", 1.0), ("death_mirrored", -1.0)):
        length, tracks = read_clip(name)
        base = rig.NODES["Visuals"]["scale"].copy()
        rig.NODES["Visuals"]["scale"] = np.array([base[0] * flip, base[1]])
        for t in (0.0, 0.35, 0.6, length):
            img = rig.render(pose_at(tracks, t)).convert("RGB")
            ImageDraw.Draw(img).text((8, 8), "%s %.2f s" % (name, t), fill=(255, 220, 120))
            imgs.append(img)
        rig.NODES["Visuals"]["scale"] = base
    w, h = imgs[0].size
    sheet = Image.new("RGB", (w * 4, h * 2), (0, 0, 0))
    for i, img in enumerate(imgs):
        sheet.paste(img, ((i % 4) * w, (i // 4) * h))
    sheet.save("from_scene.png")
    print("from_scene.png")


if __name__ == "__main__":
    main()
