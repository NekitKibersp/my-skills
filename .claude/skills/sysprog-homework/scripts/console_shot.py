#!/usr/bin/env python3
"""Нарисовать «скриншот» консоли отладки Visual Studio (Windows Terminal, тёмная тема).

python3 console_shot.py <out.png> <ИмяПроекта> <файл_с_выводом.txt> [код_возврата]
В файле — то, что видно в консоли (ввод пользователя пишется в той же строке, как в настоящей консоли).
Хвост «C:\\Users\\stud\\...exe (процесс N) завершил работу с кодом 0» добавляется сам.
Это ЗАМЕНА настоящего скрина — пользователя всегда предупреждать, что лучше снять свой (Ctrl+F5).
"""
import random, sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
UI = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

def shot(lines, out, W=1127, H=631):
    im = Image.new('RGB', (W, H), (12, 12, 12)); d = ImageDraw.Draw(im)
    g = (220, 220, 220)
    d.rectangle([0, 0, W, 46], fill=(32, 32, 32))
    d.rounded_rectangle([14, 8, 250, 52], radius=8, fill=(12, 12, 12))
    d.rectangle([26, 24, 40, 36], outline=(200, 200, 200))
    d.text((50, 24), 'Консоль отладки Microsoft Vi', font=ImageFont.truetype(UI, 12), fill=(240, 240, 240))
    d.rectangle([220, 14, 248, 46], fill=(12, 12, 12))
    d.line([229, 26, 237, 34], fill=g); d.line([237, 26, 229, 34], fill=g)
    d.line([271, 30, 281, 30], fill=g); d.line([276, 25, 276, 35], fill=g)
    d.line([302, 28, 306, 32], fill=g); d.line([306, 32, 310, 28], fill=g)
    d.line([1000, 27, 1010, 27], fill=g); d.rectangle([1046, 22, 1055, 31], outline=g)
    d.line([1092, 22, 1101, 31], fill=g); d.line([1101, 22, 1092, 31], fill=g)
    f = ImageFont.truetype(FONT, 14); y = 58; cols = 118
    wrapped = []
    for l in lines:
        while len(l) > cols: wrapped.append(l[:cols]); l = l[cols:]
        wrapped.append(l)
    for l in wrapped:
        d.text((15, y), l, font=f, fill=(204, 204, 204)); y += 19
    w = d.textlength(wrapped[-1], font=f)
    d.line([16 + w, y - 19, 16 + w, y - 3], fill=(204, 204, 204))
    im.save(out)

def main():
    out, name, txt = sys.argv[1:4]
    code = sys.argv[4] if len(sys.argv) > 4 else '0'
    lines = open(txt, encoding='utf-8').read().rstrip('\n').split('\n')
    lines += ['', f'C:\\Users\\stud\\{name}\\x64\\Debug\\{name}.exe (процесс {random.randint(2000, 15000)}) '
              f'завершил работу с кодом {code} (0x{int(code):x}).',
              'Чтобы автоматически закрывать консоль при остановке отладки, включите параметр "Сервис" ->"Параметры" ->"Отладка" -> "Автоматически закрыть консоль при остановке отладки".',
              'Нажмите любую клавишу, чтобы закрыть это окно…']
    shot(lines, out)

if __name__ == '__main__':
    main()
