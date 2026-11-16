#!/usr/bin/env bash
# Rigenera il disassemblato annotato di IcoNVader (slice i386) in una cartella di lavoro.
#
# Uso: tools/reversing/disassembla.sh [cartella_output]   (predefinita: build/reversing)
# Richiede: python3, llvm-objdump (LLVM >= 14).
#
# Risultato:
#   iv_i386          slice i386 estratta dal binario universale (ppc + i386)
#   objc.txt         metadati Objective-C 1 (classi, metodi, ivar)
#   ivars.txt        layout degli ivar per classe (offset da self)
#   dis.txt          disassemblato grezzo
#   ann.txt          disassemblato con riferimenti PIC risolti (selettori, classi, costanti, stringhe)
#   cls/<Classe>.s   ann.txt diviso per classe
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/build/reversing}"
BIN="$ROOT/IcoNVader.saver/Contents/MacOS/IcoNVader"
HERE="$ROOT/tools/reversing"
mkdir -p "$OUT/cls"

# 1. Estrae la slice i386 dall'intestazione fat (big-endian)
python3 -I - "$BIN" "$OUT/iv_i386" <<'EOF'
import struct, sys
src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
magic, n = struct.unpack_from('>II', d, 0)
assert magic == 0xCAFEBABE, 'non è un binario universale'
for i in range(n):
    cputype, _, off, size, _ = struct.unpack_from('>iiIII', d, 8 + 20 * i)
    if cputype == 7:  # CPU_TYPE_I386
        open(dst, 'wb').write(d[off:off + size])
        break
else:
    sys.exit('slice i386 non trovata')
EOF

cd "$OUT"
# 2. Metadati, sezioni, simboli indiretti e disassemblato
llvm-objdump --macho --objc-meta-data iv_i386 > objc.txt
llvm-objdump --macho -h iv_i386 > sects.txt
llvm-objdump --macho --indirect-symbols iv_i386 > ind.txt
llvm-objdump --macho -d --full-leading-addr --print-imm-hex iv_i386 > dis.txt

# 3. Annotazione dei riferimenti PIC
python3 -I "$HERE/annota.py" iv_i386 dis.txt ind.txt sects.txt > ann.txt

# 4. Layout degli ivar e suddivisione per classe
python3 -I - <<'EOF'
import re, collections
out, cls, sup, pend = [], None, '', {}
for line in open('objc.txt'):
    t = line.split()
    if not t:
        continue
    if t[0] == 'super_class':
        sup = t[-1]
    elif t[0] == 'name' and len(t) >= 3 and t[1].startswith('0x') and re.match(r'^[A-Z]\w+$', t[-1]):
        if t[-1] != cls:
            cls = t[-1]
            out.append(f'\n{cls} : {sup}')
    elif t[0] == 'instance_size' and int(t[1], 16) != 0x30:
        out.append(f'  instance_size {int(t[1], 16):#x}')
    elif t[0] == 'ivar_name':
        pend['n'] = t[-1]
    elif t[0] == 'ivar_type':
        pend['t'] = ' '.join(t[2:])
    elif t[0] == 'ivar_offset':
        out.append(f"  +{int(t[1], 16):#04x} {pend['n']} : {pend['t']}")
open('ivars.txt', 'w').write('\n'.join(out).strip() + '\n')

buf, cur = collections.defaultdict(list), '_misc'
for l in open('ann.txt'):
    m = re.match(r'^[-+]\[(\w+)', l)
    if m:
        cur = m.group(1)
    elif l.strip().endswith(':') and not l[0].isdigit() and l.strip():
        cur = '_misc'
    buf[cur].append(l)
for k, v in buf.items():
    open(f'cls/{k}.s', 'w').writelines(v)
EOF

echo "Disassemblato annotato in: $OUT"
ls "$OUT/cls"
