#!/usr/bin/env python3
"""Records the tutor's voice at build time, so the child's app never needs
a network.

Reads tool/voice/clips.json (the clips every line is cut into, written by
`VOICE_DUMP=1 flutter test test/voice_clips_test.dart`), asks Gemini TTS for
each clip that is not recorded yet, checks the recording with speech
recognition, trims the silence and writes AAC files to
assets/voice/<lang>/ with an index.json (clip text -> file name).

    GEMINI_API_KEY=... python3 tool/voice/make_voice.py [--lang ru] [--limit 5]

Needs ffmpeg. Files already listed in index.json are kept, so a run after
changing one line records only the new clips.
"""

import argparse
import base64
import concurrent.futures as cf
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
API = "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent"
TTS_MODEL = os.environ.get("TTS_MODEL", "gemini-3.1-flash-tts-preview")
STT_MODEL = os.environ.get("STT_MODEL", "gemini-3.5-flash")
VOICE = os.environ.get("TTS_VOICE", "Leda")
LANG_NAME = {
    "ru": "Russian",
    "de": "German",
    "en": "English",
    "fr": "French",
    "es": "Spanish",
}


def call(model, body, tries=6):
    key = os.environ.get("GEMINI_API_KEY", "")
    req = urllib.request.Request(
        API.format(model),
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    for i in range(tries):
        try:
            return json.load(urllib.request.urlopen(req, timeout=120))
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 503) and i < tries - 1:
                time.sleep(4 * 2 ** i)
                continue
            raise
        except (urllib.error.URLError, TimeoutError):
            if i < tries - 1:
                time.sleep(4 * 2 ** i)
                continue
            raise


_WORDS = {
    "ru": (
        "ноль один два три четыре пять шесть семь восемь девять десять "
        "одиннадцать двенадцать тринадцать четырнадцать пятнадцать "
        "шестнадцать семнадцать восемнадцать девятнадцать".split(),
        "_ _ двадцать тридцать сорок пятьдесят шестьдесят семьдесят "
        "восемьдесят девяносто".split(),
        "_ сто двести триста четыреста пятьсот шестьсот семьсот восемьсот "
        "девятьсот".split(),
    ),
    "de": (
        "null eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf "
        "dreizehn vierzehn fünfzehn sechzehn siebzehn achtzehn "
        "neunzehn".split(),
        "_ _ zwanzig dreißig vierzig fünfzig sechzig siebzig achtzig "
        "neunzig".split(),
        "_ hundert zweihundert dreihundert vierhundert fünfhundert "
        "sechshundert siebenhundert achthundert neunhundert".split(),
    ),
    "en": (
        "zero one two three four five six seven eight nine ten eleven "
        "twelve thirteen fourteen fifteen sixteen seventeen eighteen "
        "nineteen".split(),
        "_ _ twenty thirty forty fifty sixty seventy eighty ninety".split(),
        "_ one_hundred two_hundred three_hundred four_hundred five_hundred "
        "six_hundred seven_hundred eight_hundred nine_hundred".split(),
    ),
    "fr": (
        "zéro un deux trois quatre cinq six sept huit neuf dix onze douze "
        "treize quatorze quinze seize dix-sept dix-huit dix-neuf".split(),
        "_ _ vingt trente quarante cinquante soixante soixante quatre-vingt "
        "quatre-vingt".split(),
        "_ cent deux_cents trois_cents quatre_cents cinq_cents six_cents "
        "sept_cents huit_cents neuf_cents".split(),
    ),
    "es": (
        "cero uno dos tres cuatro cinco seis siete ocho nueve diez once doce "
        "trece catorce quince dieciséis diecisiete dieciocho "
        "diecinueve".split(),
        "_ _ veinte treinta cuarenta cincuenta sesenta setenta ochenta "
        "noventa".split(),
        "_ cien doscientos trescientos cuatrocientos quinientos seiscientos "
        "setecientos ochocientos novecientos".split(),
    ),
}

_ES_20S = (
    "veinte veintiuno veintidós veintitrés veinticuatro veinticinco "
    "veintiséis veintisiete veintiocho veintinueve".split()
)


