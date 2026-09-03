from __future__ import annotations

import sys
from pathlib import Path

from adtof.model.model import Model


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: transcribe.py STEM OUT_DIR", file=sys.stderr)
        return 2

    stem = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    model, hparams = Model.modelFactory(
        modelName="Frame_RNN", scenario="adtofAll", fold=0
    )
    if not model.weightLoadedFlag:
        print("ADTOF model weights did not load", file=sys.stderr)
        return 1
    model.predictFolder(str(stem), str(out_dir), **hparams)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
