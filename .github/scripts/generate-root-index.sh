#!/usr/bin/env bash
# =============================================================================
# The site root: _site/index.html -- one card per published branch.
#
# It used to be a hand-rolled heredoc inside test-suite.yml that listed branch
# names against two hardcoded sentences ("Results for the default branch") and
# carried no figures at all, so the top of the site said less than any page
# below it. Worse, with one branch present it collapsed to a meta-refresh, so
# the overview did not exist at all on a fork that only publishes main.
#
# Every figure here is READ from <branch>/history.json, written by
# generate-dashboard.sh after the catalog exists. Nothing is recomputed: the
# root, the branch hub and the board must not each derive their own headline
# from the same run and then disagree in public.
#
# NO LETTER GRADE, for the reason the dashboard removed its own: one letter is
# severity-blind, so a silent pass and a failed artifact upload cost it the
# same, and 95% reads as "good" over a state that includes a scan reporting
# success without scanning. Risk index carries the colour; pass rate does not.
#
# Env:
#   SITE_DIR   the _site directory (index.html is written into it)
#   BRANCHES   space-separated branch dirs to consider (default "main dev")
#   FALLBACK   branch to name if none are present yet
# =============================================================================
set -euo pipefail

SITE_DIR="${SITE_DIR:?SITE_DIR not set}"
BRANCHES="${BRANCHES:-main dev}"
FALLBACK="${FALLBACK:-main}"

touch "$SITE_DIR/.nojekyll"

# ---- collect what is actually published ------------------------------------
CARDS='[]'
for b in $BRANCHES; do
  [ -f "$SITE_DIR/$b/index.html" ] || continue
  H="$SITE_DIR/$b/history.json"
  LATEST='null'
  PREV='null'
  if [ -f "$H" ] && jq empty "$H" 2>/dev/null; then
    LATEST=$(jq -c '.[-1] // null' "$H")
    PREV=$(jq -c 'if length > 1 then .[-2] else null end' "$H")
  fi
  HAS_CLEAN=false
  [ -f "$SITE_DIR/$b/code-cleanliness/index.html" ] && HAS_CLEAN=true
  HAS_TESTS=false
  [ -f "$SITE_DIR/$b/tests/index.html" ] && HAS_TESTS=true

  CARDS=$(jq -c \
    --arg b "$b" \
    --argjson latest "$LATEST" \
    --argjson prev "$PREV" \
    --argjson clean "$HAS_CLEAN" \
    --argjson tests "$HAS_TESTS" \
    '. + [{branch:$b, latest:$latest, prev:$prev, hasClean:$clean, hasTests:$tests}]' \
    <<<"$CARDS")
done

COUNT=$(jq 'length' <<<"$CARDS")
echo "Branches published: $(jq -r '[.[].branch] | join(", ")' <<<"$CARDS") (count=$COUNT)"

if [ "$COUNT" -eq 0 ]; then
  # Nothing to summarise yet. Forward rather than serve an empty overview.
  printf '%s\n' \
    '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">' \
    "<meta http-equiv=\"refresh\" content=\"0; url=${FALLBACK}/\">" \
    "<link rel=\"canonical\" href=\"${FALLBACK}/\"><title>Argus Test Suite</title>" \
    "</head><body><p>Redirecting to <a href=\"${FALLBACK}/\">${FALLBACK}</a>.</p></body></html>" \
    > "$SITE_DIR/index.html"
  echo "No branch published yet; root forwards to /$FALLBACK/"
  exit 0
fi

ICON_BRANCH=$(jq -r '.[0].branch' <<<"$CARDS")

cat > "$SITE_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Argus Test Suite</title>
<link rel="icon" type="image/png" href="${ICON_BRANCH}/favicon.png">
HTMLEOF

cat >> "$SITE_DIR/index.html" << 'HTMLEOF2'
<style>
@import url('https://fonts.googleapis.com/css2?family=Nunito+Sans:ital,wght@0,300;0,400;0,600;0,700&display=swap');
:root {
  --bg:#ffffff; --surface:#ffffff; --fg:#1a1a1a; --fg2:#55595c; --fg3:#919aa1;
  --border:#dee2e6; --rule:#ebedef;
  --pass-ink:#2f8f52; --fail-ink:#b8413d; --warn-ink:#a3701f;
  --pass-bg:#edf9f1; --fail-bg:#fdefee; --warn-bg:#fef7ec;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg:#101214; --surface:#15181b; --fg:#ece9e4; --fg2:#a7adb3; --fg3:#737b82;
    --border:#282d32; --rule:#1e2226;
    --pass-ink:#79d199; --fail-ink:#e88b87; --warn-ink:#e0b271;
    --pass-bg:#16241b; --fail-bg:#2a1719; --warn-bg:#2a2116;
  }
}
* { box-sizing:border-box; }
body { font-family:"Nunito Sans",-apple-system,BlinkMacSystemFont,sans-serif;
       background:var(--bg); color:var(--fg2); margin:0; line-height:1.55;
       -webkit-font-smoothing:antialiased; }
.wrap { max-width:860px; margin:0 auto; padding:52px 16px 64px; }
a { color:inherit; }
.mono { font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:0.92em; }
h1 { font-size:1.1rem; font-weight:700; text-transform:uppercase; letter-spacing:0.11em;
     color:var(--fg); margin:0 0 6px; }
.lede { font-size:0.82rem; color:var(--fg3); margin:0 0 28px; max-width:70ch; }
.branch { border:1px solid var(--border); background:var(--surface); margin-bottom:12px; }
.bhead { display:flex; align-items:baseline; gap:14px; flex-wrap:wrap;
         padding:16px 20px 12px; text-decoration:none; color:inherit; }
