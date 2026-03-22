# Bibliography — Smart Brewery domain logic series (EN drafts)

**Note:** These citations anchor the **technical layer** of the [storytelling-led domain series](./README.md). Use them in each article’s *Evidence locker* and *Further reading* sections after the narrative hook.

Normalized references for [`docs/devto/en/smart_brewery_domain_logic/`](./). Use alongside the platform bibliography [`docs/devto/BIBLIOGRAPHY_PON_SERIES.md`](../BIBLIOGRAPHY_PON_SERIES.md). Verify standard editions and URLs before publishing.

## Digital twins and manufacturing reference models

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Grieves, M. | 2014 | *Digital Twin: Manufacturing Excellence Through Virtual Factory Replication* | Widely cited white paper on twin vocabulary (search institutional / publisher PDFs). |
| ISO | 2021 | **ISO 23247** — *Automation systems and integration — Digital twin framework for manufacturing* | [ISO catalogue](https://www.iso.org/standard/75071.html) — framework blocks mapped in `SimulacoesVisuais.SmartBrewery.ISO23247` and [`docs/artigos/12_mapeamento_iso_23247.md`](../../../artigos/12_mapeamento_iso_23247.md). |
| ISA | — | **ISA-95** — Enterprise-control system integration (Part 1 overview of levels) | [isa.org](https://www.isa.org/standards-and-publications/isa-standards) — contextualize MES/SCADA vs enterprise; twin in repo is a pedagogical slice. |
| ISA | — | **ISA-88** — Batch control (models, recipes, phases) | [isa.org](https://www.isa.org/standards-and-publications/isa-standards) — conceptual link for mash / unit operations sequencing (not a full S88 implementation in code). |

## Mechanical condition monitoring

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| ISO | — | **ISO 10816-3** — Mechanical vibration — Evaluation of machine vibration on non-rotating parts (industrial machines >300 kW) | [ISO catalogue](https://www.iso.org/standard/76135.html) — cited in Smart Brewery for **mill protection** (R_04); twin thresholds are illustrative. |

## Pressure equipment (Brazil — illustrative context for FBE_04)

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Brasil | — | **NR-13** — Caldeiras, vasos de pressão e tubulações (Ministério do Trabalho) | Official consolidated regulatory text (gov.br) — **R_06** names NR-13 as safety context; the simulation is **not** a certified pressure-system model. |

## Brewing science and unit operations

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Bamforth, C. W. | 2006 | *Brewing: New Technologies* | CRC Press / academic chapters on mash, wort, fermentation unit ops. |
| Lewis, M. J.; Young, T. W. | 2001 | *Brewing (2nd ed.)* | Springer — mash, lauter, boil, fermentation fundamentals. |
| Briggs, D. E.; Boulton, C. A.; Brookes, P. A.; Stevens, R. | 2004 | *Brewing Science and Practice* | Woodhead — equipment-oriented reference for mills, lauter tuns, kettles. |

## Cleaning in place (CIP) and hygiene

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Timperley, C.; et al. | — | EHEDG / industry guidelines on CIP validation and conductivity endpoints | Search [EHEDG](https://www.ehedg.org/) and hygiene engineering handbooks — use for **return conductivity** narrative (FBE_09). |
| *3-A SSI* | — | Sanitary standards (dairy/beverage equipment hygiene) | [3-a.org](https://www.3-a.org/) — optional context for CIP loops. |

## Overall Equipment Effectiveness (OEE)

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Nakajima, S. | 1988 | *TPM Development Program: Implementing Total Productive Maintenance* (OEE introduction) | Productivity Press — classic **Availability × Performance × Quality** formulation; mirrored in `SimulacoesVisuais.SmartBrewery.OEE` @moduledoc (“Nakajima mode”). |
| Productivity Development Team | 1999 | *OEE for Operators* | Productivity Press — shop-floor definitions. |

## Packaging, logistics, and mobile robots

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| *IFR / ISO* | — | **ISO 3691** series — Industrial trucks / driverless trucks (safety context for AGV/AMR) | [ISO catalogue](https://www.iso.org/) — high-level safety framing for **FBE_10** (twin uses simplified battery / route semantics). |

## Energy and demand response (FBE_11)

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Siano, P. | 2014 | *Demand response and smart grids—A survey* | *Renewable and Sustainable Energy Reviews* — peer-reviewed survey for peak-load shifting vocabulary. |

## Time-series ML, anomalies, and process mining (Part 10)

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| *Repository* | — | Walk-forward splits, pilot scripts | [`ml/smart_brewery/validation.py`](../../../../ml/smart_brewery/validation.py), [`ml/smart_brewery/README.md`](../../../../ml/smart_brewery/README.md) |
| van der Aalst, W. M. P.; et al. | — | Process mining (XES, discovery) | [pm4py](https://pm4py.fit.fraunhofer.de/) docs + *Process Mining* book — aligns with `rule_events` / PM4Py export. |

## This repository (domain tables and code)

| Topic | Path |
|--------|------|
| Facts, rules R_01–R_12 | [`docs/smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md) |
| ML data sources | [`docs/ml-smart-brewery-data.md`](../../../ml-smart-brewery-data.md) |
| PON lab overview | [`docs/devto/en/05_smart_brewery_digital_twin_pon_lab.md`](../05_smart_brewery_digital_twin_pon_lab.md) |

---

**Series index:** [`README.md`](README.md)
