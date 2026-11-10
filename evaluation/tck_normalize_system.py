#!/usr/bin/env python3
"""Experimental adapter: extract one UPPAAL system template for tck_product.

This is not a verified format converter. It is intentionally limited to the
simple Sys template used by the response case study: clock declarations,
guards, invariants, resets, and binary channel directions.
"""
import re
import sys
import xml.etree.ElementTree as ET


def main(src, dst, template_name="Sys"):
    root = ET.parse(src).getroot()
    matches = [t for t in root.findall("template")
               if t.findtext("name") == template_name]
    if len(matches) != 1:
        raise SystemExit(f"expected one template named {template_name}; got {len(matches)}")
    template = matches[0]
    decl = template.findtext("declaration") or ""
    m = re.search(r"\bclock\s+([^;]+);", decl)
    names = [] if not m else [x.strip() for x in m.group(1).split(",")]
    clock_map = {name: f"x{i}" for i, name in enumerate(names)}
    if m:
        decl = decl[:m.start()] + "clock " + ", ".join(clock_map.values()) + ";" + decl[m.end():]
        template.find("declaration").text = decl

    def rename(text):
        for old in sorted(clock_map, key=len, reverse=True):
            text = re.sub(rf"\b{re.escape(old)}\b", clock_map[old], text)
        return text

    template.find("name").text = "Property"
    for element in template.iter():
        if element is template.find("declaration") or not element.text:
            continue
        if element.tag == "label":
            element.text = rename(element.text)
            if element.get("kind") == "synchronisation":
                element.text = re.sub(r"[!?]$", "?", element.text.strip())
    out = ET.Element("nta")
    out.append(template)
    ET.ElementTree(out).write(dst, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: tck_normalize_system.py input.xml output.xml [template]")
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else "Sys")
