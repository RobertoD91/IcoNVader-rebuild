#!/usr/bin/env python3
"""Annota il disassemblato i386 di IcoNVader risolvendo i riferimenti PIC (ebx/ecx + off).

Uso: annotate.py <binario_i386> <dis.txt> <indirect.txt> <ivars.txt> > dis_annotated.txt
"""
import re, struct, sys

binpath, dispath, indpath = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(binpath, 'rb').read()

# Sezioni (vmaddr == fileoff in questo binario)
SECTS = {}
for line in open(sys.argv[4]):
    m = re.match(r'\s*\d+\s+(\S+)\s+([0-9a-f]+)\s+([0-9a-f]+)', line)
    if m:
        SECTS[m.group(1)] = (int(m.group(3), 16), int(m.group(2), 16))


def sect_of(addr):
    for name, (start, size) in SECTS.items():
        if start <= addr < start + size:
            return name
    return None


def u32(a):
    return struct.unpack_from('<I', data, a)[0]


def cstr(a):
    end = data.index(b'\0', a)
    return data[a:end].decode('latin-1')


# simboli indiretti (__nl_symbol_ptr / __pointers)
IND = {}
for line in open(indpath):
    m = re.match(r'0x([0-9a-f]+)\s+\d+\s+(\S+)', line.strip())
    if m:
        IND[int(m.group(1), 16)] = m.group(2)


def resolve(t):
    s = sect_of(t)
    if s is None:
        return None
    if s == '__message_refs':
        return '@sel(%s)' % cstr(u32(t))
    if s == '__cls_refs':
        return '@class(%s)' % cstr(u32(t))
    if s == '__literal8':
        return 'f64=%r' % struct.unpack_from('<d', data, t)[0]
    if s == '__literal4':
        return 'f32=%r' % struct.unpack_from('<f', data, t)[0]
    if s == '__cstring':
        return 'cstr=%r' % cstr(t)
    if s == '__cfstring':
        base = SECTS['__cfstring'][0]
        off = (t - base) // 16 * 16 + base
        return '@"%s"' % cstr(u32(off + 8))
    if s == '__const':
        return '__const+%#x f32=%r f64?=%r' % (t - SECTS['__const'][0], struct.unpack_from('<f', data, t)[0], struct.unpack_from('<d', data, t)[0])
    if s in ('__pointers', '__nl_symbol_ptr'):
        return '&%s' % IND.get(t, '?')
    if s == '__bss':
        return 'bss+%#x' % (t - SECTS['__bss'][0])
    if s == '__data':
        return 'data'
    return s


pic = {}
func = None
rx_thunk = re.compile(r'^([0-9a-f]+)\s.*calll\s+___i686\.get_pc_thunk\.(bx|cx)')
rx_ref = re.compile(r'(-?0x[0-9a-f]+)\(%(ebx|ecx)\)')
rx_imm = re.compile(r'\$0x([0-9a-f]{8})\b')
for line in open(dispath):
    line = line.rstrip('\n')
    line = line.replace('$.objc_class_name_QuartzRenderer', '$0x0').replace('.objc_class_name_QuartzRenderer(', '(')
    if line.endswith(':') and not line[0].isdigit():
        func = line
        pic = {}
        print('\n' + line)
        continue
    m = rx_thunk.match(line)
    notes = []
    if m:
        pic[m.group(2)] = int(m.group(1), 16) + 5
    else:
        for off, reg in rx_ref.findall(line):
            if ('e' + reg[1:]) and reg[1:] in pic:
                r = resolve(pic[reg[1:]] + int(off, 16))
                if r:
                    notes.append(r)
        for imm in rx_imm.findall(line):
            v = int(imm, 16)
            if 0x3a000000 <= v <= 0x4a000000 or 0xba000000 <= v <= 0xca000000:
                f = struct.unpack('<f', struct.pack('<I', v))[0]
                d = struct.unpack('<d', struct.pack('<Q', v << 32))[0]
                notes.append('imm f32=%g hi64=%g' % (f, d))
    print(line + ('    ; ' + ' | '.join(notes) if notes else ''))
