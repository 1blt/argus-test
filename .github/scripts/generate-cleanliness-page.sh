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
.lede { font-size:0.9rem; color:var(--fg2); max-width:74ch; margin:0 0 10px; }
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
  <div class="nav" id="nav"></div>
  <div class="phead" id="phead"></div>
  <div class="pmeta" id="meta"></div>
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

  $('lede').innerHTML =
    'Reported, never gated. Every figure is followed by the lines behind it.';

  var html = '';

  // A metric that could not run is a FAULT, not a blank. Rendering it as a
  // neutral dash would make "we did not look" and "there is nothing there"
  // indistinguishable -- the exact equivalence this suite rejects everywhere
  // else, so it is not granted here either.
  function fault(what, why) {
    return '<div class="fault"><span class="flabel">Not measured</span> ' +
           esc(what) + ' &mdash; ' + esc(why) +
           '. This is a broken metric, not a clean result.</div>';
  }

  ['suite', 'argus'].forEach(function (key) {
    var t = (CLEAN.targets || {})[key], cfg = (CFG.targets || {})[key];
    if (!t || !cfg) return;
    html += '<h2>' + esc(cfg.label) + '</h2>';

    // ---- duplication ------------------------------------------------------
    var d = t.duplication;
    if (!d || d.error) {
      html += fault('Duplicated lines', (d && d.error) || 'no result was produced');
    } else {
      html += '<div class="figure"><span class="fnum">' + Number(d.percent).toFixed(1) +
              '%</span><span class="flab">duplicated &middot; ' + esc(d.clones) +
              ' clone groups &middot; ' + esc(d.duplicated_lines) + ' of ' +
              esc(d.total_lines) + ' lines</span></div>';
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
          var body = x.fragment
            ? '<pre class="cl-frag">' + esc(x.fragment) + '</pre>'
            : '<div class="more">The detector recorded no text for this group; ' +
              'follow either range above.</div>';
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
      var top = c.top || [];
      if (top.length) {
        html += '<table><thead><tr><th>Score</th><th>Unit</th>' +
                '<th>What it counted</th></tr></thead><tbody>' +
          top.map(function (u) {
            var why = u.why
              ? Object.keys(u.why).map(function (k) { return k + ' \u00d7' + u.why[k]; }).join(', ')
              : '';
            return '<tr' + (u.score > c.threshold ? ' class="over"' : '') + '>' +
                   '<td class="num">' + esc(u.score) + '</td>' +
                   '<td>' + loc(key, u.file, u.line) + ' <span class="unit">' + esc(u.name) + '</span></td>' +
                   '<td class="why">' + esc(why) + '</td></tr>';
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
    '<tr><td class="k">Duplicate test tuples</td><td>DRY</td><td>Local. PR #13 cut six tests found ' +
      'this way by hand; a redundant test also inflates the denominator of the pass ' +
      'rate.</td></tr>' +
    '<tr class="excluded"><td class="k">Cyclomatic complexity</td><td></td><td>Correlates ~0.9 with ' +
      'line count <a href="#ref-4">[4]</a><a href="#ref-5">[5]</a>, so it re-measures size. Excluded.</td></tr>' +
    '<tr class="excluded"><td class="k">Halstead, Maintainability Index</td><td></td><td>No ' +
      'dependable independent predictive value <a href="#ref-6">[6]</a>. Excluded.</td></tr>' +
    '<tr class="excluded"><td class="k">Chidamber &amp; Kemerer</td><td></td><td>Validated, but ' +
      'object-oriented; nothing here is. Excluded rather than approximated.</td></tr>' +
    '</tbody></table>';

  html += '<h2>References</h2><div class="refs">' +
    (CFG.references || []).map(function (r) {
      return '<div class="ref" id="ref-' + r.n + '"><span class="n">[' + r.n + ']</span><span>' +
             esc(r.ieee) + ' <a href="' + esc(r.url) + '">' + esc(r.url) + '</a></span></div>';
    }).join('') + '</div>';

  $('body').innerHTML = html;
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
