#!/usr/bin/env python3
"""Stand-in for the `notebooklm` CLI, for evals.

Speaks the only shape app/routers/morning.py depends on: `ask --json <question>`
printing {"answer": ...} on stdout. Set EVAL_NOTEBOOK_DELAY to fake a slow
notebook (the real one takes 60-300s) and watch the pending card resolve;
set EVAL_NOTEBOOK_FAIL=1 to exercise the failure path.
"""
import json
import os
import sys
import time

ANSWER = """### Holding the hurt before the emptiness

The teachings are consistent that the defended self is met first, not dissolved \
first. When contempt lands — from another or from your own inner critic — the \
instruction is to let the reaction be fully felt as sensation before any view is \
applied to it.

Three moves, in order:

- **Green-light the charge.** Let the indignation be as big as it is. Reaching \
for emptiness while the body is still bracing is spiritual bypassing, and the \
hurt simply goes underground.
- **Meet it with warmth.** Offer the hurt the same warmth you would offer someone \
you love. Self-compassion is not a detour on the way to insight; it is what makes \
the looking safe enough to do.
- **Then look for the one who was wronged.** Held warmly, the solid self is easier \
to investigate. What is found is not a fixed thing but a changing display — \
radiance rather than substance.

Self-compassion and emptiness are not in tension here. The warmth is what lets the \
grip relax; the looking is what keeps the warmth from becoming another story about \
a self who deserves better."""


def main() -> int:
    if os.getenv("EVAL_NOTEBOOK_FAIL"):
        print("stub: simulated notebook failure", file=sys.stderr)
        return 1

    delay = float(os.getenv("EVAL_NOTEBOOK_DELAY", "0"))
    if delay:
        time.sleep(delay)

    question = sys.argv[-1] if len(sys.argv) > 1 else ""
    if "--json" in sys.argv:
        print(json.dumps({"answer": ANSWER, "question": question}))
    else:
        print(ANSWER)
    return 0


if __name__ == "__main__":
    sys.exit(main())
