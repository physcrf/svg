#!/usr/bin/env python3
"""Generate the LaTeX math tables used by SVG's native latex* command.

Sources (all shipped with a TeX Live installation):
  * fontmath.ltx          -- LaTeX's math symbol/accent/delimiter assignments
  * unicode-math-table.tex -- Unicode codepoint for each LaTeX symbol name
  * cmr10/7/5, cmmi10/7/5, cmsy10/7/5, cmex10 TFMs -- real Computer Modern metrics

Output: src/latex-tables.lisp  (in-package #:svg)

Only the glyphs that the sibling `typesetting` engine does not already carry are
emitted as metric data; the symbol/class tables always cover the full set.
"""
import re, subprocess, sys, os

FM   = "/usr/share/texlive/texmf-dist/tex/latex/base/fontmath.ltx"
UNI  = "/usr/share/texlive/texmf-dist/tex/latex/unicode-math/unicode-math-table.tex"
MOCK = "/home/crf/.quicklisp/local-projects/svg/src/tex/mock-font.lisp"
OUT  = "/home/crf/.quicklisp/local-projects/svg/src/latex-tables.lisp"

FAM = {"operators": 0, "letters": 1, "symbols": 2, "largesymbols": 3}
CLASS = {"mathord": ":ord", "mathop": ":op", "mathbin": ":bin", "mathrel": ":rel",
         "mathopen": ":open", "mathclose": ":close", "mathpunct": ":punct",
         "mathinner": ":inner", "mathalpha": ":ord"}

def parse_hex(s):
    s = s.strip()
    if s.startswith('"'): return int(s[1:], 16)
    if s.startswith("`"): return ord(s[1])
    if s.startswith("'"): return int(s[1:], 8)
    return int(s, 0)

fm = open(FM, encoding="utf-8", errors="replace").read()

symbols = {}          # name -> (class, family, code)
for m in re.finditer(r'\\DeclareMathSymbol\s*\{([^}]*)\}\s*\{\\(\w+)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}', fm):
    name, cls, font, code = m.groups()
    if font in FAM and cls in CLASS:
        symbols[name.lstrip("\\")] = (CLASS[cls], FAM[font], parse_hex(code))

accents = {}          # name -> (family, code)
for m in re.finditer(r'\\DeclareMathAccent\s*\{([^}]*)\}\s*\{\\(\w+)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}', fm):
    name, cls, font, code = m.groups()
    if font in FAM:
        accents[name.lstrip("\\")] = (FAM[font], parse_hex(code))

delims = {}           # name -> (class, (sf . sc), (lf . lc))
for m in re.finditer(r'\\DeclareMathDelimiter\s*\{?\\?([A-Za-z@]+)\}?\s*\{\\(\w+)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}', fm):
    name, cls, f1, c1, f2, c2 = m.groups()
    if f1 in FAM and f2 in FAM:
        delims[name] = (CLASS.get(cls, ":ord"), (FAM[f1], parse_hex(c1)), (FAM[f2], parse_hex(c2)))
for name, cls, f1, c1, f2, c2 in re.findall(
        r'\\DeclareMathDelimiter\s*\{([(){}\[\]<>/|])\}\s*\{\\(\w+)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}', fm):
    if f1 in FAM and f2 in FAM:
        delims[name] = (CLASS.get(cls, ":ord"), (FAM[f1], parse_hex(c1)), (FAM[f2], parse_hex(c2)))
# \expandafter\DeclareMathDelimiter\@backslashchar {..}{symbols}{"6E}{largesymbols}{"0F}
m = re.search(r'DeclareMathDelimiter\s*\\@backslashchar\s*\{\\(\w+)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}', fm)
if m:
    cls, f1, c1, f2, c2 = m.groups()
    delims["backslash"] = (CLASS.get(cls, ":ord"), (FAM[f1], parse_hex(c1)), (FAM[f2], parse_hex(c2)))