def number_words(n, lang):
    """0-100 and the full hundreds in words, so the voice cannot misread
    the digits ("0" was once read as "300")."""
    ones, tens, hundreds = _WORDS[lang]
    if n < 20:
        return ones[n]
    if n % 100 == 0:
        return hundreds[n // 100].replace("_", " ")
    t, o = divmod(n, 10)
    if lang == "fr":
        if n == 80:
            return "quatre-vingts"
        if t in (7, 9):  # soixante-dix, quatre-vingt-onze
            o += 10
        if o == 0:
            return tens[t]
        if o in (1, 11) and t < 8:
            return f"{tens[t]} et {ones[o]}"
        return f"{tens[t]}-{ones[o]}"
    if lang == "es" and t == 2:
        return _ES_20S[o]
    if o == 0:
        return tens[t]
    if lang == "es":
        return f"{tens[t]} y {ones[o]}"
    if lang == "de":
        return ("ein" if o == 1 else ones[o]) + "und" + tens[t]
    if lang == "en":
        return f"{tens[t]}-{ones[o]}"
    return f"{tens[t]} {ones[o]}"


def spoken(text, lang):
    """What the voice should read: a bare number in words."""
    if text.isdigit():
        return number_words(int(text), lang) + "."
    return text


def tts(text, lang):
    style = (
        f"Say warmly and calmly in {LANG_NAME[lang]}, like a kind teacher "
        f"talking to a six-year-old: "
    )
    body = {
        "contents": [{"parts": [{"text": style + spoken(text, lang)}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}
            },
        },
    }
    r = call(TTS_MODEL, body)
    try:
        part = r["candidates"][0]["content"]["parts"][0]["inlineData"]
    except (KeyError, IndexError) as e:
        raise RuntimeError(f"no audio in the answer: {e}") from e
    mime = part["mimeType"]
    rate = int(re.search(r"rate=(\d+)", mime).group(1)) if "rate=" in mime else 24000
    return base64.b64decode(part["data"]), rate


def stt(path, lang, number):
    ask = (
        f"This audio is one number said in {LANG_NAME[lang]}. "
        "Reply with the number in digits only."
        if number
        else f"Transcribe exactly what is said in this {LANG_NAME[lang]} "
        "audio. Reply with the words only."
    )
    data = base64.b64encode(open(path, "rb").read()).decode()
    body = {
        "contents": [
            {
                "parts": [
                    {"inline_data": {"mime_type": "audio/mp4", "data": data}},
                    {"text": ask},
                ]
            }
        ]
    }
    r = call(STT_MODEL, body)
    return "".join(
        p.get("text", "") for p in r["candidates"][0]["content"]["parts"]
    ).strip()


def confirms(path, lang, text):
    """Short fragments ("по", "Zehner") are often misheard without context:
    ask whether the audio says exactly this."""
    data = base64.b64encode(open(path, "rb").read()).decode()
    body = {
        "contents": [
            {
                "parts": [
                    {"inline_data": {"mime_type": "audio/mp4", "data": data}},
                    {"text": f"Does this {LANG_NAME[lang]} audio say exactly "
                     f"\"{text}\" and nothing else? Answer yes or no."},
                ]
            }
        ]
    }
    r = call(STT_MODEL, body)
    t = "".join(p.get("text", "") for p in r["candidates"][0]["content"]["parts"])
    return t.strip().lower().startswith("yes")


def norm(s):
    s = s.lower().replace("ё", "е")
    return re.sub(r"[^\w]+", " ", s).strip()


def matches(text, heard):
    if text.isdigit():
        return re.sub(r"\D", "", heard) == text
    return difflib.SequenceMatcher(None, norm(text), norm(heard)).ratio() >= 0.8


def encode(pcm, rate, out):
    with tempfile.NamedTemporaryFile(suffix=".pcm") as f:
        f.write(pcm)
        f.flush()
        # Trim silence at both ends, keep a short breath, then AAC mono.
        trim = (
            "silenceremove=start_periods=1:start_threshold=-45dB:"
            "start_silence=0.06"
        )
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error",
                "-f", "s16le", "-ar", str(rate), "-ac", "1", "-i", f.name,
                "-af", f"{trim},areverse,{trim},areverse,"
                "afade=t=in:d=0.01",
                "-c:a", "aac", "-b:a", "40k", "-ar", "24000", out,
            ],
            check=True,
        )


def name_for(text):
    return hashlib.sha1(text.encode()).hexdigest()[:12] + ".m4a"


def record(text, lang, folder, check=True, tries=3):
    out = os.path.join(folder, name_for(text))
    heard = ""
    for _ in range(tries):
        pcm, rate = tts(text, lang)
        encode(pcm, rate, out)
        if not check:
            return text, os.path.basename(out), ""
        heard = stt(out, lang, text.isdigit())
        if matches(text, heard) or (
            len(text.split()) <= 3 and confirms(out, lang, text)
        ):
            return text, os.path.basename(out), heard
    os.remove(out)
    raise RuntimeError(f"{lang} {text!r}: heard {heard!r}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", action="append")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--no-check", action="store_true")
    a = ap.parse_args()
    clips = json.load(open(os.path.join(HERE, "clips.json")))
    failed = []
    for lang in a.lang or list(clips):
        folder = os.path.join(APP, "assets", "voice", lang)
        os.makedirs(folder, exist_ok=True)
        index_path = os.path.join(folder, "index.json")
        index = json.load(open(index_path)) if os.path.exists(index_path) else {}
        want = [
            t for t in clips[lang]
            if t not in index or not os.path.exists(os.path.join(folder, index[t]))
        ]
        if a.limit:
            want = want[: a.limit]
        print(f"{lang}: {len(want)} to record, {len(index)} kept", flush=True)
        with cf.ThreadPoolExecutor(a.workers) as ex:
            jobs = {
                ex.submit(record, t, lang, folder, not a.no_check): t for t in want
            }
            for n, j in enumerate(cf.as_completed(jobs), 1):
                try:
                    text, file, heard = j.result()
                    index[text] = file
                    print(f"  {n}/{len(want)} {text!r} ok", flush=True)
                except Exception as e:  # noqa: BLE001
                    failed.append(f"{lang} {jobs[j]!r}: {e}")
                    print(f"  {n}/{len(want)} FAILED {e}", flush=True)
                if n % 20 == 0:
                    _save(index_path, index, clips[lang])
        _save(index_path, index, clips[lang])
    if failed:
        print("\nFailed:\n" + "\n".join(failed))
        sys.exit(1)


def _save(path, index, order):
    # Only clips that are still used; the files of dropped clips stay until
    # removed by hand.
    keep = {t: index[t] for t in order if t in index}
    with open(path, "w") as f:
        json.dump(keep, f, ensure_ascii=False, indent=0, sort_keys=True)
        f.write("\n")


if __name__ == "__main__":
    main()
