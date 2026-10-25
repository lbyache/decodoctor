#!/usr/bin/env python3
"""Convierte el listado de medicamentos de ANMAT (CSV) al formato de medicamentos.json.

Uso:
    python3 -I build_from_anmat.py <entrada.csv> <salida.json> \
        [--generic-col "Principio Activo"] [--brand-col "Nombre Comercial"] \
        [--strength-col "Potencia"] [--form-col "Forma Farmaceutica"] [--delimiter ";"]

Agrupa por droga genérica (una entrada por droga o asociación) y junta marcas, concentraciones y
formas. Los nombres de columna por defecto son una suposición: confirmarlos con el CSV real
(ver ADR 0003). Solo usa la biblioteca estándar.
"""
import argparse
import csv
import json
import re
import sys
import unicodedata
from datetime import date


def slug(text: str) -> str:
    text = unicodedata.normalize("NFD", text.lower())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def tidy(text: str) -> str:
    text = re.sub(r"\s+", " ", (text or "").strip())
    return text[:1].upper() + text[1:].lower() if text.isupper() else text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("csv_path")
    parser.add_argument("json_path")
    parser.add_argument("--generic-col", default="Principio Activo")
    parser.add_argument("--brand-col", default="Nombre Comercial")
    parser.add_argument("--strength-col", default="Potencia")
    parser.add_argument("--form-col", default="Forma Farmaceutica")
    parser.add_argument("--delimiter", default=";")
    args = parser.parse_args()

    groups: dict[str, dict] = {}
    with open(args.csv_path, newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle, delimiter=args.delimiter)
        missing = [c for c in (args.generic_col, args.brand_col) if c not in (reader.fieldnames or [])]
        if missing:
            print(f"Faltan columnas {missing}. Columnas disponibles: {reader.fieldnames}", file=sys.stderr)
            return 1
        for row in reader:
            generic = tidy(row.get(args.generic_col, ""))
            if not generic:
                continue
            entry = groups.setdefault(slug(generic), {
                "id": slug(generic), "generic": generic, "brands": [], "strengths": [], "forms": [],
            })
            for key, column in (("brands", args.brand_col), ("strengths", args.strength_col), ("forms", args.form_col)):
                value = tidy(row.get(column, ""))
                if value and value not in entry[key]:
                    entry[key].append(value)

    output = {
        "version": f"anmat-{date.today().isoformat()}",
        "source": "ANMAT — listado de medicamentos (datos abiertos)",
        "medications": sorted(groups.values(), key=lambda m: m["id"]),
    }
    with open(args.json_path, "w", encoding="utf-8") as handle:
        json.dump(output, handle, ensure_ascii=False, indent=2)
    print(f"{len(groups)} medicamentos escritos en {args.json_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
