"""
Reflex level checker.

Reads the levels from levels/levels.json (written by the in-game editor) and, for every level, says
whether it can be solved and the shortest solution, using exactly the game rules:

  #  rock      blocks the friend who walks into it (the other one still moves)
  O  hole      walking into it = you fall = the level is lost
  ~  ice       you keep sliding straight until something stops you (never uphill)
  G  flag      both friends must stand on their flag at the same time
  P  start
  heights ("ha"/"hb", digits 0-3): you can climb 1 step, and drop from any height

Usage (from the project folder):   python tools/check_levels.py
"""
import json, sys
from collections import deque
from pathlib import Path

MOVES = {"Up": (0, -1), "Down": (0, 1), "Left": (-1, 0), "Right": (1, 0)}

def read_levels(path):
    levels = json.loads(Path(path).read_text(encoding="utf-8"))
    return [{"a": lv["a"], "b": lv["b"], "ha": lv.get("ha", []), "hb": lv.get("hb", [])} for lv in levels]

class Island:
    def __init__(self, rows, heights):
        self.rows, self.heights = rows, heights
    def find(self, ch):
        for y, r in enumerate(self.rows):
            if ch in r: return (r.index(ch), y)
    def inside(self, c):
        return 0 <= c[1] < len(self.rows) and 0 <= c[0] < len(self.rows[c[1]])
    def tile(self, c): return self.rows[c[1]][c[0]]
    def h(self, c): return int(self.heights[c[1]][c[0]]) if self.heights else 0
    def free(self, c): return self.inside(c) and self.tile(c) != "#"
    def move(self, c, d):
        """same as slide() in board.gd: returns (new cell, fell?)"""
        n = (c[0] + d[0], c[1] + d[1])
        if not self.free(n) or self.h(n) - self.h(c) > 1:
            return c, False
        c = n
        while self.tile(c) == "~":
            n = (c[0] + d[0], c[1] + d[1])
            if not self.free(n) or self.h(n) > self.h(c): break
            c = n
        return c, self.tile(c) == "O"

def solve(level):
    A, B = Island(level["a"], level["ha"]), Island(level["b"], level["hb"])
    start, goal = (A.find("P"), B.find("P")), (A.find("G"), B.find("G"))
    if None in start or None in goal:
        return "error: every island needs one P and one G"
    prev, queue = {start: None}, deque([start])
    while queue:
        s = queue.popleft()
        if s == goal:
            path = []
            while prev[s]: s, m = prev[s]; path.append(m)
            return path[::-1]
        for name, (dx, dy) in MOVES.items():
            a, fa = A.move(s[0], (dx, dy))
            b, fb = B.move(s[1], (-dx, dy))       # the reflection: left/right swapped
            n = (a, b)
            if fa or fb or n == s or n in prev: continue
            prev[n] = (s, name); queue.append(n)
    return None

if __name__ == "__main__":
    levels_file = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("levels/levels.json")
    for i, lv in enumerate(read_levels(levels_file), 1):
        r = solve(lv)
        if r is None: print(f"Level {i:2}: IMPOSSIBLE")
        elif isinstance(r, str): print(f"Level {i:2}: {r}")
        else: print(f"Level {i:2}: {len(r):2} moves  ->  {' '.join(r)}")