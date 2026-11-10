"""word generator shared by run_diff.py and control.py"""
import random
from dlib import *


def constants(f, acc=None):
    acc = set() if acc is None else acc
    if f[0] in ('U', 'R') and f[1] is not None:
        acc.add(f[1][1])
    for x in f[1:]:
        if isinstance(x, tuple) and x and isinstance(x[0], str):
            constants(x, acc)
    return acc


def random_word(rng, props, consts):
    letters_pool = props + ['other']
    pool = list(range(1, 15)) + [2, 4, 6, 8, 2, 4]
    for c in consts:       # boundary steps: exactly the bound and one half-unit around it
        pool += [c, c + 1, max(1, c - 1), max(1, c // 2), c + 2]
    pool = [x for x in pool if x >= 1]
    pre = rng.randint(0, 5)
    loop = rng.randint(1, 4)
    n = pre + loop
    # per-word letter weights: a few letters dominate, so that 'always q for 3 time units' style
    # situations occur often enough to exercise interval boundaries
    weights = [rng.random() ** 3 + 0.02 for _ in letters_pool]
    letters = rng.choices(letters_pool, weights=weights, k=n)
    if rng.random() < 0.4:
        # constant loop (a single letter repeated): 'nothing happens any more' tails
        c = rng.choice(['other'] + letters_pool)
        letters[pre:] = [c] * loop
    delays = [rng.choice(pool) for _ in range(n)]
    return Word(letters, pre, delays, rng.choice(pool))


