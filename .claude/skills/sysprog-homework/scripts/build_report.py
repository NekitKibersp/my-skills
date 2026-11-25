#!/usr/bin/env python3
"""Собрать отчёт .docx в формате образца пользователя (без титульника).

python3 build_report.py <spec.json> <out.docx> [образец.docx]
Образец берётся только ради стилей и полей; по умолчанию assets/report-sample.docx.
Если пользователь прислал свой свежий отчёт — передать его третьим аргументом.

spec.json:
{
  "header": "Домашнее задание",                 # жирный, первая строка
  "topic": "Обработка исключений.",               # «Тема: ...» с отступом
  "tasks": [
    {"title": "Написать программу, которая ...",  # после жирного «Задание N.»
     "code": "путь/к/файлу.cpp",
     "image": "путь/к/скрину.png",               # можно null — тогда без рисунка
     "caption": "Консольное приложение с ...",    # → «Рис. N ...» курсив 12, по центру
     "result": "Мы научились писать программу, которая ..."}   # → «Результат: ...»
  ]
}
Формат образца: Times New Roman 14, по ширине, одинарный интервал, поля 30/15/20/20 мм,
код — обычным Times New Roman 14 по строке на абзац, без рамок и подсветки.
"""
import json, os, re, shutil, sys, tempfile, zipfile
from xml.sax.saxutils import escape
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
F = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>'

def rpr(b=False, i=False, sz=28, en=False):
    return ('<w:rPr>' + F + ('<w:b/><w:bCs/>' if b else '') + ('<w:i/><w:iCs/>' if i else '')
            + f'<w:sz w:val="{sz}"/><w:szCs w:val="{sz}"/>' + ('<w:lang w:val="en-US"/>' if en else '') + '</w:rPr>')

def run(t, **k):
    return f'<w:r>{rpr(**k)}<w:t xml:space="preserve">{escape(t)}</w:t></w:r>' if t else ''

def para(runs='', jc='both', ind='', **k):
    return f'<w:p><w:pPr>{ind}<w:jc w:val="{jc}"/>{rpr(**k)}</w:pPr>{runs}</w:p>'

def picture(rid, n, path):
    w, h = Image.open(path).size
    cx = 5940425; cy = int(cx * h / w)          # во всю ширину текста (16,5 см)
    return (f'<w:p><w:pPr><w:jc w:val="both"/>{rpr()}</w:pPr><w:r>{rpr()}<w:drawing>'
            f'<wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{cx}" cy="{cy}"/>'
            f'<wp:docPr id="{100 + n}" name="Рисунок {n}"/><wp:cNvGraphicFramePr>'
            '<a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>'
            '</wp:cNvGraphicFramePr><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            f'<pic:nvPicPr><pic:cNvPr id="{100 + n}" name=""/><pic:cNvPicPr/></pic:nvPicPr>'
            f'<pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
            f'<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic>'
            '</wp:inline></w:drawing></w:r></w:p>')

def main():
    spec = json.load(open(sys.argv[1], encoding='utf-8'))
    out = sys.argv[2]
    tpl = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, '..', 'assets', 'report-sample.docx')
    base = os.path.dirname(os.path.abspath(sys.argv[1]))
    tmp = tempfile.mkdtemp()
    zipfile.ZipFile(tpl).extractall(tmp)
    media = os.path.join(tmp, 'word', 'media')
    shutil.rmtree(media, ignore_errors=True); os.makedirs(media)
    relp = os.path.join(tmp, 'word', '_rels', 'document.xml.rels')
    rels = open(relp, encoding='utf-8').read()
    rels = re.sub(r'<Relationship [^>]*Target="media/[^"]*"[^>]*/>', '', rels)
    ct = os.path.join(tmp, '[Content_Types].xml'); c = open(ct, encoding='utf-8').read()
    if 'Extension="png"' not in c:
        c = c.replace('<Default ', '<Default Extension="png" ContentType="image/png"/><Default ', 1)
        open(ct, 'w', encoding='utf-8').write(c)

    body = [para(run(spec.get('header', 'Домашнее задание'), b=True), b=True),
            para(run('Тема: ' + spec['topic']), ind='<w:ind w:left="1416" w:firstLine="708"/>')]
    pic = 0
    for n, t in enumerate(spec['tasks'], 1):
        body.append(para(run(f'Задание {n}.', b=True) + run(' ', b=True) + run(t['title'])))
        body.append(para(run('Код') + run(':', en=True), en=True))
        src = open(os.path.join(base, t['code']), encoding='utf-8-sig').read()
        for line in src.splitlines():
            body.append(para(run(line.replace('\t', '    '), en=True), en=True))
        body.append(para())
        if t.get('image'):
            pic += 1; rid = f'rIdImg{pic}'
            shutil.copy(os.path.join(base, t['image']), os.path.join(media, f'image{pic}.png'))
            rels = rels.replace('</Relationships>',
                f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
                f'Target="media/image{pic}.png"/></Relationships>')
            body.append(picture(rid, pic, os.path.join(media, f'image{pic}.png')))
            body.append(para(run(f'Рис. {pic} ' + t['caption'], i=True, sz=24), jc='center', i=True, sz=24))
            body.append(para(jc='center', i=True))
        body.append(para(run('Результат: ' + t['result'])))
        body.append(para())
    open(relp, 'w', encoding='utf-8').write(rels)
    dp = os.path.join(tmp, 'word', 'document.xml'); x = open(dp, encoding='utf-8').read()
    s = x.find('<w:body>') + len('<w:body>'); e = x.find('<w:sectPr')
    open(dp, 'w', encoding='utf-8').write(x[:s] + ''.join(body) + x[e:])
    if os.path.exists(out): os.remove(out)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(tmp):
            for f in files:
                full = os.path.join(root, f); z.write(full, os.path.relpath(full, tmp))
    shutil.rmtree(tmp); print(out)

if __name__ == '__main__':
    main()
