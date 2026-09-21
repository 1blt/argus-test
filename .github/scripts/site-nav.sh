#!/usr/bin/env bash
# =============================================================================
# Shared navigation for the generated pages.
#
# ONE DEFINITION, THREE PAGES. The hub, the board and the cleanliness page are
# self-contained HTML files with their own CSS, so a nav bar written into each
# would be three copies drifting apart -- and this repo now measures its own
# duplication and would report it. Each generator cats these two functions into
# its output instead.
#
# WHAT IT HAS TO SOLVE. The site is three levels deep across an open-ended
# number of branches: / -> /<slug>/ -> /<slug>/{tests,code-cleanliness}/. From
# any page a reader needs to go up, move sideways to the sibling page, and jump
# to the same view on another branch -- that last one being the whole point of
# publishing per branch, and the one that was missing entirely.
#
# emit_nav_css   stylesheet rules, inside the page's <style>
# emit_nav_js    renderNav(cfg) into the page's <script>
# =============================================================================

emit_nav_css() {
cat <<'CSSEOF'
/* --- shared site navigation ------------------------------------------- */
.nav { display:flex; align-items:center; gap:10px; flex-wrap:wrap;
       padding-bottom:12px; margin-bottom:22px; border-bottom:1px solid var(--border); }
.crumbs { display:flex; align-items:center; gap:7px; font-size:0.72rem;
          text-transform:uppercase; letter-spacing:0.07em; font-weight:700; }
.crumbs a { color:var(--fg3); text-decoration:none; }
.crumbs a:hover { color:var(--fg); text-decoration:underline; text-underline-offset:3px; }
.crumbs .here { color:var(--fg); }
.crumbs .car { color:var(--border); font-weight:400; }
.tabs { display:flex; margin-left:auto; border:1px solid var(--border); }
.tabs a { padding:5px 11px; font-size:0.68rem; font-weight:700; text-transform:uppercase;
          letter-spacing:0.06em; color:var(--fg3); text-decoration:none;
          border-right:1px solid var(--border); }
.tabs a:last-child { border-right:none; }
.tabs a:hover { color:var(--fg); }
.tabs a.on { background:var(--fg); color:var(--bg); }
.switch { font-size:0.7rem; color:var(--fg3); width:100%; }
.switch b { font-weight:700; text-transform:uppercase; letter-spacing:0.06em;
            font-size:0.62rem; margin-right:7px; }
.switch a { color:var(--fg3); text-decoration:none; border-bottom:1px solid var(--border);
            margin-right:10px; }
.switch a:hover { color:var(--fg); border-color:var(--fg); }
@media (max-width:640px) { .tabs { margin-left:0; } }
CSSEOF
}

emit_nav_js() {
cat <<'JSEOF'
// renderNav({el, branch, slug, page, branches, up})
//   page  : 'summary' | 'tests' | 'cleanliness'
//   up    : relative prefix to the BRANCH root ('' or '../')
//   branches: [{slug, name}] -- every branch with a published page
//
// The branch switcher keeps the reader on the SAME page they are looking at.
// Jumping to another branch's summary when you were reading its board is a
// different question from the one they asked.
function renderNav(cfg) {
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  var up = cfg.up || '';
  var root = up + '../';              // the site root, above the branch
  var PAGES = {
    summary:     { label: 'Summary',         href: up },
    tests:       { label: 'Test results',    href: up + 'tests/' },
    cleanliness: { label: 'Code cleanliness', href: up + 'code-cleanliness/' }
  };

  var crumbs = '<a href="' + root + '">All branches</a>' +
               '<span class="car">/</span>' +
               (cfg.page === 'summary'
                 ? '<span class="here">' + esc(cfg.branch) + '</span>'
                 : '<a href="' + up + '">' + esc(cfg.branch) + '</a>' +
                   '<span class="car">/</span>' +
                   '<span class="here">' + esc(PAGES[cfg.page].label) + '</span>');

  var tabs = Object.keys(PAGES).map(function (k) {
    return '<a href="' + PAGES[k].href + '"' + (k === cfg.page ? ' class="on"' : '') +
           '>' + esc(PAGES[k].label) + '</a>';
  }).join('');

  // Only worth showing when there is somewhere else to go.
  var others = (cfg.branches || []).filter(function (b) { return b.slug !== cfg.slug; });
  var sw = '';
  if (others.length) {
    var suffix = cfg.page === 'summary' ? '' :
                 (cfg.page === 'tests' ? 'tests/' : 'code-cleanliness/');
    sw = '<div class="switch"><b>Same view on</b>' + others.map(function (b) {
      return '<a href="' + root + esc(b.slug) + '/' + suffix + '">' + esc(b.name || b.slug) + '</a>';
    }).join('') + '</div>';
  }

  document.getElementById(cfg.el).innerHTML =
    '<div class="crumbs">' + crumbs + '</div><div class="tabs">' + tabs + '</div>' + sw;
}
JSEOF
}

# splice_nav <html-file>
# Replaces the __NAV_CSS__ / __NAV_JS__ placeholder lines with the real
# content. Done as a post-pass so the page heredocs stay quoted and literal --
# the same reason __UP__ is resolved after the fact rather than interpolated.
splice_nav() {
  local f="$1"
  local css js
  css=$(mktemp); js=$(mktemp)
  emit_nav_css > "$css"
  emit_nav_js  > "$js"
  python3 - "$f" "$css" "$js" <<'PY'
import sys, pathlib
page, css, js = (pathlib.Path(p) for p in sys.argv[1:4])
t = page.read_text()
t = t.replace("__NAV_CSS__", css.read_text().rstrip("\n"))
t = t.replace("__NAV_JS__",  js.read_text().rstrip("\n"))
page.write_text(t)
PY
  rm -f "$css" "$js"
}
