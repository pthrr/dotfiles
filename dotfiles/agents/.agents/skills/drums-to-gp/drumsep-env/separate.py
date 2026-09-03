from __future__ import annotations

import sys
from pathlib import Path

from mdxnet_infer import separate


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: separate.py STEM OUT_DIR", file=sys.stderr)
        return 2

    stem = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    separate(
        stem,
        output_dir=out_dir,
        model_name="drumsep-6stem",
        device="cpu",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
