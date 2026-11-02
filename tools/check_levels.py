import re, sys
from collections import deque
from pathlib import Path

MOVES = {"Up": (0, -1), "Down": (0, 1), "Left": (-1, 0), "Right": (1, 0)}

def read_levels(path):
    src = Path(path).read_text(encoding="utf-8")
    body = src[src.index("const LEVELS"):]
    body = body[:body.index("\n]")]
    levels = []
    for block in re.findall(r"\{(.*?)\n\t\}", body, re.S):
        def arr(key):
            m = re.search(r'"%s"\s*:\s*\[(.*?)\]' % key, block, re.S)
            return re.findall(r'"([^"]*)"', m.group(1)) if m else []
        levels.append({"a": arr("a"), "b": arr("b"), "ha": arr("ha"), "hb": arr("hb")})
    return levels

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
    board = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("scripts/board.gd")
    for i, lv in enumerate(read_levels(board), 1):
        r = solve(lv)
        if r is None: print(f"Level {i:2}: IMPOSSIBLE")
        elif isinstance(r, str): print(f"Level {i:2}: {r}")
        else: print(f"Level {i:2}: {len(r):2} moves  ->  {' '.join(r)}")
