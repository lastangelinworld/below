# -*- coding: utf-8 -*-
"""Тряпичная кукла игрока: падение под гравитацией с упором в пол.

Правила, без которых решатель разгоняет тело сам по себе:
  * prev внутри итераций не трогаем;
  * предел сустава доворачивает обе половины тела навстречу друг
    другу, обратно пропорционально их массам — иначе внутренняя
    связь толкает тело целиком;
  * суммарный доворот сустава за шаг ограничен, иначе за двенадцать
    итераций нога успевает провернуться на пол-оборота и улететь.
"""
import math
import numpy as np

import rig
import bones

GROUND = rig.lowest_point()      # уровень, на котором стоят ступни живого тела
GRAVITY = 430.0                  # пикс/с²: в игре ≈ 35 пикселей на метр
DT = 1.0 / 600.0
ITERATIONS = 12
AIR_DRAG = 0.997
GROUND_FRICTION = 0.92
GROUND_SOFTNESS = 0.35
FLESH_DAMPING = 0.12
MAX_SPEED = 320.0
MAX_TURN_PER_STEP = 0.030        # радиан на сустав за шаг
MAX_TONE_PER_STEP = 0.020
GRIP = 0.02        # упёртая в пол точка во столько раз «тяжелее»
STICK = 0.5        # сила прилипания стопы к месту касания
STICK_SLIP = 0.25  # сколько пикселей за итерацию стопа всё же проскальзывает


def wrap(a):
    return (a + math.pi) % (2.0 * math.pi) - math.pi


def signed_angle(a, b, c):
    u, v = a - b, c - b
    return math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1])


