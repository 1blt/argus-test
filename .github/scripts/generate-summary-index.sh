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
# to it; the hub computes nothing of its own. Figures come from history.json,
# which the dashboard writes, so the two cannot disagree in public.
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
source "$SCRIPT_DIR/site-nav.sh"
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

# NO LETTER GRADE. The dashboard removed one deliberately -- its own comment
# calls it "the trap the letter grade fell into" -- because a single letter is
# severity-blind: a silent pass and a broken SARIF upload each cost it one
# test, so 95% renders as "good" over a state that includes scans reporting
# success without scanning. The headline is the same pair the board uses: the
# severity-weighted risk index, which carries the colour, and an uncoloured
# pass rate, which is a breadth figure and nothing more.
#
# Both are READ from history.json rather than recomputed, so this page cannot
# drift from the board. history.json is written by generate-dashboard.sh after
# the catalog exists, which is why `defined` here is every test the suite
# declares and not merely the ones that reported.
HISTORY_FILE="${HISTORY_FILE:-$OUT_DIR/history.json}"
LATEST='null'
if [ -f "$HISTORY_FILE" ] && jq empty "$HISTORY_FILE" 2>/dev/null; then
  LATEST=$(jq -c '.[-1] // null' "$HISTORY_FILE")
fi
# Fall back to the locally computed stats if history is missing, so the hub
# still renders rather than showing blanks.
HEAD_JSON=$(jq -n -c --argjson l "$LATEST" --argjson s "$STATS" '
  ($l // {}) as $h
  | { passed:   ($h.passed   // $s.passed),
      defined:  ($h.defined  // $s.total),
      failed:   $s.failed,
      skipped:  $s.skipped,
      risk:     ($h.risk     // $s.risk),
      pct:      ($h.pct_defined // (if ($s.total) > 0 then (($s.passed / $s.total) * 100 | floor) else 0 end)),
      worst:    ($h.worst    // $s.worst),
      prevRisk: null }')
# Movement against the previous run, so the number has a direction.
HEAD_JSON=$(jq -c --argjson hist "$(jq -c '.' "$HISTORY_FILE" 2>/dev/null || echo '[]')" '
  . + { prevRisk: ($hist | if length > 1 then .[-2].risk else null end) }' <<<"$HEAD_JSON")

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
__NAV_CSS__
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
     color:var(--fg); margin:0 0 6px; display:flex; align-items:center; }
/* Argus's eye beside the title. Grayscaled deliberately: it is a mark, not a
   status light, and the page already spends colour on severity -- a green eye
   next to a red risk number competes with the one signal that should carry it.
   The source is the same 32x32 PNG used as the favicon, so nothing extra is
   fetched. Slightly darkened in light mode: the green grayscales to about
   #a1a1a1, which sits well on near-black but is weak on white.
   aria-hidden because the title beside it already says the name. */
.eye { height: 1.2em; width: auto; vertical-align: -0.2em; margin-right: 0.55em;
       filter: grayscale(1) brightness(0.72); }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) .eye { filter: grayscale(1) brightness(1.05); }
}
:root[data-theme="dark"] .eye { filter: grayscale(1) brightness(1.05); }
:root[data-theme="light"] .eye { filter: grayscale(1) brightness(0.72); }

.meta { font-size:0.76rem; color:var(--fg3); margin-bottom:30px; }
.meta .sep { margin:0 8px; opacity:0.5; }
.meta a { color:inherit; }
.chip { display:inline-block; padding:1px 7px; border:1px solid var(--border); font-size:0.66rem;
        font-weight:700; letter-spacing:0.04em; text-transform:uppercase; white-space:nowrap; cursor:help; }
.chip-warn { color:var(--warn-ink); background:var(--warn-bg); border-color:var(--warn); }
.chip-ok { color:var(--pass-ink); background:var(--pass-bg); border-color:var(--pass); }
.verdict { display:flex; align-items:baseline; gap:16px; border:1px solid var(--border);
           padding:20px 22px; background:var(--surface); margin-bottom:12px; flex-wrap:wrap; }
.hstats { display:flex; gap:30px; flex:0 0 auto; }
.hstat .n { font-size:2.2rem; font-weight:300; line-height:1; color:var(--fg); }
.hstat .n.bad { color:var(--fail-ink); } .hstat .n.warn { color:var(--warn-ink); }
.hstat .n.good { color:var(--pass-ink); }
.hstat .l { font-size:0.62rem; text-transform:uppercase; letter-spacing:0.07em;
            color:var(--fg3); margin-top:5px; }
.hstat .s { font-size:0.7rem; color:var(--fg3); }
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
  <div class="nav" id="nav"></div>
  <h1><img class="eye" src="favicon.png" alt="" aria-hidden="true">Argus Test Suite</h1>
  <div class="meta" id="meta"></div>
  <div id="verdict"></div>
  <div class="cards" id="cards"></div>
  <footer id="foot"></footer>
</div>
<script>
HTMLEOF

{
  echo "const S = $STATS;
const HEAD = $HEAD_JSON;"
  echo "const CLEAN = $CLEAN_JSON;"
  echo "const LIVE = $LIVENESS_JSON;"
  echo "const FC = $CLASSES_JSON;"
  echo "const GAPS = $GAPS_JSON;"
  echo "const PAGE = {"
  echo "  date: \"${DATE_STR}\","
  echo "  branch: \"${BRANCH:-}\","
  echo "  argusRef: \"${ARGUS_REF:-}\","
  echo "  argusRepo: \"${ARGUS_REPO:-}\","
  echo "  argusSha: \"${ARGUS_SHA:-}\","
  echo "  argusVersion: \"${ARGUS_VERSION:-}\","
  echo "  runUrl: \"${RUN_URL:-}\","
  echo "  slug: \"${BRANCH_SLUG:-}\","
  printf '  branches: %s\n' "${BRANCHES_JSON:-[]}"
  echo "};"
} >> "$OUT_DIR/index.html"

cat >> "$OUT_DIR/index.html" << 'HTMLEOF2'
__NAV_JS__
(function () {
  function $(id) { return document.getElementById(id); }
  renderNav({ el: 'nav', branch: PAGE.branch, slug: PAGE.slug || PAGE.branch,
              page: 'summary', branches: PAGE.branches || [], up: '' });
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // ---- header --------------------------------------------------------------
  var m = [];
  if (PAGE.branch) m.push('branch <span class="mono">' + esc(PAGE.branch) + '</span>');
  // Same rule as the board: the label is what a human recognises, the href is
  // the most specific immutable object. Never /tree/<branch> -- it shows
  // whatever the branch became, and 404s once the PR branch is deleted, which
  // is the normal end state for every ref this suite is pointed at.
  if (PAGE.argusRepo && PAGE.argusRef) {
    var server = (PAGE.runUrl || 'https://github.com').split('/').slice(0, 3).join('/');
    var base = server + '/' + PAGE.argusRepo;
    var onMain = PAGE.argusRef === 'main';
    var known = PAGE.argusSha && PAGE.argusSha !== 'unknown';
    m.push((onMain && PAGE.argusVersion
      ? '<a href="' + base + '/releases/tag/' + esc(PAGE.argusVersion) +
        '" title="the release a consumer would pin">argus <span class="mono">v' +
        esc(PAGE.argusVersion) + '</span></a>'
      : 'argus <span class="mono">' + esc(PAGE.argusRef) + '</span>') +
      (known
        ? ' <a class="mono" href="' + base + '/commit/' + esc(PAGE.argusSha) +
          '" title="the exact commit under test -- this link cannot move">' +
          esc(String(PAGE.argusSha).slice(0, 7)) + '</a>'
        : ''));
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
  var st = STATUS[HEAD.worst] || STATUS[S.worst] || STATUS.none ||
           { word: S.failed ? 'FAIL' : 'PASS', line: '' };
  // Risk carries the colour, because severity is what it measures. Pass rate
  // stays uncoloured on purpose -- it is severity-blind by construction, so
  // rendering it green would say "good" about a state that can include a scan
  // reporting success without scanning. Same rule as the board.
  var move = '';
  if (HEAD.prevRisk !== null && HEAD.prevRisk !== undefined) {
    var d = HEAD.risk - HEAD.prevRisk;
    move = d === 0 ? 'no change vs last run'
         : (d > 0 ? '\u25b2 +' + d : '\u25bc ' + d) + ' vs last run';
  }
  $('verdict').innerHTML =
    '<div class="verdict">' +
      '<div class="hstats">' +
        '<div class="hstat"><div class="n ' + (HEAD.risk ? (st.tone || 'bad') : 'good') + '">' +
          esc(HEAD.risk) + '</div><div class="l">Risk index</div></div>' +
        '<div class="hstat"><div class="n">' + esc(HEAD.pct) + '%</div>' +
          '<div class="l">Passing <span class="s">' + esc(HEAD.passed) + '/' + esc(HEAD.defined) +
          '</span></div></div>' +
      '</div>' +
      '<div class="vtext">' +
        '<div class="vword">' + esc(st.word || '') + '</div>' +
        '<div class="vline">' + esc(st.line || '') + '</div>' +
        (move ? '<div class="vline">' + esc(move) + '</div>' : '') +
      '</div>' +
      '<div class="figs">' +
        fig(S.failed, 'failed', S.failed ? 'bad' : '') +
        fig(S.skipped, 'no assurance', S.skipped ? 'warn' : '') +
        fig(HEAD.defined, 'defined', '') +
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
        fig(HEAD.passed + '/' + HEAD.defined, 'passing', '') +
        fig(HEAD.risk, 'risk index', HEAD.risk ? 'bad' : '') +
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

splice_nav "$OUT_DIR/index.html"

echo "Summary hub written: $OUT_DIR/index.html ($(jq -r '"\(.passed)/\(.defined) passing, risk \(.risk), worst \(.worst)"' <<<"$HEAD_JSON"))"
