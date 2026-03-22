# Smart Brewery — domain logic (EN dev.to series)

English article series focused on **brewing process semantics**, **functional block elements (FBEs)**, **PON rules R_01–R_12**, and **standards-informed guardrails** in the TEC0301 Smart Brewery digital twin. Drafts are **narrative-led**: one continuous **story spine** (below) carries the reader across Parts 2–10; facts, code, and citations live in an **Evidence locker** under each chapter so rigor is not traded away for prose.

It complements the main **PON + Smart Brewery** track ([`docs/devto_serie_pon_smart_brewery.md`](../../../devto_serie_pon_smart_brewery.md)), especially [Part 5 — digital twin as a PON lab](../05_smart_brewery_digital_twin_pon_lab.md), which stays architecture-first; here we go deep on **what** each unit models and **why** thresholds and interlocks exist—often **as the twin reacts during a single batch day**.

## Canonical repo sources

| Topic | Location |
|--------|----------|
| Facts, units, rules table | [`docs/smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md) |
| ML × TimescaleDB | [`docs/ml-smart-brewery-data.md`](../../../ml-smart-brewery-data.md) |
| Core facts & boot | [`lib/tec0301_pon/examples/smart_brewery.ex`](../../../../lib/tec0301_pon/examples/smart_brewery.ex) |
| Rule definitions | [`lib/tec0301_pon/examples/smart_brewery_regras.ex`](../../../../lib/tec0301_pon/examples/smart_brewery_regras.ex) |
| Simulation & KPIs | [`apps/simulacoes_visuais/lib/simulacoes_visuais/smart_brewery/`](../../../../apps/simulacoes_visuais/lib/simulacoes_visuais/smart_brewery/) |
| PON + platform bibliography | [`docs/devto/BIBLIOGRAPHY_PON_SERIES.md`](../../BIBLIOGRAPHY_PON_SERIES.md) |
| **Domain bibliography (this series)** | [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md) |

## Publication checklist (dev.to)

- Use **Part X of 10** in the excerpt or opening paragraph.
- **Series slug:** `smart-brewery-domain` (or a single tag you prefer; keep it consistent).
- **Suggested tags:** `brewing`, `digitaltwins`, `industry40`, `elixir`, `iot`, plus any from each draft’s front matter.
- Replace *TBD* in the table below with public URLs when posts go live.

## Series index

| Part | Story beat (H1 in draft) | Post on dev.to | Repo draft |
|-----:|--------------------------|----------------|------------|
| 1 | Prologue — why this twin maps a brewery line | *TBD* | [01_why_this_twin_maps_a_brewery_line.md](01_why_this_twin_maps_a_brewery_line.md) |
| 2 | The mill talks back (FBE_01, R_04) | *TBD* | [02_fbe01_mill_grist_and_mechanical_guardrails.md](02_fbe01_mill_grist_and_mechanical_guardrails.md) |
| 3 | Mash tun — keeping Batch #47 in the band (R_05) | *TBD* | [03_fbe02_mash_tun_control_and_recipe_band.md](03_fbe02_mash_tun_control_and_recipe_band.md) |
| 4 | When the lauter bed fights back (R_01, R_09) | *TBD* | [04_fbe03_lauter_filtration_physics_and_r01.md](04_fbe03_lauter_filtration_physics_and_r01.md) |
| 5 | Boil — foam, steam, R_06 | *TBD* | [05_fbe04_boil_kettle_safety_and_r06.md](05_fbe04_boil_kettle_safety_and_r06.md) |
| 6 | Cooling coupling — wort meets glycol (R_07, R_10) | *TBD* | [06_fbe05_heat_exchanger_coupling_and_r07_r10.md](06_fbe05_heat_exchanger_coupling_and_r07_r10.md) |
| 7 | Fermentation holds — the grid knocks (R_03, R_08) | *TBD* | [07_fbe06_fbe07_fermentation_phases_and_grid_coupling.md](07_fbe06_fbe07_fermentation_phases_and_grid_coupling.md) |
| 8 | Line speed — the robot in the way (R_02, R_11) | *TBD* | [08_fbe08_packaging_line_interlocks_and_fbe10_amr.md](08_fbe08_packaging_line_interlocks_and_fbe10_amr.md) |
| 9 | Interlude — while the tun sleeps (CIP, FBE_09) | *TBD* | [09_fbe09_cip_conductivity_and_process_hygiene.md](09_fbe09_cip_conductivity_and_process_hygiene.md) |
| 10 | Control-room debrief — OEE, anomalies, ML | *TBD* | [10_cross_cutting_oee_anomalies_rule_sequences_and_ml.md](10_cross_cutting_oee_anomalies_rule_sequences_and_ml.md) |

## Series spine (story contract)

Use this **fictional but plausible** thread across Parts 2–10 so each post opens with continuity:

- **Batch #47**, a weekday brewhouse run: grain in, wort out, cooling, fermentation holds, packaging later the same long shift where the narrative needs it.
- **Mara** — shift operator (optional named anchor); the **digital twin** is the silent co-protagonist: same facts and rules as the code, described as what “lights up” on the board.
- **Part 1** sets expectations: pedagogical twin, not certified equipment or HACCP sign-off.
- **Part 9** is a deliberate **interlude** (CIP / between-operations hygiene) so time can slide to “while fermenters hold” without pretending strict clock continuity everywhere.
- **Part 10** closes with a **control-room debrief**: OEE, EMA anomalies, `rule_events` as the day’s paper trail, then ML.

You may switch to **impersonal voice** (“the SCADA tile flashes”) if you prefer less character; keep **one paragraph of bridge** from the previous part’s closing beat.

## Storytelling guidelines (per article)

Each draft follows **five blocks** (headings can vary slightly per post):

1. **The hook (scene)** — 2–4 short paragraphs: sound, trend, alarm, or a calm moment before a decision; end with a **bridge** from Part *n*−1 where *n* > 1.
2. **What the floor demands** — tension or goal in operator language (what goes wrong if nobody acts).
3. **What the twin does** — PON rule / FBE behaviour as the **consequence** of the scene; then paste the **`defrule` or action** excerpt.
4. **Evidence locker (twin sheet)** — compact **facts table** (from [`smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md)), numeric thresholds labelled **twin parameters** (not plant-certified limits), pointers to simulation modules if any.
5. **Further reading** — For the standards-minded reader: 4–8 entries from [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md) plus post-specific papers; optional one-line intro (“Beyond the story…”).

