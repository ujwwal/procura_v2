from pathlib import Path
import re

b2_text = Path(r"C:\Users\user\AppData\Local\Temp\procura-batch2.sql").read_text(encoding="utf-8")
r_lines = {}
for lid, rid, lno, cat_id, sid, desc, qty, unit, price, cat in re.findall(
    r"\((\d+),\s*(\d+),\s*(\d+),\s*([^,]+),\s*([^,]+),\s*'([^']*)',\s*([\d\.]+),\s*'([^']*)',\s*([\d\.]+),\s*'([^']*)'\)",
    b2_text,
):
    r_lines[int(lid)] = {
        "requisition_id": int(rid),
        "supplier_id": None if sid == "NULL" else int(sid),
        "unit": unit,
    }

b3_text = Path(r"C:\Users\user\AppData\Local\Temp\procura-batch3.sql").read_text(encoding="utf-8")
pos = {}
for pid, pno, title, sid, amt, status, odate, cat, rid, cid, curr in re.findall(
    r"\((\d+),\s*'([^']*)',\s*'([^']*)',\s*([^,]+),\s*([\d\.]+),\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*([^,]+),\s*([^,]+),\s*'([A-Z]{3})'\)",
    b3_text,
):
    pos[int(pid)] = {
        "supplier_id": None if sid == "NULL" else int(sid),
        "requisition_id": None if rid == "NULL" else int(rid),
    }

for lid, pid, lno, rlid, desc, qty, unit, price, cat in re.findall(
    r"\((\d+),\s*(\d+),\s*(\d+),\s*([^,]+),\s*'([^']*)',\s*([\d\.]+),\s*'([^']*)',\s*([\d\.]+),\s*'([^']*)'\)",
    b3_text,
):
    if rlid != "NULL":
        rl = r_lines[int(rlid)]
        po = pos[int(pid)]
        if po["requisition_id"] != rl["requisition_id"]:
            print(f"PO req mismatch on line {lid}: po.req={po['requisition_id']} vs rl.req={rl['requisition_id']}")
        if rl["supplier_id"] is not None and po["supplier_id"] != rl["supplier_id"]:
            print(f"PO sup mismatch on line {lid}: po.sup={po['supplier_id']} vs rl.sup={rl['supplier_id']}")
        if unit != rl["unit"]:
            print(f"PO unit mismatch on line {lid}: po.unit={unit} vs rl.unit={rl['unit']}")