class Body:
    def __init__(self):
        self.names = list(bones.JOINTS)
        self.index = {n: i for i, n in enumerate(self.names)}
        self.rest = np.array([bones.JOINTS[n][0] for n in self.names], dtype=float)
        self.pos = self.rest.copy()
        self.prev = self.rest.copy()
        self.radius = np.array([bones.JOINTS[n][1] for n in self.names])
        self.mass = np.array([bones.JOINTS[n][2] for n in self.names])
        self.inv_mass = 1.0 / self.mass
        self.links = []
        self.limits = []
        self.energy_cap = None
        self.weight = self.inv_mass.copy()
        self.planted = np.zeros(len(self.names), dtype=bool)
        self.anchor = self.rest[:, 0].copy()

    def i(self, name):
        return self.index[name]

    def link(self, a, b, stiffness=1.0):
        ia, ib = self.i(a), self.i(b)
        self.links.append((ia, ib, float(np.linalg.norm(self.rest[ia] - self.rest[ib])), stiffness))

    def limit(self, a, b, c, lo, hi, subtree, tone=1.0):
        ia, ib, ic = self.i(a), self.i(b), self.i(c)
        base = signed_angle(self.rest[ia], self.rest[ib], self.rest[ic])
        distal = [self.i(n) for n in subtree]
        proximal = [k for k in range(len(self.names)) if k not in distal and k != ib]
        share = self.mass[proximal].sum() / (self.mass[proximal].sum() + self.mass[distal].sum())
        self.limits.append({"a": ia, "b": ib, "c": ic, "base": base, "lo": lo, "hi": hi,
                            "distal": distal, "proximal": proximal, "share": share,
                            "tone": tone, "used": 0.0})

    def push(self, names, velocity):
        v = np.asarray(velocity, dtype=float) * DT
        for n in names:
            self.prev[self.i(n)] -= v

    # ── шаг симуляции ───────────────────────────────────────────
    def step(self, dt, tone=0.0):
        velocity = (self.pos - self.prev) * AIR_DRAG
        self.prev = self.pos.copy()
        self.pos = self.pos + velocity
        self.pos[:, 1] += GRAVITY * dt * dt

        for limit in self.limits:
            limit["used"] = 0.0
        self.ground_fix = np.zeros(len(self.names))
        # Упёршаяся в пол точка не ездит: на время решения делаем её
        # тяжёлой, иначе стопа массой 0.7 не удержит тело массой 15
        # и человек скользит по земле, как по льду.
        planted = self.pos[:, 1] + self.radius >= GROUND - 0.3
        self.weight = np.where(planted, self.inv_mass * GRIP, self.inv_mass)
        # Точка, только что коснувшаяся земли, запоминает своё место:
        # дальше она держится за него — это и есть трение покоя.
        fresh = planted & ~self.planted
        self.anchor[fresh] = self.pos[fresh, 0]
        self.planted = planted
        for _ in range(ITERATIONS):
            self._links()
            self._ground()
        # Пределы суставов и тонус — мягкие пружины, один раз за шаг.
        # Внутри цикла итераций они разгоняли тело: доворот больших
        # кусков вокруг дальнего сустава совершает работу.
        self._limits()
        if tone > 0.0:
            self._tone(tone)
        self._contact()
        self._flesh_damping()
        self._clamp_speed(dt)
        self._cap_energy()

    def _links(self):
        for ia, ib, rest, stiffness in self.links:
            delta = self.pos[ib] - self.pos[ia]
            length = float(np.hypot(*delta))
            if length < 1e-9:
                continue
            wa, wb = self.weight[ia], self.weight[ib]
            if wa + wb <= 0.0:
                continue
            shift = delta * (stiffness * (length - rest) / length / (wa + wb))
            self.pos[ia] += shift * wa
            self.pos[ib] -= shift * wb

    def _turn(self, which, pivot, angle):
        if not which or angle == 0.0:
            return
        cos, sin = math.cos(angle), math.sin(angle)
        arm = self.pos[which] - pivot
        self.pos[which] = pivot + np.column_stack((
            cos * arm[:, 0] - sin * arm[:, 1],
            sin * arm[:, 0] + cos * arm[:, 1]))

    def _joint_turn(self, limit, delta):
        pivot = self.pos[limit["b"]].copy()
        self._turn(limit["distal"], pivot, delta * limit["share"])
        self._turn(limit["proximal"], pivot, -delta * (1.0 - limit["share"]))

    def _limits(self):
        for limit in self.limits:
            offset = wrap(signed_angle(self.pos[limit["a"]], self.pos[limit["b"]],
                                       self.pos[limit["c"]]) - limit["base"])
            if limit["lo"] <= offset <= limit["hi"]:
                continue
            target = limit["lo"] if offset < limit["lo"] else limit["hi"]
            delta = (target - offset) * 0.5
            delta = max(-MAX_TURN_PER_STEP, min(MAX_TURN_PER_STEP, delta))
            self._joint_turn(limit, delta)

    def _tone(self, strength):
        """Мышечный тонус: мягко тянет суставы к стойке, один раз за шаг."""
        for limit in self.limits:
            offset = wrap(signed_angle(self.pos[limit["a"]], self.pos[limit["b"]],
                                       self.pos[limit["c"]]) - limit["base"])
            pull = -offset * strength * limit["tone"]
            pull = max(-MAX_TONE_PER_STEP, min(MAX_TONE_PER_STEP, pull))
            self._joint_turn(limit, pull)

    def _ground(self):
        depth = self.pos[:, 1] + self.radius - GROUND
        hit = depth > 0.0
        if hit.any():
            push = depth[hit] * GROUND_SOFTNESS
            self.pos[hit, 1] -= push
            self.ground_fix[hit] += push
        if self.planted.any():
            pull = (self.anchor[self.planted] - self.pos[self.planted, 0]) * STICK
            self.pos[self.planted, 0] += np.clip(pull, -STICK_SLIP, STICK_SLIP)

    def _contact(self):
        """Земля не имеет права подбрасывать тело.

        Выталкивание из пола — это сдвиг позиции, а в схеме Верле
        любой сдвиг превращается в скорость. Поэтому у лежащих на
        полу точек гасим скорость вверх (труп не прыгает) и трение
        по горизонтали. Без этого пол работал насосом энергии.
        """
        touching = self.pos[:, 1] + self.radius >= GROUND - 0.3
        if not touching.any():
            return
        velocity = self.pos[touching] - self.prev[touching]
        velocity[:, 0] *= (1.0 - GROUND_FRICTION)
        velocity[:, 1] = np.minimum(velocity[:, 1], 0.0)
        self.prev[touching] = self.pos[touching] - velocity

    def _flesh_damping(self):
        velocity = self.pos - self.prev
        self.prev += (velocity - velocity.mean(axis=0)) * FLESH_DAMPING

    def _clamp_speed(self, dt):
        delta = self.pos - self.prev
        speed = np.hypot(delta[:, 0], delta[:, 1]) / dt
        fast = speed > MAX_SPEED
        if fast.any():
            self.prev[fast] = self.pos[fast] - delta[fast] * (MAX_SPEED / speed[fast])[:, None]

    def _cap_energy(self):
        """Потолок энергии: пассивное тело на полу не может её набрать.

        Любой численный разгон срезается масштабированием скоростей,
        а потолок опускается следом за настоящими потерями на трении.
        """
        velocity = (self.pos - self.prev) / DT
        kinetic = 0.5 * (self.mass * (velocity ** 2).sum(1)).sum()
        potential = GRAVITY * (self.mass * -self.pos[:, 1]).sum()
        if self.energy_cap is None:
            self.energy_cap = kinetic + potential
            return
        allowed = self.energy_cap - potential
        if kinetic > allowed:
            scale = math.sqrt(max(allowed, 0.0) / kinetic) if kinetic > 0.0 else 0.0
            self.prev = self.pos - (self.pos - self.prev) * scale
            kinetic = max(allowed, 0.0)
        self.energy_cap = min(self.energy_cap, kinetic + potential)

    def speed(self):
        return float(np.abs(self.pos - self.prev).max()) / DT

    def com(self):
        return (self.mass[:, None] * self.pos).sum(0) / self.mass.sum()


