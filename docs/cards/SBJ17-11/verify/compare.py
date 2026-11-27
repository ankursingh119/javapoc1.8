import os, sys
V = sys.argv[1]
envs = ["default", "latin1", "ar_SA"]
total = diff = 0
groups = {}
for env in envs:
    o_dir = os.path.join(V, "out", "old", env)
    n_dir = os.path.join(V, "out", "new", env)
    names = sorted(set(os.listdir(o_dir)) | set(os.listdir(n_dir)))
    for name in names:
        total += 1
        def load(d):
            p = os.path.join(d, name)
            if not os.path.exists(p):
                return None
            with open(p, encoding="utf-8", errors="replace") as f:
                return [l.rstrip("\r\n") for l in f if not l.startswith("  at ")]
        a, b = load(o_dir), load(n_dir)
        if a != b:
            diff += 1
            key = "missing" if a is None or b is None else "content"
            groups.setdefault(key, []).append(f"{env}/{name}")
print(f"files compared: {total} (inputs x environments), differing: {diff}")
for k, v in groups.items():
    print(f"  {k}: {len(v)}, e.g. {v[0]}")
