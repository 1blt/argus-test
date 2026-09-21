#!/usr/bin/env bash
# =============================================================================
# KISS/DRY metrics for the dashboard panel. Reported, never gated.
#
# Usage: cleanliness-metrics.sh <out.json> [argus-checkout-dir]
#
# Emits one object per target ("suite", and "argus" when a checkout is given).
# Exits 0 even when a tool is missing -- a metric that could not be computed is
# recorded as null so the panel can say "not measured" instead of "0", which
# would read as a perfect score. Silence and zero must not look the same; that
# is the same rule the coverage-gap list exists to enforce.
#
# The evidence for each metric, and for the ones deliberately excluded, is in
# .github/data/cleanliness-metrics.json.
# =============================================================================
set -uo pipefail

OUT="${1:?usage: cleanliness-metrics.sh <out.json> [argus-dir]}"
ARGUS_DIR="${2:-}"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# DRY 1: token-based duplication over a set of paths.
# jscpd covers YAML, shell and Python, which is the whole corpus here.
# ---------------------------------------------------------------------------
duplication() {
  local root="$1"; shift
  local -a paths=("$@")
  local -a present=()
  for p in "${paths[@]}"; do [ -e "$root/$p" ] && present+=("$root/$p"); done
  [ ${#present[@]} -eq 0 ] && { echo 'null'; return; }
  have npx || { echo 'null'; return; }

  local tmp; tmp=$(mktemp -d)
  if npx --yes jscpd@4 "${present[@]}" \
        --min-lines 5 --min-tokens 50 \
        --reporters json --output "$tmp" --silent >/dev/null 2>&1 \
     && [ -f "$tmp/jscpd-report.json" ]; then
    jq -c '{
      percent:   (.statistics.total.percentage // null),
      clones:    (.statistics.total.clones // null),
      duplicated_lines: (.statistics.total.duplicatedLines // null),
      total_lines:      (.statistics.total.lines // null)
    }' "$tmp/jscpd-report.json"
  else
    echo 'null'
  fi
  rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
# KISS: cognitive complexity. Only meaningful for the Python target; the suite
# is YAML and bash, which no cognitive-complexity implementation parses.
# Reported as null for the suite rather than approximated by something else --
# a substituted metric that measures a different thing is worse than a blank.
# ---------------------------------------------------------------------------
cognitive() {
  local root="$1" pkg="$2"
  [ -d "$root/$pkg" ] || { echo 'null'; return; }
  have python3 || { echo 'null'; return; }
  python3 -m cognitive_complexity --help >/dev/null 2>&1 \
    || pip install --quiet cognitive-complexity flake8-cognitive-complexity >/dev/null 2>&1 \
    || { echo 'null'; return; }

  python3 - "$root/$pkg" <<'PY' 2>/dev/null || echo 'null'
import ast, json, sys, pathlib
try:
    from cognitive_complexity.api import get_cognitive_complexity
except Exception:
    print("null"); sys.exit(0)

THRESHOLD = 15   # SonarSource's default advisory level. A convention.
worst, worst_at, over, n = 0, None, 0, 0
for f in pathlib.Path(sys.argv[1]).rglob("*.py"):
    if "/tests/" in str(f) or "__pycache__" in str(f):
        continue
    try:
        tree = ast.parse(f.read_text(errors="replace"))
    except SyntaxError:
        continue
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            try:
                c = get_cognitive_complexity(node)
            except Exception:
                continue
            n += 1
            if c > THRESHOLD:
                over += 1
            if c > worst:
                worst, worst_at = c, f"{f.name}:{node.name}"
print(json.dumps({"worst": worst, "worst_at": worst_at,
                  "over_threshold": over, "threshold": THRESHOLD,
                  "units": n}))
PY
}

# ---------------------------------------------------------------------------
# DRY 2: duplicate test tuples. Local, and the one with a proven catch here --
# PR #13 cut six tests found this way by hand.
#
# The suites are matrices of `- { id: X, name: "...", <params> }`. Strip id and
# name and two rows that remain identical are the same test billed twice, which
# also inflates the denominator of the dashboard grade.
# ---------------------------------------------------------------------------
tuple_dupes() {
  local root="$1"
  python3 - "$root/.github/workflows" <<'PY' 2>/dev/null || echo 'null'
import json, pathlib, re, sys, collections

ROW  = re.compile(r"^\s*-\s*\{\s*(id:.*)\}\s*$")
# `key: value` where value is bare, 'single' or "double" quoted.
PAIR = re.compile(r"""(\w+)\s*:\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^,}]*)""")
# A row preceded by `# dry:allow <reason>` is exempt from the invocation tier.
ALLOW = re.compile(r"#\s*dry:allow\b[ \t]*(.*)")

IDENTITY = {"id", "name"}          # never behaviour
COSMETIC = {"cname"}               # usually a label, but not always -- see E7

exact = collections.defaultdict(list)
invoc = collections.defaultdict(list)
allowed = {}

for wf in sorted(pathlib.Path(sys.argv[1]).glob("test-*.yml")):
    lines = wf.read_text().splitlines()
    for i, line in enumerate(lines):
        if line.lstrip().startswith("#"):
            continue
        m = ROW.match(line)
        if not m:
            continue
        pairs = {k: v.strip().strip("\"'") for k, v in PAIR.findall(m.group(1))}
        tid = pairs.get("id", "?")
        where = {"id": tid, "file": wf.name, "line": i + 1}

        # look back over the comment block immediately above the row
        reason = None
        for j in range(i - 1, max(-1, i - 8), -1):
            t = lines[j].strip()
            if not t.startswith("#"):
                break
            a = ALLOW.search(t)
            if a:
                reason = a.group(1).strip() or "no reason given"
                break
        if reason:
            allowed[tid] = reason

        ex = tuple(sorted((k, v) for k, v in pairs.items() if k not in IDENTITY))
        iv = tuple(sorted((k, v) for k, v in pairs.items()
                          if k not in IDENTITY and k not in COSMETIC))
        if ex:
            exact[ex].append(where)
        if iv:
            invoc[iv].append(where)

def groups(d, skip_allowed):
    out = []
    for v in d.values():
        if len(v) < 2:
            continue
        ids = [t["id"] for t in v]
        # An exemption covers the group it appears in: one annotated row is
        # enough, because the annotation explains the pairing, not the row.
        why = next((allowed[i] for i in ids if i in allowed), None)
        if skip_allowed and why:
            out.append({"tests": ids, "where": [f"{t['file']}:{t['line']}" for t in v],
                        "allowed": why})
        elif not why:
            out.append({"tests": ids, "where": [f"{t['file']}:{t['line']}" for t in v]})
    return out

ex_g = groups(exact, False)
iv_all = groups(invoc, True)
iv_g   = [g for g in iv_all if "allowed" not in g]
iv_ok  = [g for g in iv_all if "allowed" in g]

print(json.dumps({
    "rows": sum(len(v) for v in exact.values()),
    # Tier 1: every parameter matches. Unambiguously one test billed twice.
    "exact_groups": len(ex_g),
    "exact_rows": sum(len(g["tests"]) - 1 for g in ex_g),
    "exact": ex_g[:20],
    # Tier 2: the same argus invocation, differing only by a cosmetic name.
    # May still be a distinct test if a follow-on job asserts something extra,
    # which is what `# dry:allow` records.
    "invocation_groups": len(iv_g),
    "invocation_rows": sum(len(g["tests"]) - 1 for g in iv_g),
    "invocation": iv_g[:20],
    "exempted": iv_ok[:20],
}))
PY
}

# ---------------------------------------------------------------------------
echo "Measuring suite (${REPO_ROOT})..."
SUITE_DUP=$(duplication "$REPO_ROOT" .github/workflows .github/scripts .github/actions)
SUITE_TUP=$(tuple_dupes "$REPO_ROOT")
SUITE=$(jq -n -c --argjson dup "${SUITE_DUP:-null}" --argjson tup "${SUITE_TUP:-null}" \
  '{target:"suite", duplication:$dup, cognitive:null, tuple_dupes:$tup}')

if [ -n "$ARGUS_DIR" ] && [ -d "$ARGUS_DIR" ]; then
  echo "Measuring argus (${ARGUS_DIR})..."
  A_DUP=$(duplication "$ARGUS_DIR" argus)
  A_COG=$(cognitive "$ARGUS_DIR" argus)
  ARGUS=$(jq -n -c --argjson dup "${A_DUP:-null}" --argjson cog "${A_COG:-null}" \
    '{target:"argus", duplication:$dup, cognitive:$cog, tuple_dupes:null}')
else
  echo "No argus checkout supplied; the argus panel will read 'not measured'."
  ARGUS='{"target":"argus","duplication":null,"cognitive":null,"tuple_dupes":null}'
fi

jq -n --argjson suite "$SUITE" --argjson argus "$ARGUS" \
  '{generated:(now|todate), targets:{suite:$suite, argus:$argus}}' > "$OUT"

echo "--- cleanliness ---"
jq . "$OUT"

# Duplicate tuples are the one finding worth an annotation, because they are
# unambiguous and cheap to fix. Still a notice, not a failure: the suite
# deliberately keeps a knowingly-wrong control so the harness can be shown to
# go red, and a gate here could not tell that apart from an accident.
EX=$(jq -r '.targets.suite.tuple_dupes.exact_rows // 0' "$OUT")
IV=$(jq -r '.targets.suite.tuple_dupes.invocation_rows // 0' "$OUT")
if [ "$EX" != "0" ] && [ "$EX" != "null" ]; then
  echo "::notice title=Duplicate test tuples::$EX matrix row(s) are identical to another row in every parameter. PR #13 cut six of these by hand. $(jq -c '.targets.suite.tuple_dupes.exact' "$OUT")"
fi
if [ "$IV" != "0" ] && [ "$IV" != "null" ]; then
  echo "::notice title=Duplicate argus invocations::$IV matrix row(s) dispatch the same argus call as another row, differing only by container name. That is legitimate when a follow-on job asserts something extra -- annotate the row with '# dry:allow <reason>' to record why. $(jq -c '.targets.suite.tuple_dupes.invocation' "$OUT")"
fi
