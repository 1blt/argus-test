#!/usr/bin/env bash
# =============================================================================
# The branch hub: _site/<branch>/index.html
#
# Two child pages answer two different questions, and they are not the same
# kind of question:
#
#   tests/            does argus still behave the way a consumer expects?
#   code-cleanliness/ how tidy is the code, on metrics nothing gates?
#
# The hub exists so neither is read as part of the other's verdict. It carries
# the headline of each and the ref both were measured against -- in particular
# the liveness split, because "argus@<branch>" on a card is a claim about what
# was tested and it is only half true for a branch.
#
# Deliberately thin. Every number here is restated from a child page and links
# to it; the hub computes nothing of its own except the grade, which has to
# match the dashboard's rule exactly or the two pages disagree in public.
#
# Env:
#   OUT_DIR       <branch> directory (index.html is written into it)
#   ALL_JSON      merged results array, same as the dashboard receives
#   CLEAN_FILE    cleanliness.json          (optional)
#   LIVENESS_FILE ref-liveness.json         (optional)
#   GAPS_FILE     coverage-gaps.json        (optional)
#   CLASSES_FILE  failure-classes.json      (optional)
#   BRANCH, ARGUS_REF, ARGUS_REPO, ARGUS_VERSION, RUN_URL, DATE_STR
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT_DIR="${OUT_DIR:?OUT_DIR not set}"
mkdir -p "$OUT_DIR"

ALL_JSON="${ALL_JSON:-[]}"
echo "$ALL_JSON" | jq empty 2>/dev/null || ALL_JSON='[]'
CLASSES_FILE="${CLASSES_FILE:-$SCRIPT_DIR/../data/failure-classes.json}"
GAPS_FILE="${GAPS_FILE:-$SCRIPT_DIR/../data/coverage-gaps.json}"
DATE_STR="${DATE_STR:-$(date -u '+%Y-%m-%d %H:%M UTC')}"

