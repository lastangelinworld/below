# -*- coding: utf-8 -*-
"""Контрольный лист: настоящие спрайты в позах из симуляции."""
from PIL import Image, ImageDraw
import rig, sim, bake


def sheet(poses, times, path, cols=4, label=True):
    imgs = []
    for want in times:
        t, pose = min(poses, key=lambda f: abs(f[0] - want))
        img = rig.render(pose).convert("RGB")
        if label:
            ImageDraw.Draw(img).text((8, 8), "%.2f s" % t, fill=(255, 220, 120))
        imgs.append(img)
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    out = Image.new("RGB", (w * cols, h * rows), (0, 0, 0))
    for i, img in enumerate(imgs):
        out.paste(img, ((i % cols) * w, (i // cols) * h))
    out.save(path)
    return path


if __name__ == "__main__":
    import sys
    hit = float(sys.argv[1]) if len(sys.argv) > 1 else -150.0
    fade = float(sys.argv[2]) if len(sys.argv) > 2 else 0.45
    name = sys.argv[3] if len(sys.argv) > 3 else "fall.png"
    body, frames = sim.run(hit=(hit, -25.0), fade=fade)
    poses = bake.bake(body, frames)
    print("длительность %.2f с, расхождение %.3f px" % (frames[-1][0], bake.check(body, frames, poses)))
    sheet(poses, [0.0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3, 1.7, 2.1, frames[-1][0]], name)
    print(name)
