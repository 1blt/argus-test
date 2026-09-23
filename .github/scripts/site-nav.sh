#!/usr/bin/env bash
# =============================================================================
# Shared navigation for the generated pages.
#
# ONE DEFINITION. The generated pages are self-contained HTML files with their
# own CSS, so a nav bar written into each would be copies drifting apart. Each
# generator cats these functions into its output instead.
#
# WHAT IT HAS TO SOLVE. The site is three levels deep across an open-ended
# number of branches: / -> /<slug>/ -> /<slug>/tests/. From the board a reader
# needs to go up, and jump to the same view on another branch -- the whole
# point of publishing per branch.
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
.switch { font-size:0.7rem; color:var(--fg3); width:100%; }
.switch b { font-weight:700; text-transform:uppercase; letter-spacing:0.06em;
            font-size:0.62rem; margin-right:7px; }
.switch a { color:var(--fg3); text-decoration:none; border-bottom:1px solid var(--border);
            margin-right:10px; }
.switch a:hover { color:var(--fg); border-color:var(--fg); }
CSSEOF
}

emit_nav_js() {
cat <<'JSEOF'
// renderNav({el, branch, slug, page, branches, up})
//   page  : 'tests' -- the one page per branch
//   up    : relative prefix to the BRANCH root (always '../' today)
//   branches: [{slug, name}] -- every branch with a published page
//
// The branch root is a redirect to the board, so the branch is a LABEL here
// rather than a destination. There is one page per branch, so no tabs.
function renderNav(cfg) {
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  var up = cfg.up || '';
  var root = up + '../';
  var PAGES = { tests: { label: 'Test results', href: up + 'tests/' } };

  var crumbs = '<a href="' + root + '">All branches</a>' +
               '<span class="car">/</span>' +
               '<span class="here">' + esc(cfg.branch) + '</span>' +
               '<span class="car">/</span>' +
               '<span class="here">' + esc((PAGES[cfg.page] || {}).label || '') + '</span>';

  var others = (cfg.branches || []).filter(function (b) { return b.slug !== cfg.slug; });
  var sw = '';
  if (others.length) {
    var suffix = 'tests/';
    sw = '<div class="switch"><b>Same view on</b>' + others.map(function (b) {
      return '<a href="' + root + esc(b.slug) + '/' + suffix + '">' + esc(b.name || b.slug) + '</a>';
    }).join('') + '</div>';
  }

  document.getElementById(cfg.el).innerHTML =
    '<div class="crumbs">' + crumbs + '</div>' + sw;
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
  { emit_nav_css; emit_header_css; } > "$css"
  { emit_nav_js;  emit_header_js;  } > "$js"
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

# =============================================================================
# Shared page HEADER.
#
# The board's header: branch, the suite commit, the argus ref with its version
# and commit, the liveness note, the date -- "what produced this page".
# =============================================================================

emit_header_css() {
cat <<'CSSEOF'
/* --- shared page header ------------------------------------------------ */
.phead { display:flex; align-items:center; gap:14px; flex-wrap:wrap; margin-bottom:8px; }
.phead h1 { margin:0; font-size:1.05rem; font-weight:700; color:var(--fg);
            text-transform:uppercase; letter-spacing:0.12em; display:flex; align-items:center; }
.pmeta { font-size:0.76rem; color:var(--fg3); display:flex; gap:10px; flex-wrap:wrap;
         align-items:center; margin-bottom:26px; }
.pmeta a { color:inherit; }
.pmeta .sep { color:var(--border); }
.chip { display:inline-block; padding:1px 7px; border:1px solid var(--border); font-size:0.66rem;
        font-weight:700; letter-spacing:0.04em; text-transform:uppercase; white-space:nowrap; cursor:help; }
.chip-warn { color:var(--warn-ink); background:var(--warn-bg); border-color:var(--warn); }
.chip-ok { color:var(--pass-ink); background:var(--pass-bg); border-color:var(--pass); }
CSSEOF
}

emit_header_js() {
cat <<'JSEOF'
// renderHeader({el, metaEl, title, up, branch, selfRepo, selfSha,
//               argusRepo, argusRef, argusSha, argusVersion, liveness,
//               date, runUrl, scope})
//
// One metadata line for every page. The label is what a human recognises and
// the href is the most specific immutable object; short SHAs are visible text,
// never tooltips, because a tooltip survives neither a screenshot nor a
// copy-paste.
function renderHeader(cfg) {
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  var up = cfg.up || '';
  var SRV = (cfg.runUrl || 'https://github.com').split('/').slice(0, 3).join('/');

  if (cfg.el) {
    document.getElementById(cfg.el).innerHTML =
      '<h1><img class="eye" src="' + up + 'favicon.png" alt="" aria-hidden="true">' +
      esc(cfg.title) + '</h1>';
  }

  function sha(repo, full) {
    if (!full || full === 'unknown') return '';
    return ' <a class="mono" href="' + SRV + '/' + repo + '/commit/' + esc(full) +
           '" title="exact commit -- this link cannot move">' +
           esc(String(full).slice(0, 7)) + '</a>';
  }

  var m = [];
  if (cfg.branch)   { m.push('branch <span class="mono">' + esc(cfg.branch) + '</span>'); }
  if (cfg.selfRepo) { m.push('suite' + (sha(cfg.selfRepo, cfg.selfSha) || ' <span class="mono">(sha unknown)</span>')); }
  if (cfg.argusRepo) {
    var onMain = (cfg.argusRef || 'main') === 'main';
    m.push((onMain && cfg.argusVersion
        ? '<a href="' + SRV + '/' + cfg.argusRepo + '/releases/tag/' + esc(cfg.argusVersion) +
          '">argus <span class="mono">v' + esc(cfg.argusVersion) + '</span></a>'
        : 'argus <span class="mono">' + esc(cfg.argusRef || 'main') + '</span>') +
      (sha(cfg.argusRepo, cfg.argusSha) || ''));
  }
  // Only when the Python that ran differs from the version already named.
  var L = cfg.liveness && cfg.liveness.summary;
  if (L) {
    var pins = (L.sdk_pins || []).join(', ');
    var shown = (cfg.argusRef || 'main') === 'main' ? (cfg.argusVersion || '') : '';
    if (L.sdk_live === false && pins && pins !== shown) {
      var tip = 'This run used the workflow files from ' + (L.ref || 'this ref') +
        ', but the argus Python package came from release ' + pins +
        ' — setup-argus is pinned inside those workflow files. Python behaviour is ' +
        'covered instead by the Runtime Environment tests (N1–N5), which check argus ' +
        'out at the ref and run the CLI directly.';
      var ver = (pins.indexOf(',') === -1)
        ? '<a class="mono" href="' + SRV + '/' + cfg.argusRepo + '/releases/tag/' + esc(pins) +
          '">v' + esc(pins) + '</a>'
        : '<span class="mono">' + esc(pins) + '</span>';
      m.push('<span class="chip chip-warn" title="' + esc(tip) +
             '">Python from ' + ver + ', not this ref</span>');
    } else if (L.sdk_live === true) {
      m.push('<span class="chip chip-ok" title="Workflow files and the Python package both come from this ref.">fully branch-live</span>');
    }
  }
  if (cfg.date)  { m.push(esc(cfg.date)); }
  if (cfg.scope) { m.push('scope <span class="mono">' + esc(cfg.scope) + '</span>'); }
  if (cfg.runUrl) { m.push('<a href="' + esc(cfg.runUrl) + '">view run &#8599;</a>'); }

  document.getElementById(cfg.metaEl).innerHTML = m.join('<span class="sep">&middot;</span>');
}
JSEOF
}
