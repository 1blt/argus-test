#!/usr/bin/env bash
# =============================================================================
# The code-cleanliness page: _site/<branch>/code-cleanliness/index.html
#
# Split off the main board deliberately. The dashboard answers one question --
# does argus still behave the way a consumer expects -- and a KISS/DRY panel
# sitting under it invites the reading that a duplication figure is part of
# that verdict. It is not, and nothing here gates anything.
#
# The rationale and the citations live ON this page rather than only in
# .github/data/cleanliness-metrics.json, because a number whose justification
# is in a file nobody opens is a number people will argue with from memory.
#
# Self-contained, like the dashboard: the CSS tokens are repeated rather than
# shared, so the two pages deploy independently and neither can break the
# other's rendering. That is a deliberate duplication and it is the kind this
# page's own tuple metric would flag, so: noted here rather than hidden.
#
# Env:
#   CLEAN_FILE      cleanliness.json from cleanliness-metrics.sh
#   CLEAN_CFG_FILE  .github/data/cleanliness-metrics.json  (labels, prose, refs)
#   OUT_DIR         directory to write index.html into
#   ARGUS_REF, ARGUS_REPO, BRANCH, RUN_URL, DATE_STR   (all optional)
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
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
.lede { font-size:0.9rem; color:var(--fg2); max-width:74ch; margin:0 0 10px; }
h2 { font-size:0.82rem; font-weight:700; text-transform:uppercase; letter-spacing:var(--track);
     color:var(--fg); margin:40px 0 6px; padding-top:18px; border-top:1px solid var(--border); }
h3 { font-size:0.74rem; font-weight:700; text-transform:uppercase; letter-spacing:0.06em;
     color:var(--fg); margin:24px 0 10px; }
p { font-size:0.82rem; max-width:74ch; }
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
.refs { margin-top:10px; }
.ref { display:flex; gap:10px; font-size:0.73rem; color:var(--fg3); padding:7px 0; border-bottom:1px solid var(--rule); }
.ref .n { font-weight:700; color:var(--fg2); flex:0 0 auto; }
.ref .why { display:block; color:var(--fg3); font-style:italic; margin-top:2px; }
footer { margin-top:44px; padding-top:18px; border-top:1px solid var(--border);
         font-size:0.72rem; color:var(--fg3); }
@media (max-width:640px) { .grid { grid-template-columns:1fr; } .wrap { padding:28px 16px 48px; } }
</style>
</head>
<body>
<div class="wrap">
  <a class="back" href="../">&larr; Summary</a>
  <h1><img class="eye" src="../favicon.png" alt="" aria-hidden="true">Code cleanliness</h1>
  <div class="meta" id="meta"></div>
  <p class="lede" id="lede"></p>
  <div id="body"></div>
  <footer id="foot"></footer>
</div>
<script>
HTMLEOF

