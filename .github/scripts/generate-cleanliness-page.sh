#!/usr/bin/env bash
# =============================================================================
# The code-cleanliness page: _site/<branch>/code-cleanliness/index.html
#
# Split off the board because nothing here gates anything, and a duplication
# figure under the verdict reads as though it were part of it.
#
# The page leads with EVIDENCE, not prose: every number is followed by the
# file and line range behind it, so a reader checks it instead of believing it.
#
# There is no "not applicable" state. A metric that cannot be produced renders
# as a fault with its reason, because a blank cell and a clean result look the
# same, and this suite exists to reject exactly that equivalence.
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/site-nav.sh"
CLEAN_FILE="${CLEAN_FILE:?CLEAN_FILE not set}"
CLEAN_CFG_FILE="${CLEAN_CFG_FILE:-$SCRIPT_DIR/../data/cleanliness-metrics.json}"
OUT_DIR="${OUT_DIR:?OUT_DIR not set}"

if [ ! -f "$CLEAN_FILE" ] || ! jq empty "$CLEAN_FILE" 2>/dev/null; then
  echo "No readable $CLEAN_FILE -- skipping the cleanliness page."
  exit 0
fi
if [ ! -f "$CLEAN_CFG_FILE" ] || ! jq empty "$CLEAN_CFG_FILE" 2>/dev/null; then
  echo "No readable $CLEAN_CFG_FILE -- skipping the cleanliness page."
  exit 0
fi

mkdir -p "$OUT_DIR"
CLEAN_JSON=$(jq -c '.' "$CLEAN_FILE")
CFG_JSON=$(jq -c '{targets, metrics, references}' "$CLEAN_CFG_FILE")
DATE_STR="${DATE_STR:-$(date -u '+%Y-%m-%d %H:%M UTC')}"

# ---------- history ----------
# The headline figure of each metric, one entry per run, so the page can show
# which way they are moving rather than only where they are. Lives beside the
# board's history.json in the branch directory; CI fetches the published copy
# before this runs, exactly as it does for that file.
#
# A metric that was not measured is recorded as null, never 0, and the plot
# joins straight across it: a run where the detector failed must not read as
# the run where the code got clean. That run's own page already says the
# metric was not measured, so the plot does not repeat it.
HISTORY_FILE="${CLEAN_HISTORY_FILE:-$OUT_DIR/../cleanliness-history.json}"
if [ ! -f "$HISTORY_FILE" ] || ! jq -e 'type == "array"' "$HISTORY_FILE" >/dev/null 2>&1; then
  echo '[]' > "$HISTORY_FILE"
