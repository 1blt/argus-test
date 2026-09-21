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
  if [ ${#present[@]} -eq 0 ]; then
    echo '{"error":"none of the configured paths exist in this checkout"}'; return
  fi
  if ! have npx; then
    echo '{"error":"npx is not on PATH, so the clone detector could not run"}'; return
  fi

  local tmp; tmp=$(mktemp -d)
  # jscpd EXITS 0 AND WRITES NO REPORT when it finds nothing. Gating on the
  # report's existence therefore reported "no duplication" as a broken metric
  # -- the exact conflation of "we did not look" with "there is nothing there"
  # that this page refuses to make anywhere else. The exit code and the report
  # are now separate signals: non-zero is a fault, zero with no report is a
  # clean zero, and stderr is carried into the fault so it says something
  # useful instead of guessing.
  local rc=0
  npx --yes jscpd@4 "${present[@]}" \
      --min-lines 5 --min-tokens 50 \
      --reporters json --output "$tmp" --silent >"$tmp/out" 2>"$tmp/err" || rc=$?

  if [ "$rc" -ne 0 ]; then
    jq -n -c --arg why "$(tr '\n' ' ' < "$tmp/err" | cut -c1-300)" --arg rc "$rc" \
      '{error: ("the clone detector exited " + $rc + (if $why | length > 0 then ": " + $why else "" end))}'
    rm -rf "$tmp"
    return
  fi

  if [ ! -f "$tmp/jscpd-report.json" ]; then
    # Ran cleanly and produced nothing: there is no duplication to report.
    # present[] holds directories, so count through find rather than cat.
    local total
    total=$(find "${present[@]}" -type f \( -name '*.py' -o -name '*.sh' -o -name '*.yml' \) \
             -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    jq -n -c --argjson total "${total:-0}" \
      '{percent: 0, clones: 0, duplicated_lines: 0, total_lines: $total, groups: []}'
    rm -rf "$tmp"
    return
  fi

  # The clone LOCATIONS are the point. A percentage is a claim; the file and
  # line range of each pair is the evidence for it, and it is what someone
  # has to open to decide whether the duplication matters.
  jq -c --arg root "$root" '{
    percent:   (.statistics.total.percentage // null),
    clones:    (.statistics.total.clones // null),
    duplicated_lines: (.statistics.total.duplicatedLines // null),
    total_lines:      (.statistics.total.lines // null),
    groups: [ .duplicates[]? | {
      lines:  .lines,
      tokens: .tokens,
      format: .format,
      a: { file: (.firstFile.name  | sub("^" + $root + "/"; "")), start: .firstFile.start,  end: .firstFile.end },
      b: { file: (.secondFile.name | sub("^" + $root + "/"; "")), start: .secondFile.start, end: .secondFile.end },
      # The duplicated text itself. jscpd already produces it and it was
      # being thrown away, which left the page asserting that two ranges
      # match without ever showing what matches -- the reader had to open two
      # GitHub tabs and diff by eye. Capped per group so one pathological
      # clone cannot dominate the page; the whole corpus is ~13 KB today.
      fragment: (.fragment // "" | .[0:6000])
    } ] | sort_by(-.lines)
  }' "$tmp/jscpd-report.json" > "$tmp/groups.json"

  # Pull BOTH sides out of the real files. jscpd's `fragment` is one side only
  # -- enough to say "this text repeats", not enough to show what DIFFERS
  # between the two copies, which for a Type-2 clone is the interesting part.
  # The files are right here, so reading them is cheap.
  python3 - "$root" "$tmp/groups.json" <<'PY'
import json, pathlib, sys

root = pathlib.Path(sys.argv[1])
data = json.loads(pathlib.Path(sys.argv[2]).read_text())
MAX_LINES = 140          # one pathological clone must not dominate the page

def snippet(rel, start, end, length):
    """Lines start..end of a file, tolerating a bad `end` from the detector.

    jscpd reports `end` before `start` for some groups -- 207-41, 168-45 --
    which silently dropped those pairs out of the side-by-side view. The clone
    LENGTH is reported separately and is reliable, so derive the end from it
    whenever the reported one does not make sense.
    """
    try:
        lines = (root / rel).read_text(errors="replace").splitlines()
    except OSError:
        return None
    lo = max(1, int(start))
    hi = int(end)
    if hi < lo:
        hi = lo + max(0, int(length) - 1)
    hi = min(len(lines), hi)
    if lo > hi:
        return None
    return lines[lo - 1:hi][:MAX_LINES]

for g in data.get("groups", []):
    n = g.get("lines", 0)
    a = snippet(g["a"]["file"], g["a"]["start"], g["a"]["end"], n)
    b = snippet(g["b"]["file"], g["b"]["start"], g["b"]["end"], n)
    if a is not None:
        g["aText"] = a
    if b is not None:
        g["bText"] = b
    g.pop("fragment", None)      # superseded by the two real sides

print(json.dumps(data, separators=(",", ":")))
PY
  rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
# KISS: cognitive complexity, for BOTH languages in play.
#
# This used to report "not applicable" for the suite on the grounds that no
# implementation parses Actions YAML or shell. That was a cop-out: Campbell's
# rules are language-agnostic by construction -- increment on each break in
# linear flow, and add the current nesting depth when the break is nested --
# and the suite's executable content is shell, several thousand lines of it.
# Declining to measure the thing this repository is actually made of, on a page
# about this repository, measured nothing and said so quietly.
#
# So: Python via the reference implementation, shell via the rules applied
# directly. The shell pass is an implementation of a published measure, not a
# proxy invented here, and it reports the constructs it counted so the number
# can be checked rather than believed.
# ---------------------------------------------------------------------------
cognitive_python() {
  local root="$1" pkg="$2"
  [ -d "$root/$pkg" ] || { echo '{"error":"the package directory is not present in this checkout"}'; return; }
  have python3 || { echo '{"error":"python3 is not on PATH"}'; return; }
  # Best effort. The breakdown below is pure AST and needs nothing installed,
  # so a failed pip must not take the metric down with it -- it only decides
  # whether the reference implementation or our own arithmetic produces the
  # headline number, and the page says which.
  python3 -c 'import cognitive_complexity' 2>/dev/null \
    || pip install --quiet cognitive-complexity >/dev/null 2>&1 || true

  python3 - "$root/$pkg" <<'PY' 2>/dev/null || echo '{"error":"the python pass raised"}'
import ast, json, sys, pathlib
try:
    from cognitive_complexity.api import get_cognitive_complexity
    ENGINE = "reference implementation"
except Exception:
    get_cognitive_complexity = None
    ENGINE = "same rules as the shell pass (reference package unavailable)"

THRESHOLD = 15


def breakdown(fn):
    """Which constructs produced the score, and what each contributed.

    The reference implementation returns a number and nothing else, so the
    argus column read "102" with an empty explanation -- a figure nobody can
    check or act on. This walks the same nodes Campbell's rules increment on
    and reports the arithmetic beside it.

    It EXPLAINS the score rather than deriving it: the authoritative number
    stays the library's. Where the two disagree the page says so, which is
    better than quietly showing a total nobody can reproduce.
    """
    counts, total = {}, 0

    def bump(kind, n):
        nonlocal total
        if n:
            counts[kind] = counts.get(kind, 0) + n
            total += n

    NEST = (ast.If, ast.For, ast.AsyncFor, ast.While, ast.Try, ast.With,
            ast.AsyncWith, ast.ExceptHandler)

    def walk(node, depth):
        for child in ast.iter_child_nodes(node):
            inc, nxt = 0, depth
            if isinstance(child, (ast.If, ast.For, ast.AsyncFor, ast.While)):
                inc, nxt = 1, depth + 1
                bump(type(child).__name__.lower(), 1)
            elif isinstance(child, ast.ExceptHandler):
                inc, nxt = 1, depth + 1
                bump("except", 1)
            elif isinstance(child, ast.BoolOp):
                bump("and/or", 1)
            elif isinstance(child, ast.IfExp):
                bump("ternary", 1)
            elif isinstance(child, (ast.Break, ast.Continue)):
                bump("break/continue", 1)
            elif isinstance(child, NEST):
                nxt = depth + 1
            if inc and depth:
                bump("nesting", depth)
            walk(child, nxt)

    walk(fn, 0)
    counts["= explained"] = total
    return counts


units = []
root = pathlib.Path(sys.argv[1]).parent   # the checkout root, not the package
for f in pathlib.Path(sys.argv[1]).rglob("*.py"):
    if "/tests/" in str(f) or "__pycache__" in str(f):
        continue
    try:
        tree = ast.parse(f.read_text(errors="replace"))
    except SyntaxError:
        continue
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            why = breakdown(node)
            if get_cognitive_complexity is not None:
                try:
                    c = get_cognitive_complexity(node)
                except Exception:
                    c = why.get("= explained", 0)
            else:
                c = why.get("= explained", 0)
            # relative to the checkout root, so the page can build a blob URL
            units.append({"file": str(f.relative_to(root)), "name": node.name,
                          "line": node.lineno, "score": c, "why": why})
units.sort(key=lambda u: -u["score"])
print(json.dumps({
    "worst": units[0]["score"] if units else 0,
    "worst_at": (units[0]["file"] + ":" + units[0]["name"]) if units else None,
    "over_threshold": sum(1 for u in units if u["score"] > THRESHOLD),
    "threshold": THRESHOLD,
    "units": len(units),
    "language": "python (" + ENGINE + ")",
    "top": units[:8],
}))
PY
}

cognitive_shell() {
  local root="$1"
  have python3 || { echo '{"error":"python3 is not on PATH"}'; return; }
  python3 - "$root" <<'PY' 2>/dev/null || echo '{"error":"the shell pass raised"}'
import json, re, sys, pathlib

# Campbell's Cognitive Complexity, applied to shell. Each construct that breaks
# linear reading costs 1, plus the nesting depth it sits at. Boolean operators
# cost 1 per sequence, not per operator. `else`/`elif` cost 1 flat, with no
# nesting surcharge, because the reader is already in the construct.
THRESHOLD = 15
OPEN  = re.compile(r'^\s*(if|for|while|until|case)\b')
CLOSE = re.compile(r'^\s*(fi|done|esac)\b')
FLAT  = re.compile(r'^\s*(elif|else)\b')
ARM   = re.compile(r'^\s*[^()\s|][^()]*\)\s*$')          # a case arm
BOOL  = re.compile(r'(\&\&|\|\|)')
FUNC  = re.compile(r'^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{')

HEREDOC = re.compile(r"<<-?\s*[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]?")

def mask_heredocs(lines):
    """Blank heredoc BODIES, keeping line numbers intact.

    These scripts embed JavaScript, CSS and jq programs in heredocs. To bash
    those bodies are data -- it does not branch on them -- but they are full of
    `if`, `&&`, `||` and `function foo() {`. Counting them scored the embedded
    language and attributed it to the shell: generate-dashboard.sh came out at
    1955, and the "worst function" was a JavaScript one.

    Blanked rather than removed so every reported line number still points at
    the real line in the file. A number offered as proof has to survive being
    looked up.
    """
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)                 # the opener itself is real shell
        m = HEREDOC.search(line)
        if m:
            term = m.group(1)
            i += 1
            while i < len(lines) and lines[i].strip() != term:
                out.append("")           # body: data, not control flow
                i += 1
            if i < len(lines):
                out.append(lines[i])     # the terminator
        i += 1
    return out

def score_lines(lines, start_at=1):
    """Campbell's rules, recording the arithmetic as well as the total.

    `why` used to count constructs only, so it did not add up to the score --
    the nesting surcharge was invisible and the number could not be checked by
    hand. Nesting is now its own entry, and base + nesting == total.
    """
    depth, total, why = 0, 0, {}
    def bump(kind, n):
        why[kind] = why.get(kind, 0) + n
    in_case = 0
    for raw in lines:
        line = raw.split('#', 1)[0] if raw.lstrip().startswith('#') else raw
        if CLOSE.match(line):
            depth = max(0, depth - 1)
            if re.match(r'^\s*esac\b', line):
                in_case = max(0, in_case - 1)
            continue
        if FLAT.match(line):
            total += 1; bump('else/elif', 1); continue
        m = OPEN.match(line)
        if m:
            total += 1 + depth
            bump(m.group(1), 1)
            if depth:
                bump("nesting", depth)     # the surcharge, made visible
            depth += 1
            if m.group(1) == 'case':
                in_case += 1
            continue
        if in_case and ARM.match(line) and not line.strip().startswith('esac'):
            total += 1; bump('case arm', 1)
        nb = len(BOOL.findall(line))
        if nb:
            total += 1; bump('&&/||', 1)
    return total, why

units = []
root = pathlib.Path(sys.argv[1])

# 1. shell scripts: one unit per function, plus the top level as a unit
for f in sorted(root.glob(".github/scripts/*.sh")):
    lines = mask_heredocs(f.read_text(errors="replace").splitlines())
    rel = str(f.relative_to(root))
    cur, buf, start, depth_guard = None, [], 0, 0
    toplevel = []
    for i, line in enumerate(lines, 1):
        m = FUNC.match(line)
        if m and cur is None:
            cur, buf, start = m.group(1), [], i
            depth_guard = 1
            continue
        if cur is not None:
            depth_guard += line.count('{') - line.count('}')
            if depth_guard <= 0:
                sc, why = score_lines(buf)
                units.append({"file": rel, "name": cur + "()", "line": start,
                              "score": sc, "why": why})
                cur = None
            else:
                buf.append(line)
        else:
            toplevel.append(line)
    sc, why = score_lines(toplevel)
    if sc:
        units.append({"file": rel, "name": "(top level)", "line": 1,
                      "score": sc, "why": why})

# 2. workflow `run:` blocks: one unit each, since each is an executable body
RUN = re.compile(r'^(\s*)(?:- name:.*\n\s*)?\s*run:\s*\|')
for f in sorted(root.glob(".github/workflows/*.yml")):
    lines = f.read_text(errors="replace").splitlines()
    rel = str(f.relative_to(root))
    i = 0
    while i < len(lines):
        m = re.match(r'^(\s*)run:\s*\|', lines[i])
        if not m:
            i += 1; continue
        indent = len(m.group(1))
        start = i + 1
        body, j = [], i + 1
        while j < len(lines):
            ln = lines[j]
            if ln.strip() and (len(ln) - len(ln.lstrip())) <= indent:
                break
            body.append(ln); j += 1
        sc, why = score_lines(mask_heredocs(body))
        if sc:
            units.append({"file": rel, "name": f"run: block @{start}",
                          "line": start, "score": sc, "why": why})
        i = j

units.sort(key=lambda u: -u["score"])
print(json.dumps({
    "worst": units[0]["score"] if units else 0,
    "worst_at": (units[0]["file"] + ":" + units[0]["name"]) if units else None,
    "over_threshold": sum(1 for u in units if u["score"] > THRESHOLD),
    "threshold": THRESHOLD,
    "units": len(units),
    "language": "shell + Actions YAML",
    "top": units[:8],
}))
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
SUITE_COG=$(cognitive_shell "$REPO_ROOT")
SUITE=$(jq -n -c --argjson dup "${SUITE_DUP:-null}" --argjson tup "${SUITE_TUP:-null}" \
  --argjson cog "${SUITE_COG:-null}" \
  '{target:"suite", duplication:$dup, cognitive:$cog, tuple_dupes:$tup}')

if [ -n "$ARGUS_DIR" ] && [ -d "$ARGUS_DIR" ]; then
  echo "Measuring argus (${ARGUS_DIR})..."
  A_DUP=$(duplication "$ARGUS_DIR" argus)
  A_COG=$(cognitive_python "$ARGUS_DIR" argus)
  ARGUS=$(jq -n -c --argjson dup "${A_DUP:-null}" --argjson cog "${A_COG:-null}" \
    '{target:"argus", duplication:$dup, cognitive:$cog, tuple_dupes:null}')
else
  echo "No argus checkout supplied; the argus panel will read 'not measured'."
  ARGUS='{"target":"argus","duplication":{"error":"no argus checkout was supplied to this run"},"cognitive":{"error":"no argus checkout was supplied to this run"},"tuple_dupes":null}'
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
