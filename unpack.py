"""Unpack a cc-dump archive into a folder tree.

Usage: python unpack.py ccdump_12_mybase.txt [out_dir]
       python unpack.py https://files.catbox.moe/abc123.txt [out_dir]
"""
import os
import re
import sys
import urllib.request

HEADER = re.compile(rb"\n==== FILE (.+) (\d+) ====\n")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    if src.startswith("http"):
        req = urllib.request.Request(src, headers={"User-Agent": "cc-dump"})
        data = urllib.request.urlopen(req).read()
        name = src.rstrip("/").rsplit("/", 1)[-1]
    else:
        data = open(src, "rb").read()
        name = os.path.basename(src)
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(name)[0]

    first = data.find(b"\n==== FILE ")
    summary = data if first < 0 else data[:first]
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "_summary.txt"), "wb") as f:
        f.write(summary)

    pos, count = 0, 0
    while True:
        m = HEADER.search(data, pos)
        if not m:
            break
        path, size = m.group(1).decode("utf-8", "replace"), int(m.group(2))
        start = m.end()
        body = data[start:start + size]
        pos = start + size
        dest = os.path.normpath(os.path.join(out, path.lstrip("/")))
        if not dest.startswith(os.path.normpath(out)):
            continue  # ignore paths that escape the folder
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(body)
        count += 1
    print(f"Unpacked {count} files into {out}")


if __name__ == "__main__":
    main()