# single-character math codes (letters/digits are handled by rule in the parser)
char_syms = {}
for m in re.finditer(r'\\DeclareMathSymbol\s*\{([^{}\\])\}\s*\{\\(\w+)\}\s*\{(\w+)\}\s*\{("[0-9A-Fa-f]+|`.)\}', fm):
    ch, cls, font, code = m.groups()
    if font in FAM and cls in CLASS:
        char_syms[ord(ch)] = (CLASS[cls], FAM[font], parse_hex(code))
# characters that LaTeX declares only as delimiters still have a bare mathcode
# (e.g. `(' is \mathcode"4028 = open family 0 char 40). Add them unless a
# \DeclareMathSymbol already gave a better mapping (< and > are relations,
# not the angle-bracket delimiters).
for name, (cls, small, large) in delims.items():
    if len(name) == 1 and ord(name) not in char_syms:
        char_syms[ord(name)] = (cls, small[0], small[1])
# commands that LaTeX declares only as delimiters also work as ordinary
# symbols at their small size (\langle, \uparrow, \lfloor, \backslash, ...),
# so give them a symbol entry unless one already exists.
for name, (cls, small, large) in delims.items():
    if len(name) > 1 and name not in symbols:
        symbols[name] = (cls, small[0], small[1])

# ---- unicode names -------------------------------------------------------
unitext = open(UNI, encoding="utf-8", errors="replace").read()
unicp = {}
for m in re.finditer(r'\\UnicodeMathSymbol\{"([0-9A-Fa-f]+)\}\s*\{\\\s*([A-Za-z@]+)\s*\}', unitext):
    unicp[m.group(2)] = int(m.group(1), 16)

ALIAS = {"to": "rightarrow", "gets": "leftarrow", "le": "leq", "ge": "geq",
         "land": "wedge", "lor": "vee", "lnot": "neg", "owns": "ni",
         "ne": "neq", "neq": "neq", "vert": "mid", "Vert": "parallel",
         "backslash": "setminus", "parallel": "parallel", "bigtriangleup": "triangle",
         "smallint": "smallint", "lgroup": "lgroup", "rgroup": "rgroup",
         "vert(small)": "mid", "Vert(small)": "parallel",
         "lfloor": "lfloor", "rfloor": "rfloor", "lceil": "lceil", "rceil": "rceil",
         "lbrace": "lbrace", "rbrace": "rbrace", "langle": "langle", "rangle": "rangle",
         "uparrow": "uparrow", "downarrow": "downarrow", "updownarrow": "updownarrow",
         "Uparrow": "Uparrow", "Downarrow": "Downarrow", "Updownarrow": "Updownarrow",
         "mid": "mid", "setminus": "setminus", "mapstochar": "mapstochar",
         "coprod": "coprod", "ointop": "oint", "intop": "int", "sum": "sum",
         "prod": "prod", "bigsqcup": "bigsqcup", "bigodot": "bigodot",
         "bigoplus": "bigoplus", "bigotimes": "bigotimes", "biguplus": "biguplus",
         "bigcup": "bigcup", "bigcap": "bigcap", "bigvee": "bigvee", "bigwedge": "bigwedge",
         "braceld": "braceld", "bracerd": "bracerd", "bracelu": "bracelu", "braceru": "braceru",
         "widehat": "widehat", "widetilde": "widetilde", "acute": "acute",
         "grave": "grave", "ddot": "ddot", "tilde": "tilde", "bar": "bar",
         "breve": "breve", "check": "check", "hat": "hat", "vec": "vec", "dot": "dot",
         "mathsection": "mathsection", "mathparagraph": "mathparagraph",
         "dagger": "dagger", "ddagger": "ddagger", "clubsuit": "clubsuit",
         "diamondsuit": "diamondsuit", "heartsuit": "heartsuit", "spadesuit": "spadesuit",
         "smallint": "smallint"}