fi
CURRENT_RUN=$(jq -c \
  --arg date "$DATE_STR" \
  --arg self_sha "${SELF_SHA:-}" \
  --arg argus_sha "${ARGUS_SHA:-}" \
  --arg url "${RUN_URL:-}" '
  def ok(m): (m | type) == "object" and (m.error | not);
  def pick(t): {
    # Raw, not rounded here: jq rounds 5.85 up and the page'"'"'s toFixed(1)
    # rounds it down, so the plot said 5.9 over a figure saying 5.8%. The page
    # rounds both the same way.
    duplication: (if ok(t.duplication) then t.duplication.percent else null end),
    cognitive:   (if ok(t.cognitive) then t.cognitive.worst else null end)
  };
  (.targets // {}) as $t
  | {date:$date, self_sha:$self_sha, argus_sha:$argus_sha, url:$url,
     suite: (pick($t.suite) + {tuples: (if ok($t.suite.tuple_dupes)
               then (($t.suite.tuple_dupes.exact_rows // 0) + ($t.suite.tuple_dupes.invocation_rows // 0))
               else null end)}),
     argus: pick($t.argus)}' "$CLEAN_FILE")
# A re-run of the same workflow run replaces its entry instead of adding one.
jq -c --argjson run "$CURRENT_RUN" \
  'map(select($run.url == "" or .url != $run.url)) + [$run] | .[-20:]' \
  "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
HIST_JSON=$(jq -c '.' "$HISTORY_FILE")
echo "Cleanliness history entries: $(jq 'length' "$HISTORY_FILE")"

cat > "$OUT_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Code Cleanliness &middot; Argus Test Suite</title>
<link rel="icon" type="image/png" href="../favicon.png">
<style>
@import url('https://fonts.googleapis.com/css2?family=Nunito+Sans:ital,wght@0,300;0,400;0,600;0,700&display=swap');
__NAV_CSS__
:root {
  --bg:#ffffff; --surface:#ffffff; --surface2:#f8f9fa;
  --fg:#1a1a1a; --fg2:#55595c; --fg3:#919aa1;
  --border:#dee2e6; --rule:#ebedef;
  --pass:#4bbf73; --pass-bg:#edf9f1; --pass-ink:#2f8f52;
  --warn:#f0ad4e; --warn-bg:#fef7ec; --warn-ink:#a3701f;
  --track:0.08em;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg:#101214; --surface:#15181b; --surface2:#15181b;
    --fg:#ece9e4; --fg2:#a7adb3; --fg3:#737b82;
    --border:#282d32; --rule:#1e2226;
    --pass:#4bbf73; --pass-bg:#16241b; --pass-ink:#79d199;
    --warn:#f0ad4e; --warn-bg:#2a2116; --warn-ink:#e0b271;
  }
}
:root[data-theme="dark"] {
  --bg:#101214; --surface:#15181b; --surface2:#15181b;
  --fg:#ece9e4; --fg2:#a7adb3; --fg3:#737b82;
  --border:#282d32; --rule:#1e2226;
  --pass:#4bbf73; --pass-bg:#16241b; --pass-ink:#79d199;
  --warn:#f0ad4e; --warn-bg:#2a2116; --warn-ink:#e0b271;
}
* { box-sizing:border-box; }
body { font-family:"Nunito Sans",-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
       background:var(--bg); color:var(--fg2); margin:0; line-height:1.55;
       -webkit-font-smoothing:antialiased; }
.wrap { max-width:980px; margin:0 auto; padding:40px 16px 64px; }
a { color:inherit; text-decoration:underline; text-underline-offset:2px; text-decoration-thickness:1px; }
a:hover { color:var(--fg); }
.mono { font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:0.92em; }
.back { font-size:0.74rem; text-transform:uppercase; letter-spacing:var(--track); font-weight:700;
        color:var(--fg3); display:inline-block; margin-bottom:18px; }
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

.meta { font-size:0.76rem; color:var(--fg3); margin-bottom:26px; }
.meta .sep { margin:0 8px; opacity:0.5; }
.lede { margin:0; }
.whatis { font-size:0.76rem; color:var(--fg3); max-width:78ch; margin:0 0 12px; line-height:1.5; }
h2 { font-size:0.82rem; font-weight:700; text-transform:uppercase; letter-spacing:var(--track);
     color:var(--fg); margin:40px 0 6px; padding-top:18px; border-top:1px solid var(--border); }
h3 { font-size:0.74rem; font-weight:700; text-transform:uppercase; letter-spacing:0.06em;
     color:var(--fg); margin:24px 0 10px; }
p { font-size:0.82rem; max-width:74ch; }
.figure { display:flex; align-items:baseline; gap:12px; margin:14px 0 8px; }
.fnum { font-size:1.9rem; font-weight:300; color:var(--fg); line-height:1; }
.flab { font-size:0.74rem; color:var(--fg3); }
.fault { border:1px solid var(--warn); background:var(--warn-bg); color:var(--warn-ink);
         padding:10px 13px; margin:14px 0 8px; font-size:0.78rem; }
.flabel { font-size:0.6rem; font-weight:700; text-transform:uppercase; letter-spacing:0.08em;
          border:1px solid var(--warn-ink); padding:0 5px; margin-right:8px; }
.clean { font-size:0.78rem; color:var(--pass-ink); margin:6px 0 10px; }
.clone { border:1px solid var(--border); margin:6px 0; background:var(--surface); }
.clone summary { cursor:pointer; padding:9px 12px; font-size:0.76rem; display:flex;
                 gap:14px; align-items:baseline; flex-wrap:wrap; list-style:none; }
.clone summary::-webkit-details-marker { display:none; }
.clone summary::before { content:'\25b8'; color:var(--fg3); font-size:0.7rem; }
.clone[open] summary::before { content:'\25be'; }
.clone summary:hover { background:var(--surface2); }
.cl-n { font-weight:700; color:var(--fg); font-variant-numeric:tabular-nums; }
.cl-t { color:var(--fg3); font-size:0.72rem; }
.cl-w { color:var(--fg2); font-size:0.73rem; }
.cl-eq { color:var(--fg3); }
.cl-cols { border-top:1px solid var(--rule); }
.cl-hd { display:grid; grid-template-columns:1fr 1fr; font-size:0.68rem; color:var(--fg3);
         padding:7px 12px; background:var(--surface2); border-bottom:1px solid var(--rule); }
/* Vertical scroll only. The two copies WRAP rather than running off sideways:
   a horizontal scrollbar under a side-by-side comparison means reading one
   column, scrolling back, and reading the other, which is the thing the layout
   was supposed to remove.
   Wrapping does not break the pairing, because the pairing is the table ROW --
   a cell that wraps to three visual lines makes its row taller and its
   counterpart stays beside it. table-layout:fixed is what makes the columns
   hold their width instead of stretching to the longest line. */
.cl-scroll { overflow-x:hidden; overflow-y:auto; max-height:460px; }
.cl-diff { width:100%; border-collapse:collapse; table-layout:fixed;
           font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
           font-size:0.68rem; line-height:1.5; }
.cl-diff td { padding:1px 8px; border:none; vertical-align:top; }
.cl-diff tr + tr td { border-top:1px solid color-mix(in srgb, var(--rule) 55%, transparent); }
.cl-diff td.ln { width:3.4em; text-align:right; color:var(--fg3); user-select:none;
                 border-right:1px solid var(--rule); opacity:.65; white-space:nowrap; }
.cl-diff td.cd { color:var(--fg2); white-space:pre-wrap; overflow-wrap:anywhere;
                 word-break:break-word; }
/* Each side gets half of what the line-number gutters leave. */
.cl-diff td.cd { width:calc(50% - 3.4em); }
@media (max-width:720px) { .cl-diff td.ln { width:2.6em; } .cl-diff { font-size:0.64rem; } }
.cl-diff tr.eq td.cd { background:var(--pass-bg); color:var(--pass-ink); }
.cl-diff tr.df td.cd { background:var(--warn-bg); color:var(--warn-ink); }
.cl-sum { font-size:0.7rem; color:var(--fg3); padding:8px 12px; border-top:1px solid var(--rule); }
.cl-frag { margin:0; padding:12px 14px; border-top:1px solid var(--rule); background:var(--surface2);
           font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:0.7rem;
           line-height:1.5; color:var(--fg2); overflow-x:auto; white-space:pre;
           max-height:420px; overflow-y:auto; }
td.num { font-variant-numeric:tabular-nums; color:var(--fg); font-weight:600; }
tr.over td.num { color:var(--warn-ink); }
.unit { color:var(--fg3); }
.why { color:var(--fg3); font-size:0.73rem; }
.more { font-size:0.72rem; color:var(--fg3); margin:4px 0 12px; }
.grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:12px; margin:12px 0 8px; }
.card { border:1px solid var(--border); padding:14px 16px; background:var(--surface); }
.card .t { font-size:0.66rem; font-weight:700; text-transform:uppercase; letter-spacing:0.06em; color:var(--fg3); }
.card .v { font-size:1.75rem; font-weight:300; color:var(--fg); margin:6px 0 4px; line-height:1.1; }
.card .v.na { font-size:0.9rem; color:var(--fg3); font-weight:400; padding:10px 0 6px; }
.card .d { font-size:0.73rem; color:var(--fg3); line-height:1.5; }
.tag { display:inline-block; font-size:0.58rem; font-weight:700; letter-spacing:0.08em;
       border:1px solid var(--border); padding:0 4px; margin-left:6px; color:var(--fg3); vertical-align:middle; }
.note { font-size:0.75rem; color:var(--fg3); margin-top:8px; }
table { width:100%; border-collapse:collapse; margin:10px 0 4px; font-size:0.78rem; }
th { text-align:left; font-size:0.64rem; text-transform:uppercase; letter-spacing:0.07em;
     color:var(--fg3); font-weight:700; padding:6px 10px 6px 0; border-bottom:1px solid var(--border); }
td { padding:8px 10px 8px 0; border-bottom:1px solid var(--rule); vertical-align:top; color:var(--fg2); }
td.k { color:var(--fg); font-weight:600; white-space:nowrap; }
.excluded td.k { color:var(--fg3); text-decoration:line-through; }
.dupe { border:1px solid var(--border); padding:10px 12px; margin:8px 0; font-size:0.78rem; background:var(--surface2); }
.dupe .ids { font-weight:700; color:var(--fg); }
.dupe .why { color:var(--fg3); font-size:0.74rem; margin-top:3px; }
.ok { color:var(--pass-ink); }
.calc h3 { margin:22px 0 8px; }
.eqn { font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:0.86rem;
       color:var(--fg); background:var(--surface2); border:1px solid var(--border);
       padding:14px 18px; margin:0 0 10px; line-height:2.1; overflow-x:auto; }
.eqn .sum { font-size:1.25rem; vertical-align:-0.15em; }
.eqn .cond { display:block; font-size:0.74rem; color:var(--fg3); line-height:1.5; margin-top:6px; }
.eqn .frac { display:inline-block; text-align:center; vertical-align:middle; margin:0 4px; }
.eqn .frac .num { display:block; padding:0 6px 2px; }
.eqn .frac .den { display:block; padding:2px 6px 0; border-top:1px solid var(--fg2); }
.calc p { font-size:0.79rem; max-width:76ch; margin:0 0 8px; }
.calc p.eg { border-left:2px solid var(--border); padding-left:12px; color:var(--fg3); }
.eq { color:var(--fg); font-weight:600; }
.mismatch { color:var(--warn-ink); cursor:help; }
.refs { margin-top:10px; }
.ref { display:flex; gap:10px; font-size:0.73rem; color:var(--fg3); padding:7px 0; border-bottom:1px solid var(--rule); }
.ref .n { font-weight:700; color:var(--fg2); flex:0 0 auto; }
.ref .why { display:block; color:var(--fg3); font-style:italic; margin-top:2px; }
/* Trends: the same drawing as the board's risk and pass-rate plots, one small
   plot per metric. Monochrome for the same reason the board's are -- colour
   on this page belongs to the clone diffs. */
.trends { display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:10px 22px;
          margin:14px 0 6px; }
.trend-head { display:flex; justify-content:space-between; align-items:baseline; gap:10px; }
.trend-head > span:first-child { text-transform:uppercase; letter-spacing:var(--track); font-weight:600;
                                 font-size:0.64rem; color:var(--fg3); }
.trend-head .cite { text-transform:none; letter-spacing:0; font-weight:400; text-decoration:none; }
.trend-head .cite:hover { text-decoration:underline; }
.trend-delta { font-size:0.68rem; color:var(--fg3); font-variant-numeric:tabular-nums; }
.trend-svg { width:100%; height:92px; display:block; overflow:visible; }
.ax-grid { stroke:var(--rule); stroke-width:1; }
.ax-lbl { font-size:9px; fill:var(--fg3); font-family:inherit; letter-spacing:0.04em; }
.pt-lbl { font-size:9px; font-weight:600; fill:var(--fg3); font-family:inherit; }
.pt-lbl.last { font-weight:700; fill:var(--fg); }
.trend-area { fill:var(--fg3); opacity:0.12; }
.trend-line { fill:none; stroke:var(--fg2); stroke-width:1.5; }
.trend-dot { fill:var(--fg2); }
.trend-dot.last { fill:var(--fg); }
.trend-hit { fill:transparent; cursor:pointer; }
.tip { position:absolute; display:none; background:var(--fg); color:var(--bg); padding:7px 10px;
       font-size:0.7rem; pointer-events:none; z-index:50; white-space:nowrap; }
footer { margin-top:44px; padding-top:18px; border-top:1px solid var(--border);
         font-size:0.72rem; color:var(--fg3); }
@media (max-width:640px) { .grid { grid-template-columns:1fr; } .wrap { padding:28px 16px 48px; } }
</style>
</head>
<body>
<div class="wrap">
  <div class="nav" id="nav"></div>
  <div class="phead" id="phead"></div>
  <div class="pmeta" id="meta"></div>
  <p class="lede" id="lede"></p>
  <div id="body"></div>
  <footer id="foot"></footer>
</div>
<div class="tip" id="tip"></div>
<script>
HTMLEOF

{
  echo "const CLEAN = $CLEAN_JSON;"
  echo "const CFG = $CFG_JSON;"
  echo "const HIST = $HIST_JSON;"
  echo "const PAGE = {"
  echo "  date: \"${DATE_STR}\","
  echo "  branch: \"${BRANCH:-}\","
  echo "  argusRef: \"${ARGUS_REF:-}\","
  echo "  argusRepo: \"${ARGUS_REPO:-}\","
  echo "  argusSha: \"${ARGUS_SHA:-}\","
  echo "  argusVersion: \"${ARGUS_VERSION:-}\","
  echo "  selfRepo: \"${SELF_REPO:-}\","
  echo "  selfSha: \"${SELF_SHA:-}\","
  echo "  slug: \"${BRANCH_SLUG:-}\","
  echo "  runUrl: \"${RUN_URL:-}\","
  printf '  branches: %s\n' "${BRANCHES_JSON:-[]}"
  echo "};"
} >> "$OUT_DIR/index.html"

cat >> "$OUT_DIR/index.html" << 'HTMLEOF2'
__NAV_JS__
(function () {
  function $(id) { return document.getElementById(id); }
  renderNav({ el: 'nav', branch: PAGE.branch, slug: PAGE.slug || PAGE.branch,
              page: 'cleanliness', branches: PAGE.branches || [], up: '../' });
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  // A line reference nobody can open is not evidence. Each target links into
  // its own repo at the exact commit it was measured at, so the range still
  // shows the code that produced the number however far the branch moves on.
  function srcBase(target) {
    if (target === 'argus') {
      return (PAGE.argusRepo && PAGE.argusSha && PAGE.argusSha !== 'unknown')
        ? SRV + '/' + PAGE.argusRepo + '/blob/' + PAGE.argusSha + '/' : null;
    }
    return (PAGE.selfRepo && PAGE.selfSha && PAGE.selfSha !== 'unknown')
      ? SRV + '/' + PAGE.selfRepo + '/blob/' + PAGE.selfSha + '/' : null;
  }
  function loc(target, f, a, b) {
    var text = '<span class="mono">' + esc(f) + '</span>:' + esc(a) +
               (b && b !== a ? '\u2013' + esc(b) : '');
    var base = srcBase(target);
    if (!base) return text;
    var frag = '#L' + a + (b && b !== a ? '-L' + b : '');
    return '<a href="' + base + esc(f) + frag + '">' + text + '</a>';
  }

  // The same header the board uses, from site-nav.sh.
  renderHeader({
    el: 'phead', metaEl: 'meta', title: 'Code cleanliness', up: '../',
    branch: PAGE.branch,
    selfRepo: PAGE.selfRepo, selfSha: PAGE.selfSha,
    argusRepo: PAGE.argusRepo, argusRef: PAGE.argusRef,
    argusSha: PAGE.argusSha, argusVersion: PAGE.argusVersion,
    date: PAGE.date, runUrl: PAGE.runUrl
  });
  var SRV = (PAGE.runUrl || 'https://github.com').split('/').slice(0, 3).join('/');

  // No standing lede. "Reported, never gated" said the same thing on every
  // visit and explained none of the numbers under it; what a reader needs at
  // each figure is what THAT figure measures, so the description moved to the
  // figures themselves.
  $('lede').innerHTML = '';

  var html = '';

  // A metric that could not run is a FAULT, not a blank. Rendering it as a
  // neutral dash would make "we did not look" and "there is nothing there"
  // indistinguishable -- the exact equivalence this suite rejects everywhere
  // else, so it is not granted here either.
  // What each number actually measures, said where the number is.
  var WHAT = {
    duplication: 'Share of lines that appear more than once, counting only blocks of at ' +
                 'least 5 lines and 50 tokens. Each group below opens to both copies.',
    cognitive:   'How hard the hardest single unit is to follow: one point for each break ' +
                 'in linear reading, plus the nesting depth it sits at. The arithmetic for ' +
                 'each unit is shown beside it.',
    tuples:      'Matrix rows that describe the same test once the id and display name are ' +
                 'removed \u2014 one test billed twice, which also inflates the denominator ' +
                 'of the pass rate on the results page.'
  };
  function says(k) { return '<div class="whatis">' + WHAT[k] + '</div>'; }

  // ---- trends ---------------------------------------------------------------
  // Which metrics each target plots. Tuples are a property of the suite's
  // matrices; argus has none, so it gets no empty plot for them.
  var TRENDS = {
    suite: [['duplication', 'Duplicated lines', '%'], ['cognitive', 'Worst unit', ''],
            ['tuples', 'Unexplained tuples', '']],
    argus: [['duplication', 'Duplicated lines', '%'], ['cognitive', 'Worst unit', '']]
  };
  // Each plot title carries its metric's citation, from the same `ref` the
  // references list is built from, so the two cannot disagree.
  var CFG_KEY = { duplication: 'duplication', cognitive: 'cognitive', tuples: 'tuple_dupes' };
  var CITED = Object.keys(CFG.metrics || {}).map(function (k) { return CFG.metrics[k].ref; })
    .filter(function (n) { return typeof n === 'number'; });
  function cite(m) {
    var n = ((CFG.metrics || {})[CFG_KEY[m]] || {}).ref;
    return typeof n === 'number' ? ' <a class="cite" href="#ref-' + n + '">[' + n + ']</a>' : '';
  }
  function valOf(p, key, m) { var t = p[key]; return t && typeof t[m] === 'number' ? t[m] : null; }
  function fmt(v, m) { return m === 'duplication' ? v.toFixed(1) : String(v); }

  // The delta is against the previous run that measured this metric, and
  // says how far back that was when it is not the previous run.
  function delta(key, m, unit) {
    var got = [];
    for (var i = HIST.length - 1; i >= 0 && got.length < 2; i--) {
      var v = valOf(HIST[i], key, m);
      if (v !== null) got.push({ v: v, i: i });
    }
    if (valOf(HIST[HIST.length - 1] || {}, key, m) === null || got.length < 2) return '';
    var d = got[0].v - got[1].v, back = got[0].i - got[1].i;
    var s = d === 0 ? 'no change' : (d > 0 ? '+' : '−') + fmt(Math.abs(d), m) + unit;
    return s + (back > 1 ? ' vs ' + back + ' runs ago' : ' vs last run');
  }

  function trendRow(key) {
    return '<div class="trends">' + TRENDS[key].map(function (t) {
      return '<div><div class="trend-head"><span>' + esc(t[1]) + cite(t[0]) + '</span>' +
             '<span class="trend-delta">' + esc(delta(key, t[0], t[2])) + '</span></div>' +
             '<svg class="trend-svg" data-t="' + key + '" data-m="' + t[0] + '"></svg></div>';
    }).join('') + '</div>';
  }

  // The board's steps, less any whose half is not a whole number: the middle
  // gridline is labelled top/2, and 25 put a rounded 12.5 there ("13"). 150
  // and 250 stay, so a worst unit of 102 is not drawn against 200.
  function niceMax(v) {
    if (v <= 5) return 5;
    var mag = Math.pow(10, Math.floor(Math.log10(v)));
    return [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10].map(function (x) { return x * mag; })
      .filter(function (c) { return c >= v && Number.isInteger(c / 2); })[0] || 10 * mag;
  }

  // The board's drawSeries, less what does not apply here (verdict dots), plus
  // unmeasured runs: x is the run's position in the history, so such a run
  // keeps its slot and the line joins its neighbours across it.
  function drawTrend(svg) {
    var key = svg.dataset.t, m = svg.dataset.m, tip = $('tip');
    var vals = HIST.map(function (p) { return valOf(p, key, m); });
    var measured = vals.filter(function (v) { return v !== null; });
    if (HIST.length < 2 || measured.length < 1) {
      svg.innerHTML = '<text x="0" y="30" class="ax-lbl">' +
        (HIST.length < 2 ? 'Not enough runs yet' : 'Never measured') + '</text>';
      return;
    }
    var box = svg.getBoundingClientRect();
    var W = Math.round(box.width || 300), H = Math.round(box.height || 92);
    var padL = 30, padR = 10, padT = 14, padB = 18;
    var plotW = W - padL - padR, plotH = H - padT - padB, n = HIST.length;
    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    svg.setAttribute('preserveAspectRatio', 'none');
    var top = niceMax(Math.max.apply(null, measured.concat([1])));
    function xs(i) { return padL + i * (plotW / (n - 1)); }
    function ys(v) { return padT + plotH - (v / top) * plotH; }
    var g = '';
    [0, top / 2, top].forEach(function (v) {
      g += '<line class="ax-grid" x1="' + padL + '" y1="' + ys(v) + '" x2="' + (W - padR) +
           '" y2="' + ys(v) + '"/><text class="ax-lbl" x="' + (padL - 6) + '" y="' + (ys(v) + 3) +
           '" text-anchor="end">' + (top <= 5 && v % 1 ? v.toFixed(1) : Math.round(v)) + '</text>';
    });
    // Dates as MM-DD; where two labelled runs fall on the same day, the date
    // alone cannot tell them apart, so those show the time instead.
    var xi = [0, Math.floor((n - 1) / 2), n - 1].filter(function (v, i, a) { return a.indexOf(v) === i; });
    function day(i) { return String(HIST[i].date || '').split(' ')[0].slice(5); }
    function clock(i) { return String(HIST[i].date || '').split(' ')[1] || day(i); }
    xi.forEach(function (i) {
      var anchor = i === 0 ? 'start' : (i === n - 1 ? 'end' : 'middle');
      var shared = xi.some(function (j) { return j !== i && day(j) === day(i); });
      g += '<text class="ax-lbl" x="' + xs(i) + '" y="' + (H - 4) + '" text-anchor="' + anchor + '">' +
           esc(shared ? clock(i) : day(i)) + '</text>';
    });
    // One line through the measured points, joined straight across any run
    // that did not measure this metric.
    var pts = [];
    vals.forEach(function (v, i) { if (v !== null) pts.push(i); });
    var line = '', area = 'M' + xs(pts[0]) + ',' + (padT + plotH);
    pts.forEach(function (i, j) {
      line += (j ? ' L' : 'M') + xs(i) + ',' + ys(vals[i]);
      area += ' L' + xs(i) + ',' + ys(vals[i]);
    });
    area += ' L' + xs(pts[pts.length - 1]) + ',' + (padT + plotH) + ' Z';
    g += '<path class="trend-area" d="' + area + '"/><path class="trend-line" d="' + line + '"/>';
    // A dot on every sample, so the reader can see where the measurements are
    // and the line reads as joining them rather than as a continuous signal.
    pts.forEach(function (i) {
      g += '<circle class="trend-dot" cx="' + xs(i) + '" cy="' + ys(vals[i]) + '" r="2.2"/>';
    });
    var last = n - 1;
    if (vals[last] !== null) {
      g += '<circle class="trend-dot last" cx="' + xs(last) + '" cy="' + ys(vals[last]) + '" r="3"/>' +
           '<text class="pt-lbl last" x="' + xs(last) + '" y="' + (ys(vals[last]) - 5 > padT + 6 ?
           ys(vals[last]) - 5 : ys(vals[last]) + 11) + '" text-anchor="end">' + fmt(vals[last], m) + '</text>';
    }
    var bw = plotW / (n - 1);
    pts.forEach(function (i) {
      g += '<rect class="trend-hit" x="' + (xs(i) - bw / 2) + '" y="0" width="' + bw +
           '" height="' + H + '" data-i="' + i + '"/>';
    });
    svg.innerHTML = g;
    svg.querySelectorAll('.trend-hit').forEach(function (r) {
      var p = HIST[+r.dataset.i], v = vals[+r.dataset.i];
      r.addEventListener('mouseenter', function (e) {
        var sha = key === 'argus' ? p.argus_sha : p.self_sha;
        tip.innerHTML = '<b>' + esc(p.date) + '</b><br>' + esc(fmt(v, m)) +
          (sha ? ' &middot; <span class="mono">' + esc(String(sha).slice(0, 7)) + '</span>' : '');
        tip.style.display = 'block';
        tip.style.left = (e.clientX + window.scrollX + 12) + 'px';
        tip.style.top = (e.clientY + window.scrollY - 44) + 'px';
      });
      r.addEventListener('mouseleave', function () { tip.style.display = 'none'; });
      if (p.url) r.addEventListener('click', function () { window.open(p.url, '_blank'); });
    });
  }

  function fault(what, why) {
    return '<div class="fault"><span class="flabel">Not measured</span> ' +
           esc(what) + ' &mdash; ' + esc(why) +
           '. This is a broken metric, not a clean result.</div>';
  }

  ['suite', 'argus'].forEach(function (key) {
    var t = (CLEAN.targets || {})[key], cfg = (CFG.targets || {})[key];
    if (!t || !cfg) return;
    html += '<h2>' + esc(cfg.label) + '</h2>';
    html += trendRow(key);

    // ---- duplication ------------------------------------------------------
    var d = t.duplication;
    if (!d || d.error) {
      html += fault('Duplicated lines', (d && d.error) || 'no result was produced');
    } else {
      html += '<div class="figure"><span class="fnum">' + Number(d.percent).toFixed(1) +
              '%</span><span class="flab">duplicated &middot; ' + esc(d.clones) +
              ' clone groups &middot; ' + esc(d.duplicated_lines) + ' of ' +
              esc(d.total_lines) + ' lines</span></div>';
      html += says('duplication');
      var g = d.groups || [];
      if (g.length) {
        // Each group expands to the duplicated text. jscpd already produces
        // the fragment and it was being discarded, so the page asserted that
        // two ranges match without ever showing WHAT matches -- leaving the
        // reader to open two tabs and diff by eye. Collapsed by default: the
        // list is for scanning, the text is for the one you care about.
        html += g.slice(0, 12).map(function (x) {
          var head = '<span class="cl-n">' + esc(x.lines) + ' lines</span>' +
                     '<span class="cl-t">' + esc(x.tokens) + ' tokens</span>' +
                     '<span class="cl-w">' + loc(key, x.a.file, x.a.start, x.a.end) +
                     ' <span class="cl-eq">=</span> ' +
                     loc(key, x.b.file, x.b.start, x.b.end) + '</span>';
          // Both sides, aligned line for line, matches in green. A clone pair is
          // the same length by construction, so index-wise alignment is right
          // -- and for a Type-2 clone the handful of lines that DIFFER are the
          // whole reason to look, so those are what stand out against the green.
          var body;
          if (x.aText && x.bText) {
            var n = Math.max(x.aText.length, x.bText.length), same = 0, rows = '';
            for (var i = 0; i < n; i++) {
              var la = x.aText[i], lb = x.bText[i];
              var eq = la === lb;
              if (eq) { same++; }
              rows += '<tr class="' + (eq ? 'eq' : 'df') + '">' +
                      '<td class="ln">' + (x.a.start + i) + '</td>' +
                      '<td class="cd">' + esc(la == null ? '' : la) + '</td>' +
                      '<td class="ln">' + (x.b.start + i) + '</td>' +
                      '<td class="cd">' + esc(lb == null ? '' : lb) + '</td></tr>';
            }
            body = '<div class="cl-cols"><div class="cl-hd">' +
                     '<span>' + loc(key, x.a.file, x.a.start, x.a.end) + '</span>' +
                     '<span>' + loc(key, x.b.file, x.b.start, x.b.end) + '</span></div>' +
                   '<div class="cl-scroll"><table class="cl-diff"><tbody>' + rows +
                   '</tbody></table></div><div class="cl-sum">' + same + ' of ' + n +
                   ' lines identical' + (same === n ? '' : ' \u2014 ' + (n - same) + ' differ') +
                   '</div></div>';
          } else if (x.fragment) {
            body = '<pre class="cl-frag">' + esc(x.fragment) + '</pre>';
          } else {
            body = '<div class="more">The detector recorded no text for this group; ' +
                   'follow either range above.</div>';
          }
          return '<details class="clone"><summary>' + head + '</summary>' + body + '</details>';
        }).join('') +
        (g.length > 12 ? '<div class="more">' + (g.length - 12) +
                         ' further group(s) not shown.</div>' : '');
      } else {
        html += '<div class="clean">No clone group reached the 5-line / 50-token floor.</div>';
      }
    }

    // ---- cognitive complexity ---------------------------------------------
    var c = t.cognitive;
    if (!c || c.error) {
      html += fault('Cognitive complexity', (c && c.error) || 'no result was produced');
    } else {
      html += '<div class="figure"><span class="fnum">' + esc(c.worst) +
              '</span><span class="flab">worst unit &middot; ' + esc(c.over_threshold) +
              ' of ' + esc(c.units) + ' over ' + esc(c.threshold) +
              ' &middot; ' + esc(c.language) + '</span></div>';
      html += says('cognitive');
      var top = c.top || [];
      if (top.length) {
        html += '<table><thead><tr><th>Score</th><th>Unit</th>' +
                '<th>What it counted</th></tr></thead><tbody>' +
          top.map(function (u) {
            // The arithmetic, not a label. "102" with an empty explanation is
            // a number nobody can check or act on, which is what the argus
            // column showed before the Python pass recorded a breakdown.
            var why = '', sum = null;
            if (u.why) {
              var parts = [];
              Object.keys(u.why).forEach(function (k) {
                if (k === '= explained') { sum = u.why[k]; return; }
                parts.push(esc(k) + '&nbsp;+' + u.why[k]);
              });
              why = parts.join(' &nbsp;');
              var shown = sum === null ? u.score : sum;
              why += ' &nbsp;<span class="eq">= ' + esc(shown) + '</span>';
              // The Python breakdown explains the reference implementation's
              // score rather than deriving it. Say so when they diverge
              // instead of showing a total that does not reconcile.
              if (sum !== null && sum !== u.score) {
                why += ' <span class="mismatch" title="The breakdown walks the same constructs ' +
                       'Campbell\u2019s rules increment on; the score is the reference ' +
                       'implementation\u2019s. A gap means the two disagree on this unit.">' +
                       '(score ' + esc(u.score) + ')</span>';
              }
            }
            return '<tr' + (u.score > c.threshold ? ' class="over"' : '') + '>' +
                   '<td class="num">' + esc(u.score) + '</td>' +
                   '<td>' + loc(key, u.file, u.line, u.end) + ' <span class="unit">' + esc(u.name) + '</span></td>' +
                   '<td class="why">' + why + '</td></tr>';
          }).join('') + '</tbody></table>';
      }
    }

    // ---- duplicate tuples (suite only) ------------------------------------
    var td = t.tuple_dupes;
    if (td && !td.error) {
      var unexplained = (td.exact_rows || 0) + (td.invocation_rows || 0);
      html += '<div class="figure"><span class="fnum">' + esc(unexplained) +
              '</span><span class="flab">unexplained duplicate tuples &middot; ' +
              esc(td.rows) + ' matrix rows &middot; ' +
              esc((td.exempted || []).length) + ' annotated deliberate</span></div>';
      html += says('tuples');
      var rows = (td.exact || []).concat(td.invocation || []);
      if (rows.length) {
        html += '<table><thead><tr><th>Tests</th><th>Defined at</th></tr></thead><tbody>' +
          rows.map(function (x) {
            return '<tr><td>' + esc(x.tests.join(' = ')) + '</td><td>' +
                   (x.where || []).map(function (w) {
                     var pp = String(w).split(':');
                     return loc('suite', '.github/workflows/' + pp[0], pp[1]);
                   }).join(' &nbsp; ') + '</td></tr>';
          }).join('') + '</tbody></table>';
      }
      if ((td.exempted || []).length) {
        html += '<table><thead><tr><th>Annotated</th><th>Reason given in the workflow</th></tr></thead><tbody>' +
          td.exempted.map(function (x) {
            return '<tr><td>' + esc(x.tests.join(' = ')) + '</td><td class="why">' +
                   esc(x.allowed) + '</td></tr>';
          }).join('') + '</tbody></table>';
      }
    }
  });

  // ---- why these, in a table rather than paragraphs ----------------------
  html += '<h2>Why these metrics</h2><table><thead><tr><th>Metric</th><th></th>' +
          '<th>Grounding</th></tr></thead><tbody>' +
    '<tr><td class="k">Duplicated lines</td><td>DRY</td><td>Inconsistent changes to clones are a ' +
      'measurable defect source <a href="#ref-1">[1]</a>. Type-1 and Type-2 only, so a low number ' +
      'is weaker evidence than a high one.</td></tr>' +
    '<tr><td class="k">Cognitive complexity</td><td>KISS</td><td>Validated against measured ' +
      'comprehension time <a href="#ref-2">[2]</a>. Threshold 15 is SonarSource\u2019s default \u2014 ' +
      'a convention, not a finding.</td></tr>' +
    '<tr><td class="k">Duplicate test tuples</td><td>DRY</td><td>A test is redundant when the rest ' +
      'of the suite already covers what it exercises <a href="#ref-7">[7]</a>; identical matrix rows ' +
      'are the literal case. PR #13 cut six found this way by hand, and each also inflated the ' +
      'denominator of the pass rate.</td></tr>' +
    '</tbody></table>';

  // Every figure above should be reproducible by hand from the evidence beside
  // it. Without the rule, a score is a number from a machine.
  // Each figure as the equation that produces it, then two sentences on what
  // the equation is doing. A formula a reader can apply by hand to the
  // evidence above it is the difference between a measurement and a number
  // from a machine.
  html += '<h2>How these are calculated</h2>' +
    '<div class="calc">' +

      '<h3>Cognitive complexity</h3>' +
      '<div class="eqn">score &nbsp;=&nbsp; ' +
        '<span class="sum">&Sigma;</span><sub>&thinsp;b&thinsp;&isin;&thinsp;breaks</sub>' +
        '&nbsp;( 1 + depth<sub>b</sub> )</div>' +
      '<p>A <em>break</em> is anything that interrupts linear reading: ' +
      '<span class="mono">if</span>, <span class="mono">for</span>, ' +
      '<span class="mono">while</span>, <span class="mono">case</span> and each arm, ' +
      '<span class="mono">except</span>, a ternary, <span class="mono">break</span>/' +
      '<span class="mono">continue</span>, and each boolean sequence &mdash; once per ' +
      'sequence, not per operator. <span class="mono">depth<sub>b</sub></span> is how many ' +
      'constructs already enclose it, which is why the same statements cost more nested than ' +
      'laid out flat.</p>' +
      '<p><span class="mono">else</span> and <span class="mono">elif</span> are the exception: ' +
      'they add 1 with no depth term, because the reader is already inside that construct. ' +
      'Worked: <span class="mono">for&nbsp;+1, if&nbsp;+3, while&nbsp;+2, &amp;&amp;/||&nbsp;+3, ' +
      'else&nbsp;+1, nesting&nbsp;+7 = 17</span> &mdash; the nesting term alone is 41% of that ' +
      'score.</p>' +

      '<h3>Duplicated lines</h3>' +
      '<div class="eqn">duplication &nbsp;=&nbsp; ' +
        '<span class="frac"><span class="num">duplicated lines</span>' +
        '<span class="den">total lines</span></span> &nbsp;&times;&nbsp; 100' +
        '<span class="cond">&nbsp;&nbsp;where a clone &ge; 5 lines <em>and</em> &ge; 50 tokens</span></div>' +
      '<p>Both thresholds must hold, so a repeated three-line stanza is not counted and neither ' +
      'is a long run of trivial tokens. Only Type-1 (identical) and Type-2 (identical but for ' +
      'names and literals) clones are detected.</p>' +
      '<p>That makes a high figure strong evidence and a low one weak: duplication restructured ' +
      'to say the same thing differently is invisible to the measure. The groups above open to ' +
      'both copies so the number can be checked against the code.</p>' +

      '<h3>Duplicate test tuples</h3>' +
      '<div class="eqn">sig(row) &nbsp;=&nbsp; params(row) &nbsp;&minus;&nbsp; { id, name }' +
        '<br>exact &nbsp;=&nbsp; &Sigma;<sub>&thinsp;g</sub> ( |g| &minus; 1 ) ' +
        '&nbsp;&nbsp;over groups sharing a sig' +
        '<span class="cond">&nbsp;&nbsp;invocation: the same, with sig also &minus; { cname }</span></div>' +
      '<p>Every matrix row reduces to its parameters with the id and display name stripped; rows ' +
      'sharing a signature form a group, and a group of <em>n</em> contributes <em>n&minus;1</em> ' +
      'redundant tests. The second form additionally ignores the container name, catching the ' +
      'same argus call run under a different label.</p>' +
      '<p>A same-invocation pair can be legitimate when a follow-on job asserts something extra, ' +
      'so those are annotated in the workflow with <span class="mono">// dry:allow &lt;reason&gt;</span> ' +
      'and counted separately rather than excluded from the measure.</p>' +
    '</div>';

  html += '<h2>References</h2><div class="refs">' +
    // Only what the page cites, and the citation IS the link. Printing the
    // raw URL beside it repeated the destination in a form nobody reads and
    // made every entry twice as long.
    // Cited means a metric names it with `ref` in the config; the excluded
    // metrics' references stay in the config as provenance only.
    (CFG.references || []).filter(function (r) { return CITED.indexOf(r.n) !== -1; })
      .map(function (r) {
        return '<div class="ref" id="ref-' + r.n + '"><span class="n">[' + r.n + ']</span>' +
               '<span><a href="' + esc(r.url) + '">' + esc(r.ieee) + '</a></span></div>';
      }).join('') + '</div>';

  $('body').innerHTML = html;

  // Draw after layout, and again whenever a plot's box changes size -- the
  // board found that measuring once at init read a width before layout had
  // settled and the drawing came out scaled.
  var plots = Array.prototype.slice.call(document.querySelectorAll('.trend-svg'));
  plots.forEach(drawTrend);
  if (typeof ResizeObserver === 'function') {
    var ro = new ResizeObserver(function (es) { es.forEach(function (e) { drawTrend(e.target); }); });
    plots.forEach(function (s) { ro.observe(s); });
  } else {
    window.addEventListener('resize', function () { plots.forEach(drawTrend); });
  }
  $('foot').innerHTML =
    'Measured by <span class="mono">.github/scripts/cleanliness-metrics.sh</span> on every run. ' +
    '<a href="../../">All branches</a> &middot; <a href="../tests/">Test results</a>.';
})();
</script>
</body>
</html>
HTMLEOF2

splice_nav "$OUT_DIR/index.html"

echo "Cleanliness page written: $OUT_DIR/index.html"
