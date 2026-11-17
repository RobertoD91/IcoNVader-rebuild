#!/usr/bin/env python3
"""Genera le traduzioni per macOS e per il web da i18n/stringhe.json.

Uso: python3 tools/genera_traduzioni.py [--verifica]

Scrive:
  macos/Resources/<lingua>.lproj/Localizable.strings   (UTF-8)
  web/iconvader/js/i18n.js                              (testi + numero di versione)
Il numero di versione viene da CFBundleShortVersionString in macos/project.yml, così la versione
web e il salvaschermo mostrano sempre lo stesso.
Con --verifica non scrive nulla e termina con errore se i file generati non sono aggiornati.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'i18n', 'stringhe.json')
PROJECT = os.path.join(ROOT, 'macos', 'project.yml')
HEADER = 'Generato da tools/genera_traduzioni.py a partire da i18n/stringhe.json: non modificare a mano.'


def strings_escape(s):
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')


def build():
    data = json.load(open(SRC, encoding='utf-8'))
    langs = data['lingue']
    table = data['stringhe']
    for key, values in table.items():
        missing = [l for l in langs if l not in values]
        if missing:
            sys.exit(f'traduzione mancante per {key}: {", ".join(missing)}')

    out = {}
    for lang in langs:
        lines = [f'/* {HEADER} */', '']
        for key, values in table.items():
            lines.append(f'"{strings_escape(key)}" = "{strings_escape(values[lang])}";')
        out[os.path.join(ROOT, 'macos', 'Resources', f'{lang}.lproj', 'Localizable.strings')] = '\n'.join(lines) + '\n'

    m = re.search(r'CFBundleShortVersionString:\s*"([^"]+)"', open(PROJECT, encoding='utf-8').read())
    if not m:
        sys.exit('CFBundleShortVersionString non trovato in macos/project.yml')
    per_lang = {lang: {k: v[lang] for k, v in table.items()} for lang in langs}
    js = (f'/* {HEADER} */\n'
          f'window.IcoNVaderVersion = {json.dumps(m.group(1))};\n'
          f'window.IcoNVaderStrings = {json.dumps(per_lang, ensure_ascii=False, indent=2)};\n')
    out[os.path.join(ROOT, 'web', 'iconvader', 'js', 'i18n.js')] = js
    return out


def main():
    files = build()
    check = '--verifica' in sys.argv
    stale = []
    for path, content in files.items():
        current = open(path, encoding='utf-8').read() if os.path.exists(path) else None
        if current != content:
            stale.append(os.path.relpath(path, ROOT))
            if not check:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
    if check and stale:
        sys.exit('traduzioni non aggiornate (esegui tools/genera_traduzioni.py): ' + ', '.join(stale))
    print('aggiornati: ' + (', '.join(stale) if stale else 'nessuno'))


if __name__ == '__main__':
    main()