MANUAL_UNI = {"(": 0x28, ")": 0x29, "[": 0x5B, "]": 0x5D, "<": 0x27E8, ">": 0x27E9,
              "/": 0x2F, "|": 0x7C, "backslash": 0x5C, "vert": 0x7C, "Vert": 0x2016,
              "lbrace": 0x7B, "rbrace": 0x7D, "lfloor": 0x230A, "rfloor": 0x230B,
              "lceil": 0x2308, "rceil": 0x2309, "uparrow": 0x2191, "downarrow": 0x2193,
              "updownarrow": 0x2195, "Uparrow": 0x21D1, "Downarrow": 0x21D3,
              "Updownarrow": 0x21D5, "infty": 0x221E, "mapstochar": 0x21A6,
              "braceld": 0x23AA, "bracerd": 0x23AA, "bracelu": 0x23AA, "braceru": 0x23AA,
              "lgroup": 0x27EE, "rgroup": 0x27EF, "arrowvert": 0x7C, "Arrowvert": 0x2016,
              "bracevert": 0x23AA, "smallint": 0x222B, "surd": 0x221A, "not": 0x29F8}

def uni_for(name):
    if name in MANUAL_UNI:
        return MANUAL_UNI[name]
    n = ALIAS.get(name, name)
    return unicp.get(n, unicp.get(name))

# ---- existing typesetting slots -----------------------------------------
mock = open(MOCK, encoding="utf-8", errors="replace").read()
def codes_of(var):
    i = mock.index("(defparameter " + var)
    j = mock.index("))", i)
    return set(int(x) for x in re.findall(r'\((\d+)\s+-?\d', mock[i:j]))
existing = {0: codes_of("*cmr-chars*"), 1: codes_of("*cmmi-chars*"), 2: codes_of("*cmsy-chars*")}
existing[3] = set(int(x) for x in re.findall(r'math-font-set-char font (\d+)', mock))

def tftopl(tfm):
    pl = "/tmp/%s.pl" % tfm
    subprocess.run(["tftopl", subprocess.check_output(["kpsewhich", tfm + ".tfm"]).decode().strip(), pl],
                   check=True, capture_output=True)
    return open(pl).read()

def char_metrics(pl):
    out = {}
    # tftopl prints "C X" for printable character codes and "O n" (octal) or
    # "D n" (decimal) otherwise; handle all three.
    for m in re.finditer(r'\(CHARACTER ([COD]) ([^\s\)]+)(.*?)\n\s*\)\n', pl, re.S):
        fmt, raw, body = m.groups()
        code = int(raw, 8) if fmt == 'O' else (int(raw, 10) if fmt == 'D' else ord(raw))
        def val(key):
            mm = re.search(r'\(' + key + r' R (-?[\d.]+)\)', body)
            return float(mm.group(1)) if mm else 0.0
        nextm = re.search(r'\(NEXTLARGER [OD] (\d+)\)', body)
        top = re.search(r'\(TOP [OD] (\d+)\)', body)
        bot = re.search(r'\(BOT [OD] (\d+)\)', body)
        rep = re.search(r'\(REP [OD] (\d+)\)', body)
        mid = re.search(r'\(MID [OD] (\d+)\)', body)
        out[code] = dict(w=val("CHARWD"), h=val("CHARHT"), d=val("CHARDP"), ic=val("CHARIC"),
                         next=int(nextm.group(1), 8) if nextm else None,
                         much=(int(top.group(1),8) if top else None, int(bot.group(1),8) if bot else None),
                         rep=int(rep.group(1),8) if rep else None,
                         mid=int(mid.group(1),8) if mid else None)
    return out

SIZES = {"10": 655360, "7": 458752, "5": 327680}
FONTS = {0: ["cmr10", "cmr7", "cmr5"], 1: ["cmmi10", "cmmi7", "cmmi5"],
         2: ["cmsy10", "cmsy7", "cmsy5"], 3: ["cmex10", "cmex10", "cmex10"]}
metrics = {}
for fam, names in FONTS.items():
    for size, name in enumerate(names):
        pl = tftopl(name)
        for code, d in char_metrics(pl).items():
            metrics[(fam, size, code)] = d

def scaled(x, design):
    return int(round(x * design))