.bhead:hover .bname { text-decoration:underline; text-underline-offset:3px; }
.bname { font-size:0.82rem; font-weight:700; text-transform:uppercase;
         letter-spacing:0.08em; color:var(--fg); }
.bwhen { font-size:0.7rem; color:var(--fg3); margin-left:auto; }
.bstats { display:flex; gap:26px; flex-wrap:wrap; padding:0 20px 14px; }
.bs .n { font-size:1.45rem; font-weight:300; line-height:1.1; color:var(--fg); }
.bs .n.bad { color:var(--fail-ink); } .bs .n.warn { color:var(--warn-ink); }
.bs .n.good { color:var(--pass-ink); }
.bs .l { font-size:0.6rem; text-transform:uppercase; letter-spacing:0.07em; color:var(--fg3); }
.bline { font-size:0.75rem; color:var(--fg3); padding:0 20px 14px; }
.blinks { display:flex; gap:0; border-top:1px solid var(--rule); }
.blinks a { flex:1; text-align:center; padding:10px 12px; font-size:0.68rem; font-weight:700;
            text-transform:uppercase; letter-spacing:0.07em; color:var(--fg3);
            text-decoration:none; border-right:1px solid var(--rule); }
.blinks a:last-child { border-right:none; }
.blinks a:hover { color:var(--fg); background:var(--bg); }
.none { font-size:0.75rem; color:var(--fg3); padding:0 20px 16px; font-style:italic; }
footer { margin-top:34px; padding-top:16px; border-top:1px solid var(--border);
         font-size:0.72rem; color:var(--fg3); }
@media (max-width:640px) { .wrap { padding:32px 16px 48px; } .bstats { gap:18px; } }
</style>
</head>
<body>
<div class="wrap">
  <h1>Argus Test Suite</h1>
  <p class="lede">Consumer-contract tests for
    <a href="https://github.com/huntridge-labs/argus">huntridge-labs/argus</a>,
    published per branch. Each branch keeps its own run history, so results from
    work in progress never overwrite the default branch's.</p>
  <div id="branches"></div>
  <footer id="foot"></footer>
</div>
<script>
HTMLEOF2

{
  echo "const BRANCHES = $CARDS;"
  echo "const GENERATED = \"$(date -u '+%Y-%m-%d %H:%M UTC')\";"
} >> "$SITE_DIR/index.html"

cat >> "$SITE_DIR/index.html" << 'HTMLEOF3'
(function () {
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  // Same sentences the board uses for the worst failing class, so the three
  // levels of the site describe a run the same way.
  var LINE = {
    open:      'reports success without scanning',
    degraded:  'a scan ran with fewer sub-scanners than were asked for',
    closed:    'argus refuses to run where it should work',
    auxiliary: 'an auxiliary path is broken; scans and gates still work',
    none:      'every defined test that ran, passed'
  };
  var TONE = { open: 'bad', degraded: 'bad', closed: 'bad', auxiliary: 'warn', none: 'good' };

  var html = BRANCHES.map(function (b) {
    var h = b.latest;
    var body;
    if (!h) {
      body = '<div class="none">Published, but no run history yet &mdash; figures appear ' +
             'after the next complete run.</div>';
    } else {
      var worst = h.worst || (h.verdict === 'PASS' ? 'none' : 'closed');
      var move = '';
      if (b.prev && typeof b.prev.risk === 'number') {
        var d = h.risk - b.prev.risk;
        move = d === 0 ? ' &middot; no change vs previous run'
             : ' &middot; ' + (d > 0 ? '▲ +' + d : '▼ ' + d) + ' vs previous run';
      }
      var defined = h.defined != null ? h.defined : h.total;
      var pct = h.pct_defined != null ? h.pct_defined : h.rate;
      body =
        '<div class="bstats">' +
          '<div class="bs"><div class="n ' + (h.risk ? (TONE[worst] || 'bad') : 'good') + '">' +
            esc(h.risk) + '</div><div class="l">Risk index</div></div>' +
          '<div class="bs"><div class="n">' + esc(pct) + '%</div>' +
            '<div class="l">Passing</div></div>' +
          '<div class="bs"><div class="n">' + esc(h.passed) + '<span style="font-size:.7rem;color:var(--fg3)">/' +
            esc(defined) + '</span></div><div class="l">of defined</div></div>' +
        '</div>' +
        '<div class="bline">' + esc(LINE[worst] || '') + move +
          ' &middot; scope <span class="mono">' + esc(h.scope || 'all') + '</span></div>';
    }

    var links = '<a href="' + esc(b.branch) + '/">Summary</a>';
    if (b.hasTests) links += '<a href="' + esc(b.branch) + '/tests/">Test results</a>';
    if (b.hasClean) links += '<a href="' + esc(b.branch) + '/code-cleanliness/">Code cleanliness</a>';
    if (h && h.url) links += '<a href="' + esc(h.url) + '">Run &#8599;</a>';

    return '<div class="branch">' +
             '<a class="bhead" href="' + esc(b.branch) + '/">' +
               '<span class="bname">' + esc(b.branch) + '</span>' +
               (h ? '<span class="bwhen">' + esc(h.date) + '</span>' : '') +
             '</a>' + body +
             '<div class="blinks">' + links + '</div>' +
           '</div>';
  }).join('');

  document.getElementById('branches').innerHTML = html;
  document.getElementById('foot').innerHTML =
    'Figures are read from each branch’s <span class="mono">history.json</span> rather than ' +
    'recomputed here, so this page cannot disagree with the board it links to. There is no letter ' +
    'grade: one letter is severity-blind, and a silent pass would cost it exactly as much as a ' +
    'failed report upload. Generated ' + esc(GENERATED) + '.';
})();
</script>
</body>
</html>
HTMLEOF3

echo "Root index written: $SITE_DIR/index.html ($COUNT branch card(s))"
