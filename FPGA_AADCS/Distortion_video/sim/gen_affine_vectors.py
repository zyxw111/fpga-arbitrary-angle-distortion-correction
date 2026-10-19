"""Deterministic rational reference, plus a floating geometry error bound.

These coefficients are arithmetic test cases, not real camera calibration.
"""
import math
import random
from fractions import Fraction
from pathlib import Path


def quantize(value):
    return int(math.copysign(math.floor(abs(value) * 65536 + 0.5), value))


def nearest_away(value):
    if value < 0:
        return -nearest_away(-value)
    return (2 * value.numerator + value.denominator) // (2 * value.denominator)


def main():
    rng = random.Random(20261019)
    rows = []
    edges = [(0, 0), (1919, 1079), (4095, 4095), (1, 1),
             (63, 31), (320, 200), (17, 89), (4095, 0)]
    angles = [0, 90, -90, 180, 17.3, -137.2, 359.9, 45]
    for i in range(256):
        x, y = rng.randrange(4096), rng.randrange(4096)
        if i < 8:
            x, y = edges[i]
        angle = angles[i % 8] if i < 32 else rng.uniform(-360, 360)
        c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        cx, cy = 959.5, 539.5
        a = [quantize(c), quantize(-s), quantize(cx-c*cx+s*cy),
             quantize(s), quantize(c), quantize(cy-s*cx-c*cy)]
        if i % 19 == 0:
            a = [65536, 0, -8, 0, 65536, 8]
        if i % 31 == 0:
            a = [2147483647, 2147483647, 0, -2147483648, -2147483648, 0]
            x = y = 4095
        exact = [nearest_away(Fraction(a[0]*x+a[1]*y+a[2], 16)),
                 nearest_away(Fraction(a[3]*x+a[4]*y+a[5], 16))]
        overflow = any(v < -2147483648 or v > 2147483647 for v in exact)
        out = [max(-2147483648, min(2147483647, v)) for v in exact]
        if i % 19 and i % 31:
            ideal = [c*x-s*y+cx-c*cx+s*cy, s*x+c*y+cy-s*cx-c*cy]
            assert max(abs(out[j]/4096-ideal[j]) for j in range(2)) < 0.065
        valid = 1 if i < 48 else int(rng.random() > 0.24)
        fields = [(valid, 1), (int(overflow), 1), (out[1], 32), (out[0], 32)]
        fields += [(v, 32) for v in reversed(a)] + [(y, 12), (x, 12)]
        packed = 0
        for value, bits in fields:
            packed = (packed << bits) | (value & ((1 << bits)-1))
        rows.append(f"{packed:071x}")
    Path(__file__).with_name("affine_vectors.hex").write_text(
        "\n".join(rows)+"\n", encoding="ascii")


if __name__ == "__main__":
    main()