# ---- emit ---------------------------------------------------------------
lines = []
lines.append(";;;; latex-tables.lisp --- generated by tools/gen-latex-tables.py; do not edit.")
lines.append(";;;;")
lines.append(";;;; Symbol/class tables come from LaTeX's fontmath.ltx (via plain.tex's")
lines.append(";;;; mathcodes); Unicode previews from unicode-math-table.tex, except for the")
lines.append(";;;; accents, which are curated to Latin Modern's spacing forms (CURATED_UNI);")
lines.append(";;;; the extra Computer Modern metrics are the real TFM values (store_scaled)")
lines.append(";;;; for the slots the sibling `typesetting` engine does not already ship.")
lines.append("(in-package #:svg)")
lines.append("")

lines.append("(defparameter *latex-symbols*")
lines.append("  ;; name (no backslash) -> (noad-class family code)")
lines.append("  '(")
for name in sorted(symbols):
    cls, fam, code = symbols[name]
    lines.append("    (\"%s\" %s %d %d)" % (name, cls, fam, code))
lines.append("    ))")
lines.append("")

lines.append("(defparameter *latex-accents*")
lines.append("  ;; name -> (family code)  (math accent, TeX \\mathaccent)")
lines.append("  '(")
for name in sorted(accents):
    fam, code = accents[name]
    lines.append("    (\"%s\" %d %d)" % (name, fam, code))
lines.append("    ))")
lines.append("")

lines.append("(defparameter *latex-delimiters*")
lines.append("  ;; name -> (noad-class (small-family . small-code) (large-family . large-code))")
lines.append("  '(")
for name in sorted(delims):
    cls, (sf, sc), (lf, lc) = delims[name]
    lines.append("    (\"%s\" %s (%d . %d) (%d . %d))" % (name, cls, sf, sc, lf, lc))
lines.append("    ))")
lines.append("")

lines.append("(defparameter *latex-char-symbols*")
lines.append("  ;; char code -> (noad-class family code)")
lines.append("  '(")
for ch in sorted(char_syms):
    cls, fam, code = char_syms[ch]
    lines.append("    (%d %s %d %d)" % (ch, cls, fam, code))
lines.append("    ))")
lines.append("")

# symbols that have an op class and take display limits vs nolimits
lines.append("(defparameter *latex-big-op-limits*")
lines.append("  ;; \\mathop atoms that get \\displaylimits (limits in display style)")
lines.append("  '(%s))" % " ".join('"%s"' % n for n in
      ["sum", "prod", "coprod", "bigcup", "bigcap", "bigvee", "bigwedge",
       "biguplus", "bigoplus", "bigotimes", "bigodot", "bigsqcup"]))
lines.append("")
lines.append("(defparameter *latex-big-op-nolimits*")
lines.append("  ;; \\mathop atoms that are always \\nolimits")
lines.append("  '(%s))" % " ".join('"%s"' % n for n in
      ["int", "intop", "oint", "ointop", "smallint"]))
lines.append("")
lines.append("(defparameter *latex-named-ops*")
lines.append("  ;; upright function names: \\mathop{\\rm ...}\\nolimits")
lines.append("  '(%s))" % " ".join('"%s"' % n for n in
      ["arccos", "arcsin", "arctan", "arg", "cos", "cosh", "cot", "coth", "csc",
       "deg", "det", "dim", "exp", "gcd", "hom", "inf", "ker", "lg", "lim",
       "liminf", "limsup", "ln", "log", "max", "min", "Pr", "sec", "sin", "sinh",
       "sup", "tan", "tanh"]))
lines.append("")
lines.append("(defparameter *latex-named-limits-ops*")
lines.append("  ;; named operators whose scripts go above/below in display style")
lines.append("  '(%s))" % " ".join('"%s"' % n for n in
      ["arg", "deg", "det", "dim", "gcd", "hom", "inf", "ker", "lim",
       "liminf", "limsup", "max", "min", "Pr", "sup"]))
lines.append("")

# unicode for every (family . code) the symbol tables reference
uni_entries = {}

# The math italic (cmmi) and calligraphic (cmsy) fonts carry the *same*
# letters as cmr in a different design, so a plain "A" must NOT preview as
# U+0041: Latin Modern Math would draw that upright. unicode-math names these
# alphabets \mitA / \mathcalA and keeps them in the math alphanumeric block.
ALPHABET = {1: (0x1D434, 0x1D44E),   # cmmi10: \mitA.., \mita..
            2: (0x1D49C, None)}      # cmsy10: \mathcalA.. (caps only)