{
  echo "const CLEAN = $CLEAN_JSON;"
  echo "const CFG = $CFG_JSON;"
  echo "const PAGE = {"
  echo "  date: \"${DATE_STR}\","
  echo "  branch: \"${BRANCH:-}\","
  echo "  argusRef: \"${ARGUS_REF:-}\","
  echo "  argusRepo: \"${ARGUS_REPO:-}\","
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

  // ---- header -------------------------------------------------------------
  var m = [];
  if (PAGE.branch) { m.push('branch <span class="mono">' + esc(PAGE.branch) + '</span>'); }
  if (PAGE.argusRef) { m.push('argus@' + esc(PAGE.argusRef)); }
  m.push(esc(PAGE.date));
  if (PAGE.runUrl) { m.push('<a href="' + esc(PAGE.runUrl) + '">view run &#8599;</a>'); }
  $('meta').innerHTML = m.join('<span class="sep">&middot;</span>');

  $('lede').innerHTML =
    'KISS and DRY indicators for this suite and for argus, <strong>reported and never gated</strong>. ' +
    'Nothing on this page can fail a build: the suite’s job is argus’s consumer contract, and a red ' +
    'has to mean argus broke rather than that a function grew. A gated cleanliness number also gets met ' +
    'rather than earned — the figure improves and the code does not.';

  var html = '';

  // ---- per-target measurements -------------------------------------------
  function card(title, value, detail, tag, na) {
    return '<div class="card">' +
           '<div class="t">' + esc(title) + (tag ? '<span class="tag">' + esc(tag) + '</span>' : '') + '</div>' +
           '<div class="v' + (na ? ' na' : '') + '">' + esc(value) + '</div>' +
           '<div class="d">' + detail + '</div></div>';
  }

  html += '<h2>Measurements</h2>' +
    '<p>Two targets, reported separately and <strong>never summed</strong>. A combined score would let tidy ' +
    'tests offset untidy source, and it would let this board assert something about argus’s internals ' +
    'that its maintainers have not agreed to. A metric that could not be computed reads ' +
    '<em>not measured</em>, never 0 — absence of evidence is not evidence of cleanliness.</p>';

  ['suite', 'argus'].forEach(function (key) {
    var t = (CLEAN.targets || {})[key], cfg = (CFG.targets || {})[key];
    if (!t || !cfg) return;
    var cards = '';

    var md = (CFG.metrics || {}).duplication || {};
    if (t.duplication && t.duplication.percent != null) {
      cards += card(md.label || 'Duplicated lines',
        Number(t.duplication.percent).toFixed(1) + '%',
        esc(t.duplication.clones + ' clone group(s); ' + t.duplication.duplicated_lines +
            ' of ' + t.duplication.total_lines + ' lines.'),
        'DRY');
    } else {
      cards += card(md.label || 'Duplicated lines', 'not measured',
        'No clone detector was available in this run.', 'DRY', true);
    }

    var mc = (CFG.metrics || {}).cognitive || {};
    if (t.cognitive && t.cognitive.worst != null) {
      cards += card(mc.label || 'Cognitive complexity', String(t.cognitive.worst),
        esc(t.cognitive.over_threshold + ' of ' + t.cognitive.units + ' unit(s) over ' +
            t.cognitive.threshold + (t.cognitive.worst_at ? '. Worst: ' + t.cognitive.worst_at : '')),
        'KISS');
    } else {
      cards += card(mc.label || 'Cognitive complexity', 'not applicable',
        'No implementation parses Actions YAML or shell. Left blank rather than substituting a metric ' +
        'that measures something else.', 'KISS', true);
    }

    var mt = (CFG.metrics || {}).tuple_dupes || {};
    if (t.tuple_dupes) {
      var td = t.tuple_dupes;
      var unexplained = (td.exact_rows || 0) + (td.invocation_rows || 0);
      cards += card(mt.label || 'Duplicate test tuples', String(unexplained),
        esc(td.rows + ' matrix rows; ' + (td.exact_rows || 0) + ' exact, ' +
            (td.invocation_rows || 0) + ' same-invocation, ' +
            ((td.exempted || []).length) + ' annotated as deliberate.'),
        'DRY');
    }

    html += '<h3>' + esc(cfg.label) + '</h3><div class="grid">' + cards + '</div>' +
            '<div class="note">' + esc(cfg.note || '') + '</div>';
  });

  // ---- duplicate detail ----------------------------------------------------
  var suite = (CLEAN.targets || {}).suite || {};
  var td = suite.tuple_dupes;
  if (td) {
    html += '<h2>Duplicate test tuples, in detail</h2>' +
      '<p>The suite’s tests are parameter tables, so two rows that are identical once the id and display ' +
      'name are removed are one test billed twice — which also inflates the denominator of the dashboard ' +
      'grade. Detection runs in two tiers: <strong>exact</strong> (every parameter matches) and ' +
      '<strong>same invocation</strong> (the same argus call, differing only by container name). The second ' +
      'tier is legitimate when a follow-on job asserts something extra, so a row can be annotated in place ' +
      'with <span class="mono">// dry:allow &lt;reason&gt;</span> rather than the metric being tuned to ignore it.</p>';

    function list(groups, cls) {
      if (!groups || !groups.length) return '';
      return groups.map(function (g) {
        return '<div class="dupe"><span class="ids">' + esc(g.tests.join('  =  ')) + '</span>' +
               '<div class="why">' + esc((g.where || []).join('  ·  ')) +
               (g.allowed ? '<br><strong>allowed:</strong> ' + esc(g.allowed) : '') + '</div></div>';
      }).join('');
    }

    var unexplained = (td.exact || []).concat(td.invocation || []);
    if (unexplained.length) {
      html += '<h3>Unexplained</h3>' + list(unexplained);
    } else {
      html += '<h3>Unexplained</h3><p class="ok">None. Every duplicate pairing found is annotated with a reason.</p>';
    }
    if ((td.exempted || []).length) {
      html += '<h3>Annotated as deliberate</h3>' + list(td.exempted);
    }
  }

  // ---- why these metrics ---------------------------------------------------
  html += '<h2>Why these three</h2>' +
    '<p>Most of the classical cleanliness canon is weaker than its reputation, so the list is short on ' +
    'purpose. Each metric below is here because something measured it against an outcome that matters, ' +
    'rather than against intuition.</p><table><thead><tr>' +
    '<th>Metric</th><th>KISS/DRY</th><th>What it measures, and the caveat</th></tr></thead><tbody>';
  Object.keys(CFG.metrics || {}).forEach(function (k) {
    var m = CFG.metrics[k];
    html += '<tr><td class="k">' + esc(m.label) + '</td><td>' + esc(m.kiss_dry) + '</td><td>' +
            esc(m.what) + '<br><span style="color:var(--fg3)"><em>' + esc(m.caveat) + '</em></span></td></tr>';
  });
  html += '</tbody></table>';

  html += '<h2>What is deliberately excluded</h2>' +
    '<table><thead><tr><th>Metric</th><th>Why not</th></tr></thead><tbody>' +
    '<tr class="excluded"><td class="k">Cyclomatic complexity</td><td>Correlates around 0.9 with raw line ' +
    'count <a href="#ref-4">[4]</a>, so it largely re-measures size rather than adding evidence. The ' +
    'methodological objection <a href="#ref-5">[5]</a> predates the correlation studies that confirmed it. ' +
    'Recorded for provenance <a href="#ref-3">[3]</a>.</td></tr>' +
    '<tr class="excluded"><td class="k">Halstead volume / effort</td><td>No dependable independent ' +
    'predictive value once size is controlled for.</td></tr>' +
    '<tr class="excluded"><td class="k">Maintainability Index</td><td>Its constants were fitted to a small ' +
    'sample and never re-derived; the widely-shipped variant is ad hoc <a href="#ref-6">[6]</a>.</td></tr>' +
    '<tr class="excluded"><td class="k">Chidamber &amp; Kemerer</td><td>Genuinely validated, but ' +
    'object-oriented. This repository is Actions YAML and bash, so CBO, WMC and LCOM have nothing to bind ' +
    'to. Not approximated by a stand-in.</td></tr>' +
    '</tbody></table>';

  // ---- references ----------------------------------------------------------
  html += '<h2>References</h2><div class="refs">' +
    (CFG.references || []).map(function (r) {
      return '<div class="ref" id="ref-' + r.n + '"><span class="n">[' + r.n + ']</span><span>' +
             esc(r.ieee) + ' <a href="' + esc(r.url) + '">' + esc(r.url) + '</a>' +
             (r.note ? '<span class="why">' + esc(r.note) + '</span>' : '') + '</span></div>';
    }).join('') + '</div>';

  $('body').innerHTML = html;
  $('foot').innerHTML =
    'Measured on every suite run by <span class="mono">.github/scripts/cleanliness-metrics.sh</span>; ' +
    'thresholds, prose and citations in <span class="mono">.github/data/cleanliness-metrics.json</span>. ' +
    'Generated ' + esc(PAGE.date) + '. <a href="../">Summary</a> &middot; ' +
    '<a href="../tests/">Test results</a>.';
})();
</script>
</body>
</html>
HTMLEOF2

echo "Cleanliness page written: $OUT_DIR/index.html"
