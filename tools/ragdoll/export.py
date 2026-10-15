# -*- coding: utf-8 -*-
"""Симуляция -> обрезка -> прореживание ключей -> клипы для player.tscn."""
import io
import math
import numpy as np

import rig, bones, sim, bake

SCENE = rig.SCENE

# Узлы анимации в том же порядке, в каком они пойдут дорожками.
TRACKS = [
    ("Visuals:position", "position"),
    ("Visuals:rotation", "rotation"),
    (bake.BODY, "rotation"),
    (bake.HEAD, "rotation"),
    (bake.B_SH, "rotation"),
    (bake.B_EL, "rotation"),
    (bake.F_SH, "rotation"),
    (bake.F_EL, "rotation"),
    (bake.F_HIP, "rotation"),
    (bake.F_KNEE, "rotation"),
    (bake.F_ANK, "rotation"),
    (bake.B_HIP, "rotation"),
    (bake.B_KNEE, "rotation"),
    (bake.B_ANK, "rotation"),
]

ROT_TOLERANCE = 0.012     # радиан
POS_TOLERANCE = 0.22      # пикселей


def sample(poses):
    """Переводит список поз в таблицу значений по дорожкам."""
    times = np.array([t for t, _ in poses])
    data = {}
    for path, kind in TRACKS:
        node = path.split(":")[0]
        if kind == "position":
            data[path] = np.array([p[node]["position"] for _, p in poses])
        else:
            data[path] = np.array([p[node]["rotation"] for _, p in poses])
    return times, data


def trim(times, data, move_threshold=0.015, quiet=0.010):
    """Срезает неподвижное начало и успокоившийся хвост."""
    motion = np.zeros(len(times))
    for path, kind in TRACKS:
        values = data[path]
        if kind == "position":
            step = np.abs(np.diff(values, axis=0)).sum(1) / 20.0
        else:
            step = np.abs(np.diff(values))
        motion[1:] = np.maximum(motion[1:], step)

    start = 0
    while start < len(times) - 1 and motion[start + 1] < move_threshold:
        start += 1
    end = len(times) - 1
    while end > start + 10 and motion[end] < quiet:
        end -= 1
    end = min(len(times) - 1, end + 15)
    return start, end


def decimate(times, data):
    """Оставляет только те кадры, без которых кривая заметно исказится."""
    keep = [0]
    last = 0
    for i in range(1, len(times) - 1):
        bad = False
        for path, kind in TRACKS:
            values = data[path]
            span = times[i + 1] - times[last]
            if span <= 0:
                continue
            k = (times[i] - times[last]) / span
            guess = values[last] + (values[i + 1] - values[last]) * k
            if kind == "position":
                error = float(np.hypot(*(values[i] - guess)))
                limit = POS_TOLERANCE
            else:
                error = abs(float(values[i] - guess))
                limit = ROT_TOLERANCE
            if error > limit:
                bad = True
                break
        if bad:
            keep.append(i)
            last = i
    keep.append(len(times) - 1)
    return keep


def pose_at(data, i):
    pose = {}
    for path, kind in TRACKS:
        node = path.split(":")[0]
        pose.setdefault(node, {})[kind] = data[path][i]
    return pose


def plant(times, data, smooth=7):
    """Сажает тело точно на землю.

    В симуляции конечности — это шарики, а рисуется персонаж
    спрайтами, которые чуть шире. Поэтому лежащее тело уходило в пол
    на три пикселя. Считаем настоящую нижнюю точку картинки на каждом
    кадре и поднимаем тело ровно настолько, насколько оно утонуло.
    """
    deep = np.array([max(0.0, rig.lowest_point(pose_at(data, i)) - sim.GROUND)
                     for i in range(len(times))])
    if smooth > 1:
        pad = np.r_[np.full(smooth, deep[0]), deep, np.full(smooth, deep[-1])]
        kernel = np.ones(smooth) / smooth
        deep = np.convolve(pad, kernel, mode="same")[smooth:-smooth]
    data["Visuals:position"][:, 1] -= deep
    return deep


def build(hit=-180.0, push=-25.0, tone0=0.55, tone_fade=0.55, leg_tone=1.0):
    body, frames = sim.run(hit=(hit, -40.0), body_push=(push, 0.0), tone0=tone0,
                           tone_fade=tone_fade, leg_tone=leg_tone, duration=3.0)
    poses = bake.bake(body, frames)
    error = bake.check(body, frames, poses)
    times, data = sample(poses)
    start, end = trim(times, data)
    times = times[start:end + 1] - times[start]
    data = {k: v[start:end + 1] for k, v in data.items()}
    deep = plant(times, data)
    keep = decimate(times, data)
    return body, frames, times, data, keep, error, deep


if __name__ == "__main__":
    body, frames, times, data, keep, error, deep = build()
    print("симуляция %.2f с, сверка рига %.3f px" % (frames[-1][0], error))
    print("после обрезки %.2f с, кадров %d -> ключей %d" % (times[-1], len(times), len(keep)))
    pos = data["Visuals:position"]
    print("сдвиг Visuals: x от %.1f до %.1f, y от %.1f до %.1f" % (
        pos[:, 0].min(), pos[:, 0].max(), pos[:, 1].min(), pos[:, 1].max()))
    print("поворот Visuals: от %.2f до %.2f рад" % (
        data["Visuals:rotation"].min(), data["Visuals:rotation"].max()))
    print("посадка на землю: поднял тело максимум на %.2f px" % deep.max())
    lows = [rig.lowest_point(pose_at(data, i)) for i in range(len(times))]
    print("нижняя точка: мин %.2f, макс %.2f, в конце %.2f (пол %.2f)" % (
        min(lows), max(lows), lows[-1], sim.GROUND))
