#!/usr/bin/env python3
"""Inline core CSS/JS, every exhibit and the review/blueprint sections into one self-contained page."""
import pathlib, sys
here = pathlib.Path(__file__).parent
src = here / 'src'
shell = (src / 'shell.html').read_text()
outname = sys.argv[1] if len(sys.argv) > 1 else 'index.html'
prefix = sys.argv[2] if len(sys.argv) > 2 else ''
files = [p for p in sorted((src / 'ex').glob('*.js')) if p.name.startswith(prefix)]
exhibits = '\n'.join(p.read_text() for p in files)
def part(name):
    f = src / name
    return f.read_text() if f.exists() else ''
out = (shell.replace('/*{{CSS}}*/', (src / 'core.css').read_text())
            .replace('/*{{CORE}}*/', (src / 'core.js').read_text())
            .replace('/*{{EXHIBITS}}*/', exhibits)
            .replace('<!--{{CRITIQUE}}-->', part('review.html'))
            .replace('<!--{{BLUEPRINT}}-->', part('blueprint.html')))
(here / outname).write_text(out)
print(f'{outname}: {len(out)//1024} KB, {len(files)} exhibits')