def build(leg_tone=1.0, arm_tone=0.25, spine=0.8):
    body = Body()

    # Таз — жёсткая перекладина, грудь — жёсткий треугольник,
    # между ними растяжки: поясница слегка гнётся.
    body.link("back_hip", "front_hip")
    body.link("b_shoulder", "f_shoulder")
    body.link("b_shoulder", "neck")
    body.link("f_shoulder", "neck")
    for hip in ("back_hip", "front_hip"):
        for top in ("b_shoulder", "f_shoulder", "neck"):
            body.link(hip, top, spine)

    for a, b in bones.LIMBS:
        body.link(a, b)
    body.link("neck", "head_top")
    body.link("head", "head_top")

    # Пределы суставов заданы в тех же единицах, что rotation в риге:
    # проверено, что поворот узла меняет этот угол один к одному.
    body.limit("back_hip", "front_hip", "front_knee", -2.0, 0.55,
               ["front_knee", "front_ankle", "front_toe"], tone=leg_tone)
    body.limit("front_hip", "back_hip", "back_knee", -2.0, 0.55,
               ["back_knee", "back_ankle", "back_toe"], tone=leg_tone)
    body.limit("front_hip", "front_knee", "front_ankle", -0.08, 2.30,
               ["front_ankle", "front_toe"], tone=leg_tone)
    body.limit("back_hip", "back_knee", "back_ankle", -0.08, 2.30,
               ["back_ankle", "back_toe"], tone=leg_tone)
    body.limit("front_knee", "front_ankle", "front_toe", -0.70, 0.90,
               ["front_toe"], tone=leg_tone)
    body.limit("back_knee", "back_ankle", "back_toe", -0.70, 0.90,
               ["back_toe"], tone=leg_tone)
    body.limit("neck", "b_shoulder", "b_elbow", -2.80, 1.80,
               ["b_elbow", "b_wrist"], tone=arm_tone)
    body.limit("neck", "f_shoulder", "f_elbow", -2.80, 1.80,
               ["f_elbow", "f_wrist"], tone=arm_tone)
    body.limit("b_shoulder", "b_elbow", "b_wrist", -2.40, 0.05,
               ["b_wrist"], tone=arm_tone)
    body.limit("f_shoulder", "f_elbow", "f_wrist", -2.40, 0.05,
               ["f_wrist"], tone=arm_tone)
    body.limit("b_shoulder", "neck", "head_top", -0.70, 0.70,
               ["head", "head_top"], tone=arm_tone)
    return body


def run(hit=(-60.0, -20.0), body_push=(-90.0, 0.0), duration=2.8, fps=60,
        tone0=0.55, tone_fade=0.55, leg_tone=1.0, arm_tone=0.25, spine=0.8):
    """Удар, обмякание, падение. Возвращает (кукла, [(время, позиции)])."""
    body = build(leg_tone=leg_tone, arm_tone=arm_tone, spine=spine)
    if any(body_push):
        body.push(body.names, body_push)
    if any(hit):
        body.push(["b_shoulder", "f_shoulder", "neck", "head", "head_top"], hit)

    frames = []
    steps = int(duration / DT)
    every = max(1, int(round(1.0 / fps / DT)))
    quiet = 0
    n = 0
    for n in range(steps):
        t = n * DT
        strength = tone0 * max(0.0, 1.0 - t / tone_fade)
        body.step(DT, tone=strength)
        if n % every == 0:
            frames.append((t, body.pos.copy()))
        if t > 0.8:
            quiet = quiet + 1 if body.speed() < 1.5 else 0
            if quiet > int(0.3 / DT):
                break
    frames.append(((n + 1) * DT, body.pos.copy()))
    return body, frames


def energy(body):
    v = (body.pos - body.prev) / DT
    return (0.5 * (body.mass * (v ** 2).sum(1)).sum()
            + GRAVITY * (body.mass * -body.pos[:, 1]).sum())
