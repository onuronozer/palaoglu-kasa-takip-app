"""Export only dated cafe revenue from monthly tabs of the existing workbook."""

import argparse
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
import io
import json
from pathlib import Path
import posixpath
import re
import sys
import time
import unicodedata
from urllib.request import urlopen
import xml.etree.ElementTree as ET
import zipfile

SPREADSHEET_ID = "1W6b9GxO6g-krIn_pXBidJpxhrPQypReLjocA3jq4bRQ"
EXPORT_URL = f"https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/export?format=xlsx"
SNAPSHOT_URL = "https://onuronozer.github.io/palaoglu-kasa-takip-app/data/sheet-ciro.json"
MONTHS = "ocak subat mart nisan mayis haziran temmuz agustos eylul ekim kasim aralik".split()
REL_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def fold(value):
    value = value.lower().replace("ı", "i")
    return "".join(c for c in unicodedata.normalize("NFKD", value) if not unicodedata.combining(c))


def named_period(title):
    match = re.fullmatch(r"\s*(" + "|".join(MONTHS) + r")[\s._/-]*(20\d{2})?\s*", fold(title))
    if not match:
        return None
    return MONTHS.index(match[1]) + 1, int(match[2]) if match[2] else None


def cell_value(cell, shared):
    if cell.get("t") == "inlineStr":
        return "".join(cell.find("{*}is").itertext())
    value = cell.findtext("{*}v", "")
    if cell.get("t") == "s":
        return shared[int(value)]
    if cell.get("t") == "e":
        return ""
    if cell.get("t") in ("str", "d"):
        return value
    try:
        return Decimal(value)
    except InvalidOperation:
        return value


def parse_day(value, epoch):
    if isinstance(value, Decimal):
        if not value.is_finite() or not 30000 <= value <= 100000:
            return None
        return epoch + timedelta(days=int(value))
    text = str(value).strip()
    for pattern in ("%d.%m.%Y", "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d.%m.%y"):
        try:
            return datetime.strptime(text, pattern).date()
        except ValueError:
            pass
    return None


def parse_amount(value):
    if isinstance(value, Decimal):
        amount = value
    else:
        text = re.sub(r"[\s₺]|TL", "", str(value), flags=re.I)
        if "," in text:
            text = text.replace(".", "").replace(",", ".")
        elif re.fullmatch(r"\d{1,3}(?:\.\d{3})+", text):
            text = text.replace(".", "")
        try:
            amount = Decimal(text)
        except InvalidOperation:
            return None
    return amount if amount.is_finite() and amount > 0 else None


def extract_months(workbook_bytes):
    months = {}
    with zipfile.ZipFile(io.BytesIO(workbook_bytes)) as archive:
        book = ET.fromstring(archive.read("xl/workbook.xml"))
        properties = book.find("{*}workbookPr")
        epoch = date(1904, 1, 1) if properties is not None and properties.get("date1904") in ("1", "true") else date(1899, 12, 30)
        relationships = {
            rel.get("Id"): rel.get("Target")
            for rel in ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
            if rel.get("TargetMode") != "External"
        }
        shared = []
        if "xl/sharedStrings.xml" in archive.namelist():
            shared = ["".join(item.itertext()) for item in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
        for sheet in book.findall(".//{*}sheet"):
            title = sheet.get("name", "")
            period = named_period(title)
            if period is None:
                continue
            target = relationships.get(sheet.get(REL_NS + "id"))
            if not target:
                continue
            path = target.lstrip("/") if target.startswith("/") else posixpath.normpath(posixpath.join("xl", target))
            if not path.startswith("xl/"):
                raise ValueError("Unexpected worksheet path")
            rows = []
            for row in ET.fromstring(archive.read(path)).findall(".//{*}sheetData/{*}row"):
                rows.append({re.sub(r"\d", "", c.get("r", "")): cell_value(c, shared) for c in row})
            header_index = next((i for i, row in enumerate(rows[:10]) if fold(str(row.get("A", ""))).strip() in ("gun", "tarih") and fold(str(row.get("B", ""))).strip() in ("ciro", "toplam ciro")), None)
            if header_index is None:
                continue
            dated = [(parse_day(row.get("A", ""), epoch), row.get("B", "")) for row in rows[header_index + 1:]]
            dated = [(day, value) for day, value in dated if day is not None]
            month_number, year = period
            if year is None:
                years = Counter(day.year for day, _ in dated if day.month == month_number)
                if not years or len(years) > 1:
                    continue
                year = next(iter(years))
            month_key = f"{year:04}-{month_number:02}"
            if month_key in months:
                raise ValueError(f"Multiple source tabs for {month_key}")
            totals = {}
            invalid_dates = 0
            for day, value in dated:
                amount = parse_amount(value)
                if amount is None:
                    continue
                if day.year != year or day.month != month_number:
                    invalid_dates += 1
                    continue
                key = day.isoformat()
                if key in totals:
                    raise ValueError(f"Duplicate revenue day in {month_key}: {key}")
                totals[key] = float(amount.quantize(Decimal("0.01")))
            if invalid_dates:
                print(
                    f"WARNING: {title!r} contains {invalid_dates} date(s) outside {month_key}",
                    file=sys.stderr,
                )
            months[month_key] = {
                "sheetTitle": title,
                "ciroByDate": dict(sorted(totals.items())),
                "invalidDateCount": invalid_dates,
            }
    if not months:
        raise ValueError("No monthly cafe revenue tabs found")
    return dict(sorted(months.items()))


def download(url):
    for attempt in range(3):
        try:
            with urlopen(url, timeout=45) as response:
                return response.read()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2 * (attempt + 1))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path, default=Path("web/data/sheet-ciro.json"))
    parser.add_argument("--allow-stale", action="store_true")
    args = parser.parse_args()
    try:
        source = args.input.read_bytes() if args.input else download(EXPORT_URL)
        snapshot = {
            "version": 1,
            "spreadsheetId": SPREADSHEET_ID,
            "checkedAt": datetime.now(timezone.utc).isoformat(),
            "months": extract_months(source),
        }
    except Exception:
        if not args.allow_stale:
            raise
        snapshot = json.loads(download(SNAPSHOT_URL))
        if snapshot.get("version") != 1 or snapshot.get("spreadsheetId") != SPREADSHEET_ID or not snapshot.get("months") or not snapshot.get("checkedAt"):
            raise ValueError("No valid previous snapshot")
        print("WARNING: Sheet unavailable; preserving previous snapshot and its original checkedAt.", file=sys.stderr)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Revenue snapshot: {len(snapshot['months'])} months; latest {max(snapshot['months'])}")


if __name__ == "__main__":
    main()