**Citations:** weave light references in §2–3; place dense normative detail in §4–5. **Legal / normative disclaimer:** NR-13, ISO zones, etc. are **illustrative context** for the lab twin unless you explicitly document validation—say so in Part 1 and repeat briefly where rules touch safety.

**Front matter:** keep `title`, `tags`, `series`; you may tune **`description`** to a story hook (e.g. “When the lauter bed fights back…”).

### Length target (reading time)

Each numbered draft (`01_` … `10_`) should land at **≥2000 words** so a technical reader gets roughly **≥10 minutes** at ~**200 words per minute** (tables and code slow people down; this is a conservative floor). For extra margin toward 10 minutes at faster reading speeds, aim for **~2200–2400 words**.

**Quick check before publishing:**

```bash
wc -w docs/devto/en/smart_brewery_domain_logic/0*.md docs/devto/en/smart_brewery_domain_logic/10_*.md
```

Optional automation: [`scripts/check_smart_brewery_domain_wordcount.sh`](../../../../scripts/check_smart_brewery_domain_wordcount.sh) (fails if any series article is below 2000 words).

## ISO 23247 mapping (internal)

The Elixir module `SimulacoesVisuais.SmartBrewery.ISO23247` documents a component mapping to ISO 23247. A prose version (PT) lives in [`docs/artigos/12_mapeamento_iso_23247.md`](../../../artigos/12_mapeamento_iso_23247.md); Part 1 of this series should link there and to `map_components/0`.

## Bibliography

- **Domain-specific:** [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md)
- **PON / Elixir / TSDB / ML lifecycle:** [`../../BIBLIOGRAPHY_PON_SERIES.md`](../../BIBLIOGRAPHY_PON_SERIES.md)
