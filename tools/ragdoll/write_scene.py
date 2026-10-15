# -*- coding: utf-8 -*-
"""Записывает просчитанное падение в player.tscn как клипы death / death_mirrored."""
import io
import numpy as np

import export

SCENE = export.SCENE
ROT, POS, LINEAR = 3, 2, 1


def num(v):
    return "%g" % round(float(v), 4)


def clip(anim_id, name, times, data, keep, mirror=False):
    out = ['[sub_resource type="Animation" id="%s"]' % anim_id,
           'resource_name = "%s"' % name,
           "length = %s" % num(times[keep[-1]])]
    stamps = ", ".join(num(times[i]) for i in keep)
    ones = ", ".join("1" for _ in keep)
    for n, (path, kind) in enumerate(export.TRACKS):
        values = data[path][keep]
        if kind == "position":
            if mirror:
                values = values * np.array([-1.0, 1.0])
            text = ", ".join("Vector2(%s, %s)" % (num(x), num(y)) for x, y in values)
            interp = LINEAR
        else:
            if mirror and path == "Visuals:rotation":
                values = -values
            text = ", ".join(num(v) for v in values)
            interp = ROT
        node = path if ":" in path else path + ":rotation"
        out += ['tracks/%d/type = "value"' % n,
                "tracks/%d/imported = false" % n,
                "tracks/%d/enabled = true" % n,
                'tracks/%d/path = NodePath("%s")' % (n, node),
                "tracks/%d/interp = %d" % (n, interp),
                "tracks/%d/loop_wrap = true" % n,
                "tracks/%d/keys = {" % n,
                '"times": PackedFloat32Array(%s),' % stamps,
                '"transitions": PackedFloat32Array(%s),' % ones,
                '"update": 0,',
                '"values": [%s]' % text,
                "}"]
    return "\n".join(out) + "\n\n"


def main():
    body, frames, times, data, keep, error, deep = export.build()
    print("сверка рига и куклы: %.3f px" % error)
    print("длительность %.2f с, ключей %d" % (times[keep[-1]], len(keep)))

    text = io.open(SCENE, encoding="utf-8").read()
    start = text.index('[sub_resource type="Animation" id="Animation_death_1"]')
    end = text.index('[sub_resource type="Animation" id="Animation_b2kln"]')
    text = (text[:start]
            + clip("Animation_death_1", "death", times, data, keep, mirror=False)
            + clip("Animation_death_2", "death_mirrored", times, data, keep, mirror=True)
            + text[end:])
    io.open(SCENE, "w", encoding="utf-8", newline="\n").write(text)
    print("player.tscn обновлён")


if __name__ == "__main__":
    main()