# The math alphanumeric block is not contiguous: Unicode leaves a hole where a
# letter's glyph already lives elsewhere, and Latin Modern Math has no glyph at
# the hole at all (the browser then draws nothing).  Italic small h is the one
# in the ranges above: U+1D455 is unassigned and U+210E (Planck's constant) is
# the italic h.  A codepoint in here maps to the value instead.
MATH_ALPHABET_HOLES = {0x1D455: 0x210E}

def alphabet_cp(fam, name):
    "Math alphanumeric codepoint for a single ASCII LETTER in alphabet FAM."
    if fam not in ALPHABET or len(name) != 1:
        return None
    up, lo = ALPHABET[fam]
    if "A" <= name <= "Z" and up:
        cp = up + ord(name) - ord("A")
        return MATH_ALPHABET_HOLES.get(cp, cp)
    if "a" <= name <= "z" and lo:
        cp = lo + ord(name) - ord("a")
        return MATH_ALPHABET_HOLES.get(cp, cp)
    return None

# Slots whose LaTeX name is a plain character that does NOT name the glyph the
# CM font actually carries there, so the unicode-math lookup on the name is
# misleading: cmsy10 slot 0 is the math minus, not the ASCII hyphen that
# unicode-math associates with the name "-".
CURATED_UNI = {(2, 0): 0x2212}       # cmsy10 minus

# cmsy10 slots the symbol tables reference that unicode-math does not name --
# without an entry the slot has no preview glyph and the renderer falls back to
# the raw font code (\emptyset came out as ";", \lhook as ","). Two of them are
# also picked for size: CM's \bigcirc is a large circle, not the 10pt ○, and
# CM's \circ is the open circle Latin Modern keeps as U+25E6 (3.9pt against
# U+2218's 3.0), so both agree with a real LaTeX run to within .1pt.
CURATED_UNI.update({
    (2, 13): 0x25EF,    # \bigcirc  -> ◯  large circle
    (2, 14): 0x25E6,    # \circ     -> ◦  white bullet (open circle)
    (2, 15): 0x2219,    # \bullet   -> ∙  bullet operator
    (2, 54): 0x2215,    # \not      -> ∕  division slash (Latin Modern has no ⧸)
    (2, 59): 0x2205,    # \emptyset -> ∅  empty set
})

# TeX's math accents are *spacing* glyphs: make_math_accent keeps the accent on
# the base line and relies on the CM design sitting high in the em box (cmr10
# char 94, for instance, has ink from .540 to .694 em, above the .4305 em
# x-height). unicode-math instead names each accent with the combining mark
# that goes *after* a base character -- zero advance, ink to the left of the
# origin -- so a preview drawing it alone either drops it or puts it beside the
# formula. Latin Modern carries the same designs as the spacing accents of the
# Spacing Modifier Letters block: each pair below agrees to within 40 font
# units (.04 em) on every side of the ink box, and those are the glyphs this
# table selects. (cmr10 slots, family 0: see *latex-accents*.)
CURATED_UNI.update({
    (0, 18): 0x0060,    # \grave    -> `  grave accent
    (0, 19): 0x00B4,    # \acute    -> ´  acute accent
    (0, 20): 0x02C7,    # \check    -> ˇ  caron
    (0, 21): 0x02D8,    # \breve    -> ˘  breve
    (0, 22): 0x00AF,    # \bar      -> ¯  macron
    (0, 23): 0x02DA,    # \mathring -> ˚  ring above
    (0, 94): 0x02C6,    # \hat      -> ˆ  circumflex accent
    (0, 95): 0x02D9,    # \dot      -> ˙  dot above
    (0, 126): 0x02DC,   # \tilde    -> ˜  small tilde (high tilde)
    (0, 127): 0x00A8,   # \ddot     -> ¨  diaeresis
})

def note(fam, code, name):
    if code is None: return
    u = alphabet_cp(fam, name) or CURATED_UNI.get((fam, code)) or uni_for(name)
    if u and (fam, code) not in uni_entries:
        uni_entries[(fam, code)] = u
