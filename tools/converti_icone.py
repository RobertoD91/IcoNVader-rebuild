#!/usr/bin/env python3
"""Converte i set di icone .icns di IcoNVader in PNG 128x128 per la versione web.

Uso: python3 tools/converti_icone.py
Richiede Pillow. Legge IcoNVader.saver/Contents/Resources/Icon Sets/<Set>/*.icns
e scrive web/iconvader/icons/<Set>/<Nome>.png (variante 'it32' 128x128 con maschera alfa 't8mk').
"""
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'IcoNVader.saver', 'Contents', 'Resources', 'Icon Sets')
DST = os.path.join(ROOT, 'web', 'iconvader', 'icons')

for path in sorted(glob.glob(os.path.join(SRC, '*', '*.icns'))):
    icon_set = os.path.basename(os.path.dirname(path))
    name = os.path.splitext(os.path.basename(path))[0]
    im = Image.open(path)
    im.size = (128, 128)  # seleziona la rappresentazione 128x128
    im.load()
    os.makedirs(os.path.join(DST, icon_set), exist_ok=True)
    im.convert('RGBA').save(os.path.join(DST, icon_set, name + '.png'), optimize=True)
    print(f'{icon_set}/{name}.png')
