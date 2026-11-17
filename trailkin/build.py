#!/usr/bin/env python3
"""Inline CSS, scripts and docs into one self-contained page: trailkin/index.html."""
import pathlib, sys
here = pathlib.Path(__file__).parent; src = here / 'src'
out_name = sys.argv[1] if len(sys.argv) > 1 else 'index.html'
js = '\n'.join((src / f).read_text() for f in ['core.js', 'creatures.js', 'encounter.js', 'app.js'] if (src / f).exists())
page = ((src / 'shell.html').read_text()
        .replace('/*{{CSS}}*/', (src / 'app.css').read_text())
        .replace('<!--{{DOCS}}-->', (src / 'docs.html').read_text())
        .replace('/*{{JS}}*/', js.replace('</script', '<\\/script')))
(here / out_name).write_text(page)
print(f'{out_name}: {len(page)//1024} KB')
