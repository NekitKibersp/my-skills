#!/usr/bin/env python3
"""Титульный лист студента по образцу ГБПОУ «Донецкий политехнический колледж».

Отдельный файл:
  make_title.py --subject "..." --teacher "Близкая Ольга Владимировна" --topic "..." --out title.docx
Вставить первой страницей в готовую работу (номер страницы на титульном не ставится):
  make_title.py ... --into work.docx [--out work_with_title.docx]
Постоянные данные студента берутся из ../student.json (можно переопределить флагами).
"""
import argparse, datetime, json, os, re, sys
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "student.json")


def short_name(full: str) -> str:
    """«Близкая Ольга Владимировна» -> «Близкая О.В.»; уже короткое имя не трогает."""
    full = full.strip()
    if re.search(r"[А-ЯA-Z]\.\s*[А-ЯA-Z]?\.?$", full):
        return re.sub(r"\.\s+", ".", full)
    parts = full.split()
    if len(parts) >= 2:
        return parts[0] + " " + "".join(p[0].upper() + "." for p in parts[1:3])
    return full


def build_lines(a):
    """Возвращает список (текст, выравнивание, отступ_слева_см, полужирный)."""
    C, L = "center", "left"
    R = 11.0  # отступ правого блока «Выполнил»
    lines = [(a.college, C, 0, False)]
    lines += [("", C, 0, False)] * 6
    lines += [(a.type.upper(), C, 0, False)]
    lines += [(a.discipline_label, C, 0, False)]
    lines += [(f"«{a.subject}»", C, 0, False)]
    lines += [("", C, 0, False)]
    if a.topic:
        lines += [(f"на тему: «{a.topic}»", C, 0, False)]
    if a.qualification:
        lines += [(f"Квалификация: {a.qualification}", C, 0, False)]
    lines += [("", C, 0, False)] * (7 - bool(a.topic) - bool(a.qualification))
    lines += [("Выполнил:", L, R, False), (a.student, L, R, False),
              (f"Студент: {a.course} курса", L, R, False)]
    if a.group:
        lines += [(f"Группы: {a.group}", L, R, False)]
    lines += [("Руководитель:", L, R, False), (short_name(a.teacher), L, R, False)]
    lines += [("", C, 0, False)] * (5 if a.group else 6)
    lines += [(a.city, C, 0, False), (f"{a.year} год", C, 0, False)]
    return lines


def fmt(p, text, align, indent, bold):
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER if align == "center" else WD_ALIGN_PARAGRAPH.LEFT
    pf = p.paragraph_format
    pf.first_line_indent = Cm(0)
    pf.left_indent = Cm(indent)
    pf.right_indent = Cm(0)
    pf.space_before = Pt(0)
    pf.space_after = Pt(0)
    pf.line_spacing = 1.5
    if text:
        r = p.add_run(text)
        r.bold = bold
        r.font.name = "Times New Roman"
        r.font.size = Pt(14)
        r._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:eastAsia"), "Times New Roman")


def set_title_pg(section):
    """Особый колонтитул первой страницы: на титульном нет номера."""
    sectPr = section._sectPr
    if sectPr.find(qn("w:titlePg")) is None:
        sectPr.append(OxmlElement("w:titlePg"))


def main():
    data = {}
    if os.path.exists(DATA):
        with open(DATA, encoding="utf-8") as f:
            data = json.load(f)
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject", required=True, help="название предмета/модуля")
    ap.add_argument("--teacher", required=True, help="ФИО преподавателя (полное или Фамилия И.О.)")
    ap.add_argument("--topic", default="", help="тема работы")
    ap.add_argument("--type", default="Реферат", help="РЕФЕРАТ / ОТЧЕТ / КУРСОВАЯ РАБОТА / ...")
    ap.add_argument("--discipline-label", default="по дисциплине",
                    help="строка под типом: «по дисциплине», «По учебной практике» и т.п.")
    ap.add_argument("--student", default=data.get("student"))
    ap.add_argument("--course", default=data.get("course"))
    ap.add_argument("--group", default=data.get("group"))
    ap.add_argument("--college", default=data.get("ministry_and_college"))
    ap.add_argument("--qualification", default=data.get("qualification"), help="строка «Квалификация: …»; по умолчанию не ставится")
    ap.add_argument("--city", default=data.get("city", "Донецк"))
    ap.add_argument("--year", default=str(datetime.date.today().year))
    ap.add_argument("--into", help="готовая работа .docx: титульный вставляется первой страницей")
    ap.add_argument("--out", help="куда сохранить (по умолчанию title.docx или поверх --into)")
    a = ap.parse_args()
    for k in ("student", "course", "college"):
        if not getattr(a, k):
            sys.exit(f"нет данных: {k} (заполни student.json или передай флагом)")

    lines = build_lines(a)
    if a.into:
        doc = Document(a.into)
        body = doc.element.body
        first = body[0]
        for text, align, ind, bold in lines:
            p = doc.add_paragraph()  # добавится в конец — переносим в начало
            fmt(p, text, align, ind, bold)
            first.addprevious(p._p)
        # разрыв страницы после титульного
        br = doc.add_paragraph()
        br.paragraph_format.space_after = Pt(0)
        br.add_run().add_break(WD_BREAK.PAGE)
        first.addprevious(br._p)
        set_title_pg(doc.sections[0])
        out = a.out or a.into
    else:
        doc = Document()
        s = doc.sections[0]
        s.left_margin, s.right_margin = Cm(3), Cm(1.5)
        s.top_margin = s.bottom_margin = Cm(2)
        for text, align, ind, bold in lines:
            fmt(doc.add_paragraph(), text, align, ind, bold)
        # убрать пустой абзац по умолчанию в начале документа
        body = doc.element.body
        if body[0].tag == qn("w:p") and not body[0].xpath(".//w:t"):
            body.remove(body[0])
        out = a.out or "title.docx"
    doc.save(out)
    print(out)


if __name__ == "__main__":
    main()
