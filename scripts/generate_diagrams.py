#!/usr/bin/env python3
"""Render diagrams/architecture.png, er_diagram.png and star_schema.png with Graphviz (reads foreign keys from the live warehouse)."""
import os, subprocess
from db import connect, ROOT

OUT = os.path.join(ROOT, "diagrams")
FILL = {"fact": "#FCE8D5", "dim": "#D9EEF2", "bridge": "#EADCF4"}


def dot(name, src):
    p = os.path.join(OUT, name + ".dot")
    open(p, "w").write(src)
    subprocess.check_call(["dot", "-Tpng", "-Gdpi=140", p, "-o", os.path.join(OUT, name + ".png")])
    subprocess.check_call(["dot", "-Tsvg", p, "-o", os.path.join(OUT, name + ".svg")])
    os.remove(p)


def kind(t):
    return "dim" if t.startswith("dim_") else ("bridge" if t.startswith("bridge") else "fact")


def main():
    os.makedirs(OUT, exist_ok=True)
    cur = connect().cursor()
    cur.execute("""SELECT tc.table_name, kcu.column_name, ccu.table_name, ccu.column_name FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'dw' ORDER BY 1, 2""")
    fks = cur.fetchall()
    cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='dw' ORDER BY 1")
    tables = [r[0] for r in cur.fetchall()]

    # ---------------- ER diagram: every table, every FK (date role-playing edges collapsed with a count label)
    g = ['digraph ER {', 'rankdir=LR; fontname="Helvetica"; node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=11]; edge [color="#7B8794", arrowsize=0.6];',
         'labelloc=t; label="ChainSight warehouse (dw schema): entity-relationship diagram. Orange = fact, blue = dimension, purple = bridge"; fontsize=16;']
    for t in tables:
        g.append(f'"{t}" [fillcolor="{FILL[kind(t)]}"];')
    agg = {}
    for t, c, rt, rc in fks:
        agg.setdefault((t, rt), []).append(c)
    for (t, rt), cs in agg.items():
        lab = cs[0] if len(cs) == 1 else f"{len(cs)} date roles" if rt == "dim_date" else f"{len(cs)} keys"
        g.append(f'"{t}" -> "{rt}" [label="{lab}", fontsize=8, fontname="Helvetica"];')
    g.append("}")
    dot("er_diagram", "\n".join(g))

    # ---------------- Star schema overview: constellation with conformed dimensions highlighted
    conformed = {"dim_date", "dim_product", "dim_warehouse", "dim_plant", "dim_customer", "dim_material", "dim_supplier", "dim_machine"}
    g = ['graph STAR {', 'layout=neato; overlap=false; splines=true; sep="+18"; fontname="Helvetica"; node [fontname="Helvetica", fontsize=11, style="filled"]; edge [color="#B0B7BF"];',
         'labelloc=t; label="ChainSight star-schema constellation: facts (orange boxes) share conformed dimensions (blue ellipses)"; fontsize=16;']
    for t in tables:
        if kind(t) == "fact":
            g.append(f'"{t}" [shape=box, fillcolor="{FILL["fact"]}"];')
        else:
            g.append(f'"{t}" [shape=ellipse, fillcolor="{FILL[kind(t)]}"{", penwidth=2.5, color=\"#0F4C5C\"" if t in conformed else ""}];')
    for (t, rt), cs in agg.items():
        if kind(t) in ("fact", "bridge"):
            g.append(f'"{t}" -- "{rt}";')
    g.append("}")
    dot("star_schema", "\n".join(g))

    # ---------------- Architecture
    arch = '''digraph ARCH { rankdir=LR; fontname="Helvetica"; node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=12, fillcolor="#FFFFFF"]; edge [color="#52606D"];
 labelloc=t; label="ChainSight data architecture"; fontsize=16;
 gen [label="Python generator\\n(seeded simulation)\\n24 CSV files", fillcolor="#EDEFF2"];
 subgraph cluster_pg { label="PostgreSQL"; style="rounded,dashed"; color="#7B8794";
  raw [label="raw\\nall TEXT, dirty\\nnever edited", fillcolor="#FDE2E2"];
  stg [label="staging\\ntyped, trimmed, de-duplicated\\nrejects logged", fillcolor="#FEF3C7"];
  tr [label="transform\\n(status repair, customer merge,\\nbusiness rules)", fillcolor="#FEF3C7"];
  dw [label="dw\\nstar schema\\n15 dims + bridge + 13 facts", fillcolor="#D9EEF2"];
  an [label="analytics\\nviews + 81 queries", fillcolor="#E0F2E9"];
  dq [label="dq\\n150+ checks", fillcolor="#EADCF4"]; }
 pbi [label="Power BI\\nsemantic model + DAX", fillcolor="#FCE8D5"];
 rep [label="12 report pages\\ncontrol tower", fillcolor="#FCE8D5"];
 mgmt [label="Insights +\\nmanagement report", fillcolor="#EDEFF2"];
 gen -> raw [label="COPY"]; raw -> stg -> tr -> dw; dw -> an; dw -> dq [style=dashed]; stg -> dq [style=dashed];
 dw -> pbi [label="Import"]; an -> pbi; pbi -> rep; an -> mgmt; }'''
    dot("architecture", arch)
    print("diagrams written:", sorted(f for f in os.listdir(OUT)))


if __name__ == "__main__":
    main()
