#!/usr/bin/env python3
"""Скачать архив по публичной ссылке Яндекс Диска и распаковать с правильными русскими именами.

python3 -I fetch_zip.py <ссылка_или_путь_к_zip> <пустая_папка>
Пропускает мусор сборки (x64, Debug, Release, .vs, bin, obj) — они не нужны и весят десятки МБ.
"""
import json, os, sys, urllib.parse, urllib.request, zipfile

SKIP = ('/x64/', '/Debug/', '/Release/', '/.vs/', '/bin/', '/obj/', '/ipch/')

def download(link, out):
    api = 'https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=' + urllib.parse.quote(link, safe='')
    href = json.load(urllib.request.urlopen(api))['href']
    urllib.request.urlretrieve(href, out)

def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    if src.startswith('http'):
        z = os.path.join(dst, '_archive.zip'); download(src, z)
    else:
        z = src
    for i in zipfile.ZipFile(z).infolist():
        n = i.filename
        if not i.flag_bits & 0x800:          # имя не в UTF-8 → в Windows-архивах это cp866
            try: n = n.encode('cp437').decode('cp866')
            except UnicodeError: pass
        if any(s in '/' + n for s in SKIP) or '..' in n.split('/'):
            continue
        p = os.path.join(dst, n)
        if n.endswith('/'):
            os.makedirs(p, exist_ok=True); continue
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with zipfile.ZipFile(z) as zz, open(p, 'wb') as f:
            f.write(zz.read(i))
        print(n)

if __name__ == '__main__':
    main()