for name, (cls, fam, code) in symbols.items():
    note(fam, code, name)
for name, (fam, code) in accents.items():
    note(fam, code, name)
for name, (cls, small, large) in delims.items():
    rd = name if name in ALIAS else ALIAS.get(name, name)
    note(small[0], small[1], name)
    note(large[0], large[1], name)
for ch, (cls, fam, code) in char_syms.items():
    uni_entries.setdefault((fam, code), ch)

# TeX grows a delimiter by walking its NEXTLARGER chain, so every slot on a
# delimiter's chain must render as that delimiter. Walk each cmex chain and
# give the intermediate variants the same preview glyph (otherwise the larger
# \left( / \left[ variants would draw as stray ASCII characters).
cmex_next = {code: d["next"] for (fam, size, code), d in metrics.items()
             if fam == 3 and size == 0 and d["next"] is not None}
for name, (cls, small, large) in delims.items():
    if large[0] != 3:
        continue
    cp = uni_for(name)
    if not cp:
        continue
    code = large[1]
    while code is not None:
        uni_entries.setdefault((3, code), cp)
        code = cmex_next.get(code)

lines.append("(defparameter *latex-glyph-unicode*")
lines.append("  ;; (family . code) -> Unicode codepoint used for the SVG preview glyph")
lines.append("  '(")
for (fam, code) in sorted(uni_entries):
    lines.append("    ((%d . %d) . #x%X)" % (fam, code, uni_entries[(fam, code)]))
lines.append("    ))")
lines.append("")

# extra CM metrics for slots typesetting lacks
extra, larger, extens = [], [], []
for (fam, size, code), d in sorted(metrics.items()):
    # cmex is a single 10pt design shared by every size code; the other
    # families have genuine 10/7/5pt optical designs.
    design = 655360 if fam == 3 else list(SIZES.values())[size]
    if code not in existing[fam]:
        extra.append((fam, size, code, scaled(d["w"], design), scaled(d["h"], design),
                      scaled(d["d"], design), scaled(d["ic"], design)))
    if fam == 3:
        # Chains and extensible recipes must cover the engine's existing cmex
        # slots too: the vendored font stops the ( chain at 18, while cmex10
        # continues 18 -> 32 -> 48 (extensible).
        if d["next"] is not None:
            larger.append((fam, code, d["next"]))
        if d["rep"] is not None:
            top, bot = d["much"]
            top = top or 0
            bot = bot or 0
            mid = d["mid"] or 0
            # typesetting's recipe order is (top mid bot rep)
            extens.append((fam, code, top, mid, bot, d["rep"]))

# de-duplicate metrics that repeat across cmex size codes
seen = set(); extra_u = []
for e in extra:
    fam, size, code = e[0], e[1], e[2]
    key = (fam, code, e[3], e[4], e[5], e[6])
    if key in seen: continue
    seen.add(key); extra_u.append(e)
extra = extra_u
seen = set(); larger_u = []
for e in larger:
    if e in seen: continue
    seen.add(e); larger_u.append(e)
larger = larger_u
seen = set(); extens_u = []
for e in extens:
    if e in seen: continue
    seen.add(e); extens_u.append(e)
extens = extens_u

lines.append("(defparameter *cm-extra-chars*")
lines.append("  ;; (family size-code code width height depth italic) in sp, real CM TFM metrics")
lines.append("  '(")
for e in extra:
    lines.append("    (%d %d %d %d %d %d %d)" % e)
lines.append("    ))")
lines.append("")
lines.append("(defparameter *cm-extra-larger* '(%s))" % " ".join("(%d %d %d)" % e for e in larger))
lines.append("(defparameter *cm-extra-extensible* '(%s))" % " ".join("(%d %d %d %d %d %d)" % e for e in extens))
lines.append("")

open(OUT, "w").write("\n".join(lines) + "\n")
print("wrote", OUT)
print("symbols", len(symbols), "accents", len(accents), "delims", len(delims),
      "char-syms", len(char_syms), "unicode", len(uni_entries),
      "extra-chars", len(extra), "larger", len(larger), "extensible", len(extens))
