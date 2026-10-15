# -*- coding: utf-8 -*-
"""Добавляет нейтральные дорожки в клипы ходьбы и стойки.

Клип приседа опускает всё тело и сгибает руки. Клипы idle/walk/run
эти узлы не трогают вовсе, поэтому после вставания персонаж остался
бы в приседной позе: Godot просто перестаёт писать такую дорожку и
узел замирает на последнем значении. Добавляем в каждый клип по
постоянной дорожке с нулём — тогда переход возвращает стойку.
"""
import io
import re

import rig

CLIPS = ("idle", "jump", "run", "sprint", "walk", "walk_back")
NEUTRAL = [
    ("Visuals:position", "Vector2(0, 0)", 2),
    ("Visuals/BodyBreath/BackShoulder:rotation", "0.0", 1),
    ("Visuals/BodyBreath/BackShoulder/BackElbow:rotation", "0.0", 1),
    ("Visuals/BodyBreath/FrontArmAim/FrontArmAttack:rotation", "0.0", 1),
    ("Visuals/BodyBreath/FrontArmAim/FrontArmAttack/FrontElbow:rotation", "0.0", 1),
]


def track_block(index, path, value, interp):
    return "\n".join([
        'tracks/%d/type = "value"' % index,
        "tracks/%d/imported = false" % index,
        "tracks/%d/enabled = true" % index,
        'tracks/%d/path = NodePath("%s")' % (index, path),
        "tracks/%d/interp = %d" % (index, interp),
        "tracks/%d/loop_wrap = true" % index,
        "tracks/%d/keys = {" % index,
        '"times": PackedFloat32Array(0),',
        '"transitions": PackedFloat32Array(1),',
        '"update": 0,',
        '"values": [%s]' % value,
        "}",
    ]) + "\n"


def main():
    text = io.open(rig.SCENE, encoding="utf-8").read()
    for name in CLIPS:
        start = text.index('resource_name = "%s"' % name)
        start = text.rindex("[sub_resource", 0, start)
        end = text.index("[sub_resource", start + 10)
        block = text[start:end]
        count = len(set(re.findall(r"tracks/(\d+)/type", block)))
        added = []
        for path, value, interp in NEUTRAL:
            if 'NodePath("%s")' % path in block:
                continue
            added.append(track_block(count + len(added), path, value, interp))
        if not added:
            print("%-10s — всё уже на месте" % name)
            continue
        block = block.rstrip("\n") + "\n" + "".join(added) + "\n"
        text = text[:start] + block + text[end:]
        print("%-10s + %d дорожек" % (name, len(added)))
    io.open(rig.SCENE, "w", encoding="utf-8", newline="\n").write(text)
    print("player.tscn обновлён")


if __name__ == "__main__":
    main()