read_json() { [ -f "$1" ] && jq empty "$1" 2>/dev/null && jq -c '.' "$1" || echo 'null'; }
CLEAN_JSON=$(read_json "${CLEAN_FILE:-/nonexistent}")
LIVENESS_JSON=$(read_json "${LIVENESS_FILE:-/nonexistent}")
CLASSES_JSON=$(read_json "$CLASSES_FILE")
GAPS_RAW=$(read_json "$GAPS_FILE")
GAPS_JSON=$(jq -c 'if . == null then {gaps:[],retired:[]}
                   elif type == "array" then {gaps:., retired:[]}
                   else {gaps:(.gaps // []), retired:(._retired // [])} end' <<<"$GAPS_RAW")

# ---- stats, computed the same way the dashboard computes them --------------
STATS=$(jq -n -c --argjson all "$ALL_JSON" --argjson fc "$CLASSES_JSON" '
  ($fc // {}) as $f
  | (($f.weights) // {open:10, degraded:6, closed:3, auxiliary:1}) as $w
  | (($f.default) // "closed") as $dflt
  | (($f.classes) // {} | to_entries | map(.value[] as $id | {key:$id, value:.key}) | from_entries) as $cls
  | ($all | length) as $total
  | [$all[] | select(.status == "pass")] as $passed
  | [$all[] | select(.status == "FAIL")] as $failed
  | [$all[] | select(.status == "skip" or .status == "cancel")] as $skipped
  | ($failed | map($cls[.id] // $dflt)) as $fclasses
  | {
      total: $total,
      passed: ($passed | length),
      failed: ($failed | length),
      skipped: ($skipped | length),
      risk: ([$fclasses[] | $w[.] // 0] | add // 0),
      byClass: ($fclasses | group_by(.) | map({key: .[0], value: length}) | from_entries),
      # Severity order derives from the weights, so a class added to
      # failure-classes.json ranks itself rather than being silently dropped.
      worst: (($w | to_entries | sort_by(-.value) | map(.key))
              | map(select(. as $c | $fclasses | index($c)))
              | first // "none")
    }')

# Grade: passed over every test the suite DEFINES, so a run that skipped most of
# itself scores as no assurance rather than as an A. A single failure caps at B,
# because "96% passing" is not an A when the missing 4% is a gate that stopped
# enforcing. Identical to the dashboard's rule -- if one changes, both must.
GRADE=$(jq -n -r --argjson s "$STATS" '
  ($s.total) as $t
  | (if $t == 0 then 0 else ($s.passed / $t * 100) end) as $pct
  | (if   $pct >= 97 then "A+" elif $pct >= 93 then "A" elif $pct >= 90 then "A-"
     elif $pct >= 87 then "B+" elif $pct >= 83 then "B" elif $pct >= 80 then "B-"
     elif $pct >= 70 then "C"  elif $pct >= 60 then "D" else "F" end) as $g
  | if $s.failed > 0 and ($g | startswith("A")) then "B+" else $g end')

cat > "$OUT_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Argus Test Suite</title>
<link rel="icon" type="image/png" href="favicon.png">
<link rel="apple-touch-icon" href="favicon.png">
<style>
@import url('https://fonts.googleapis.com/css2?family=Nunito+Sans:ital,wght@0,300;0,400;0,600;0,700&display=swap');
:root {
  --bg:#ffffff; --surface:#ffffff; --surface2:#f8f9fa;
  --fg:#1a1a1a; --fg2:#55595c; --fg3:#919aa1;
  --border:#dee2e6; --rule:#ebedef;
  --pass:#4bbf73; --pass-bg:#edf9f1; --pass-ink:#2f8f52;
  --fail:#d9534f; --fail-bg:#fdefee; --fail-ink:#b8413d;
  --warn:#f0ad4e; --warn-bg:#fef7ec; --warn-ink:#a3701f;
  --idle:#919aa1; --idle-bg:#f3f5f6;
  --track:0.08em;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg:#101214; --surface:#15181b; --surface2:#15181b;
    --fg:#ece9e4; --fg2:#a7adb3; --fg3:#737b82;
    --border:#282d32; --rule:#1e2226;
    --pass-bg:#16241b; --pass-ink:#79d199;
    --fail-bg:#2a1719; --fail-ink:#e88b87;
    --warn-bg:#2a2116; --warn-ink:#e0b271;
    --idle-bg:#1a1d20;
  }
}
* { box-sizing:border-box; }
body { font-family:"Nunito Sans",-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
       background:var(--bg); color:var(--fg2); margin:0; line-height:1.55;
       -webkit-font-smoothing:antialiased; }
.wrap { max-width:900px; margin:0 auto; padding:48px 16px 64px; }
a { color:inherit; }
.mono { font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:0.92em; }
h1 { font-size:1.15rem; font-weight:700; text-transform:uppercase; letter-spacing:0.1em;
     color:var(--fg); margin:0 0 6px; }
.meta { font-size:0.76rem; color:var(--fg3); margin-bottom:30px; }
.meta .sep { margin:0 8px; opacity:0.5; }
.meta a { color:inherit; }
.chip { display:inline-block; padding:1px 7px; border:1px solid var(--border); font-size:0.66rem;
        font-weight:700; letter-spacing:0.04em; text-transform:uppercase; white-space:nowrap; cursor:help; }
.chip-warn { color:var(--warn-ink); background:var(--warn-bg); border-color:var(--warn); }
.chip-ok { color:var(--pass-ink); background:var(--pass-bg); border-color:var(--pass); }
.verdict { display:flex; align-items:baseline; gap:16px; border:1px solid var(--border);
           padding:20px 22px; background:var(--surface); margin-bottom:12px; flex-wrap:wrap; }
.grade { font-size:3rem; font-weight:300; line-height:1; color:var(--fg); }
.grade.bad { color:var(--fail-ink); }
.grade.good { color:var(--pass-ink); }
.vtext { flex:1 1 260px; }
.vword { font-size:0.8rem; font-weight:700; text-transform:uppercase; letter-spacing:var(--track); color:var(--fg); }
.vline { font-size:0.8rem; color:var(--fg3); margin-top:2px; }
.cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:12px; margin-top:12px; }
.card { display:block; border:1px solid var(--border); padding:18px 20px; background:var(--surface);
        text-decoration:none; color:inherit; transition:border-color .12s; }
.card:hover { border-color:var(--fg); }
.card h2 { font-size:0.72rem; font-weight:700; text-transform:uppercase; letter-spacing:0.07em;
           color:var(--fg); margin:0 0 3px; }
.card .sub { font-size:0.74rem; color:var(--fg3); margin-bottom:12px; min-height:2.6em; }
.figs { display:flex; gap:18px; flex-wrap:wrap; }
.fig .n { font-size:1.35rem; font-weight:300; color:var(--fg); line-height:1.1; }
.fig .n.bad { color:var(--fail-ink); }
.fig .n.warn { color:var(--warn-ink); }
.fig .n.na { font-size:0.82rem; color:var(--fg3); padding:7px 0 2px; }
.fig .l { font-size:0.63rem; text-transform:uppercase; letter-spacing:0.06em; color:var(--fg3); }
.more { font-size:0.7rem; text-transform:uppercase; letter-spacing:0.06em; color:var(--fg3); margin-top:14px; }
footer { margin-top:40px; padding-top:18px; border-top:1px solid var(--border);
         font-size:0.72rem; color:var(--fg3); }
@media (max-width:640px) { .cards { grid-template-columns:1fr; } .wrap { padding:32px 16px 48px; } }
</style>
</head>
<body>
<div class="wrap">
  <h1>Argus Test Suite</h1>
  <div class="meta" id="meta"></div>
  <div id="verdict"></div>
  <div class="cards" id="cards"></div>
  <footer id="foot"></footer>
</div>
<script>
HTMLEOF

{
  echo "const S = $STATS;"
  echo "const CLEAN = $CLEAN_JSON;"
  echo "const LIVE = $LIVENESS_JSON;"
  echo "const FC = $CLASSES_JSON;"
  echo "const GAPS = $GAPS_JSON;"
  echo "const PAGE = {"
  echo "  grade: \"${GRADE}\","
  echo "  date: \"${DATE_STR}\","
  echo "  branch: \"${BRANCH:-}\","
  echo "  argusRef: \"${ARGUS_REF:-}\","
  echo "  argusRepo: \"${ARGUS_REPO:-}\","
  echo "  argusVersion: \"${ARGUS_VERSION:-}\","
  echo "  runUrl: \"${RUN_URL:-}\""
  echo "};"
} >> "$OUT_DIR/index.html"

cat >> "$OUT_DIR/index.html" << 'HTMLEOF2'
(function () {
  function $(id) { return document.getElementById(id); }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // ---- header --------------------------------------------------------------
  var m = [];
  if (PAGE.branch) m.push('branch <span class="mono">' + esc(PAGE.branch) + '</span>');
  if (PAGE.argusRepo && PAGE.argusRef) {
    var server = (PAGE.runUrl || 'https://github.com').split('/').slice(0, 3).join('/');
    var onMain = PAGE.argusRef === 'main';
    m.push(onMain && PAGE.argusVersion
      ? '<a href="' + server + '/' + PAGE.argusRepo + '/releases/tag/' + esc(PAGE.argusVersion) +
        '">argus <span class="mono">v' + esc(PAGE.argusVersion) + '</span></a>'
      : '<a href="' + server + '/' + PAGE.argusRepo + '/tree/' + esc(PAGE.argusRef) + '">argus@' +
        esc(PAGE.argusRef) + '</a>');
  }
  // The liveness split belongs on the hub, not only on the dashboard: both
  // child pages were measured against this ref, and for a branch the label is
  // only half true.
  if (LIVE && LIVE.summary) {
    var L = LIVE.summary;
    if (L.sdk_live === false) {
      var pins = (L.sdk_pins || []).join(', ') || 'a release tag';
      m.push('<span class="chip chip-warn" title="' + esc(
        'The entry-point workflow YAML comes from ' + (L.ref || 'this ref') + ', but all ' +
        L.stale_nested + ' nested references stay pinned (' + L.live_nested + ' live). ' +
        'setup-argus installs the SDK from its own checkout, so the Python under test is ' + pins +
        '. SDK behaviour is covered by the Runtime Environment tests, which check argus out at the ref.') +
        '">YAML from ref &middot; SDK <span class="mono">' + esc(pins) + '</span></span>');
    } else if (L.sdk_live === true) {
      m.push('<span class="chip chip-ok" title="Workflow YAML and SDK both resolve to this ref.">fully branch-live</span>');
    }
  }
  m.push(esc(PAGE.date));
  if (PAGE.runUrl) m.push('<a href="' + esc(PAGE.runUrl) + '">view run &#8599;</a>');
  $('meta').innerHTML = m.join('<span class="sep">&middot;</span>');

  // ---- verdict -------------------------------------------------------------
  var STATUS = (FC && FC.status) || {};
  var st = STATUS[S.worst] || STATUS.none ||
           { word: S.failed ? 'FAIL' : 'PASS', line: '' };
  var tone = S.failed > 0 ? 'bad' : (S.passed > 0 ? 'good' : '');
  $('verdict').innerHTML =
    '<div class="verdict">' +
      '<div class="grade ' + tone + '">' + esc(PAGE.grade) + '</div>' +
      '<div class="vtext">' +
        '<div class="vword">' + esc(st.word || '') + '</div>' +
        '<div class="vline">' + esc(st.line || '') + '</div>' +
      '</div>' +
      '<div class="figs">' +
        fig(S.passed, 'passed', '') +
        fig(S.failed, 'failed', S.failed ? 'bad' : '') +
        fig(S.skipped, 'no assurance', S.skipped ? 'warn' : '') +
        fig(S.total, 'defined', '') +
      '</div>' +
    '</div>';

  function fig(n, label, cls) {
    return '<div class="fig"><div class="n ' + (cls || '') + '">' + esc(n) +
           '</div><div class="l">' + esc(label) + '</div></div>';
  }
  function figNA(text, label) {
    return '<div class="fig"><div class="n na">' + esc(text) +
           '</div><div class="l">' + esc(label) + '</div></div>';
  }

  // ---- child pages ---------------------------------------------------------
  var cards = '';

  var gapN = (GAPS.gaps || []).length, retN = (GAPS.retired || []).length;
  cards +=
    '<a class="card" href="tests/">' +
      '<h2>Test results</h2>' +
      '<div class="sub">Does argus still behave the way a consumer expects? Every test the suite ' +
      'defines, searchable in plain language.</div>' +
      '<div class="figs">' +
        fig(S.passed + '/' + S.total, 'passing', '') +
        fig(S.risk, 'risk index', S.risk ? 'bad' : '') +
        fig(gapN, 'known gaps', '') +
        (retN ? fig(retN, 'gaps retired', '') : '') +
      '</div>' +
      '<div class="more">Open the board &rarr;</div>' +
    '</a>';

  if (CLEAN && CLEAN.targets) {
    var su = CLEAN.targets.suite || {}, ar = CLEAN.targets.argus || {};
    var td = su.tuple_dupes;
    var unexplained = td ? ((td.exact_rows || 0) + (td.invocation_rows || 0)) : null;
    var dupPct = (su.duplication && su.duplication.percent != null)
      ? Number(su.duplication.percent).toFixed(1) + '%' : null;
    var cog = (ar.cognitive && ar.cognitive.worst != null) ? ar.cognitive.worst : null;

    cards +=
      '<a class="card" href="code-cleanliness/">' +
        '<h2>Code cleanliness</h2>' +
        '<div class="sub">KISS and DRY indicators for this suite and for argus. Reported, never ' +
        'gated &mdash; nothing here can fail a build.</div>' +
        '<div class="figs">' +
          (dupPct !== null ? fig(dupPct, 'suite duplication', '') : figNA('not measured', 'suite duplication')) +
          (unexplained !== null ? fig(unexplained, 'duplicate tuples', unexplained ? 'warn' : '') : '') +
          (cog !== null ? fig(cog, 'argus cognitive, worst', '') : figNA('not measured', 'argus cognitive')) +
        '</div>' +
        '<div class="more">Metrics, rationale and citations &rarr;</div>' +
      '</a>';
  }

  $('cards').innerHTML = cards;

  $('foot').innerHTML =
    'The two pages answer different questions and are kept apart on purpose: a duplication figure is ' +
    'not part of whether argus behaves correctly, and nothing on the cleanliness page gates anything. ' +
    'Generated by the test suite CI on every push.';
})();
</script>
</body>
</html>
HTMLEOF2

echo "Summary hub written: $OUT_DIR/index.html (grade $GRADE, worst $(jq -r '.worst' <<<"$STATS"))"
