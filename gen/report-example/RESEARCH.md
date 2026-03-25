# Research: Preset Settings Storage in DB

**Preset:** `KOD_PRESET = 2000493109`  
**Date:** 2026-03-25  

## Task

**Goal:** understand how report preset settings are physically stored in the Oracle DB so we can build a solution that extracts them into a convenient JSON with a human-readable structure.

**Approach:**
1. Take a known preset (`KOD_PRESET = 2000493109`) whose UI settings and resulting report output we already have (see `settings-info/` and `result/report.txt`).
2. Query every related table referenced in `RR_PRESET_REFERENCE.md` for that preset.
3. Map each DB row back to the corresponding UI setting to confirm correctness.
4. Document the data model, patterns, and ready-to-use SQL queries for future extraction tooling.

**Input artifacts:**
- `gen/RR_PRESET_REFERENCE.md` — schema documentation (table structures, FKs, sample data)
- `gen/report-example/settings-info/*.md` — UI settings captured from the application
- `gen/report-example/result/report.txt` — actual report output generated with this preset

---

## 1. Executive Summary

All report settings for a given preset are stored **almost entirely** in a single table — `ASUSE.RR_PRESETOPTION`. The preset header lives in `ASUSE.RR_PRESET`, and option definitions (metadata/names) are in `ASUSE.RK_PRESETSUBJOPTION`.

For the tested preset (2000493109), the following auxiliary tables contained **zero rows**:
- `RR_GEN_PRESET_COLS` — no per-preset column overrides
- `RR_GEN_KODES` — no denormalized grouping codes
- `RR_PRESETWND` / `RR_PRESETWNDSETUP` — no window setup
- `RR_PRESETENTITY` — no entity links
- `RR_PRESET_COMP` — not a composite preset
- `RR_PRESET_COLUMNS` — no serialized grid state

**Conclusion:** to extract a full preset config, you need only **2 tables** (+ 1 for option metadata):

| Table | Purpose | Rows for this preset |
|-------|---------|---------------------|
| `RR_PRESET` | Header (name, subject, modified by/at) | 1 |
| `RR_PRESETOPTION` | All option key-value pairs | **64** |
| `RK_PRESETSUBJOPTION` | Option definitions (INTNAME, NAME, type) | joined |

---

## 2. Preset Header

```sql
SELECT p.*, s.NAME AS SUBJ_NAME, s.INTNAME AS SUBJ_INTNAME, s.TYPE_POTR
FROM ASUSE.RR_PRESET p
JOIN ASUSE.RR_PRESETSUBJECT s ON s.KOD_PSUBJ = p.KOD_PSUBJ
WHERE p.KOD_PRESET = :kod_preset;
```

| Field | Value |
|-------|-------|
| KOD_PRESET | 2000493109 |
| KOD_PSUBJ | 2 |
| NAME | bav-test-2 |
| Subject | Оборотная ведомость (genz) |
| TYPE_POTR | 1 (промышленные потребители) |
| PR_PROTECTED | 1 |
| TMP | 0 |
| TYPE_APP | 1 |

### Subject → Option definition linkage

The preset has `KOD_PSUBJ = 2` ("Оборотная ведомость", INTNAME = `genz`), but all option definitions (`RK_PRESETSUBJOPTION`) are registered under `KOD_PSUBJ = 6` ("старый класс Генератор", INTNAME = `clsFormGenOld`). This means the "Оборотная ведомость" subject inherits/shares option definitions from the legacy generator class. When joining, use `KOD_POPTION` directly — do **not** filter by `KOD_PSUBJ`.

---

## 3. The Master Query

This single query retrieves the full settings payload:

```sql
SELECT
    po.KOD_POPTION,
    so.INTNAME          AS OPT_INTNAME,
    so.NAME             AS OPT_NAME,
    so.KOD_OPTION_TYPE,
    ot.NAME             AS OPTION_TYPE_NAME,
    po.ORDNUM,
    po.VAL_N,
    po.VAL_S,
    po.VAL_D,
    po.DT,
    po.OPER,
    po.VAL_N1,
    po.VAL_S1,
    po.VAL_D1,
    po.OPERNOT,
    po.OPEROR,
    po.VAL_SL,
    po.NUM
FROM ASUSE.RR_PRESETOPTION po
JOIN ASUSE.RK_PRESETSUBJOPTION so ON so.KOD_POPTION = po.KOD_POPTION
LEFT JOIN ASUSE.RK_OPTION_TYPE ot ON ot.KOD_OPTION_TYPE = so.KOD_OPTION_TYPE
WHERE po.KOD_PRESET = :kod_preset
ORDER BY so.KOD_OPTION_TYPE NULLS LAST, so.INTNAME, po.ORDNUM;
```

Returns **64 rows** for `KOD_PRESET = 2000493109`.

---

## 4. Option Data Model

Each row in `RR_PRESETOPTION` represents a single value for an option. Multi-value options (lists) use **multiple rows** with the same `KOD_POPTION` but different `ORDNUM`.

### Value columns

| Column | Purpose | Examples |
|--------|---------|---------|
| `VAL_N` | Numeric value | Numeric code, 1/0 flag, UM period (2021.02) |
| `VAL_S` | String value | Human-readable label, internal column name |
| `VAL_D` | Date value | Start/end dates |
| `ORDNUM` | Sequence number within multi-value option | 1, 2, 3... |
| `DT` | Data type hint on the row | 1 = numeric, 3 = date, 9 = reference |
| `OPER` | Comparison operator (for conditions) | `>`, `<`, `=` |
| `OPERNOT` | NOT flag (0/1) | 1 = negate the operator |
| `OPEROR` | OR flag (0/1) | 0 = AND with previous condition |

### Option types (KOD_OPTION_TYPE)

| KOD_OPTION_TYPE | NAME | Used for |
|-----------------|------|----------|
| 200 | Фильтры по деньгам | Voltage levels, realization types |
| 500 | Условия на значения выводимых строчек | Row-level conditions (charges > X) |
| 800 | Тип объектов для которых выбираются коды (везде) | Contract codes filter |
| 1120 | Фильтр договора | Active/archive contract filter |
| NULL | *(generic options)* | Columns, periods, display flags, etc. |

---

## 5. Complete Option-to-UI Mapping

Below is the full mapping of every option from the DB to the UI settings tabs, verified against the example report output.

### 5.1 Period Settings

| INTNAME | KOD_POPTION | OPT_NAME | Value | UI Meaning |
|---------|-------------|----------|-------|------------|
| `period` | 33 | (2- в датах;1- в умах) | VAL_N=1 | Period format: **in УМ (year.month)** |
| `is_DefDat` | 86 | Период - тек. отч. период | VAL_N=0 | Use specific dates (not default) |
| `ymbegin` | 25 | УМ начала периода | VAL_N=**2021.02** | Start: February 2021 |
| `ymend` | 26 | УМ конца периода | VAL_N=**2021.03** | End: March 2021 |
| `datbegin` | 20 | Дата начала периода | VAL_D=**2021-02-01** | Exact start date |
| `datend` | 21 | Дата конца периода | VAL_D=**2021-04-01** | Exact end date (exclusive) |
| `is_other_date` | 238 | Как запоминаем даты | VAL_N=2 | Date storage mode |

**UI match:** "Период: Февраль 2021 — Март 2021" ✅

### 5.2 Display Options (Checkboxes)

| INTNAME | KOD_POPTION | OPT_NAME | VAL_N | UI Meaning |
|---------|-------------|----------|-------|------------|
| `w_kred_part` | 82 | Делить на деб/кред | 1 | ✅ деб. и кред. части |
| `w_kred_part_1` | 83 | Кред часть в 1 колонке | 1 | ✅ кред. часть в одной колонке |
| `opl20` | 185 | Учит. авансы в опл. осн. реал. | 1 | ✅ Учит. авансы в опл осн. реал. |

### 5.3 Print Columns (Column Visibility)

| INTNAME | KOD_POPTION | OPT_NAME | VAL_N | UI Section |
|---------|-------------|----------|-------|------------|
| `c_nach_zad` | 45 | Выводить общую нач зад | 1 | **Начальная зад.** — enabled |
| `c_nachdeb` | 113 | Деб. задолженность на начало | 1 | Начальная зад. → debit part |
| `c_nachkred` | 93 | Кред. задолженность на начало | 1 | Начальная зад. → credit part |
| `c_nachisl` | 46 | Выводить начисления | 1 | **Начисления, р.** — enabled |
| `c_nachisl_nds` | 564 | Начисления — налоги | 1 | Начисления → НДС |
| `c_nachisl_cust` | 446 | Начисления по нат показ | 1 | Начисления → нат.показатели |
| `c_opl` | 48 | Выводить оплату | 1 | **Оплата, р.** — enabled |
| `c_opldeb` | 114 | Дебитовая часть оплаты | 1 | Оплата → debit part |
| `c_oplkred` | 96 | Кредитовая часть оплаты | 1 | Оплата → credit part |
| `c_zadol` | 52 | Выводить конечную задолженность | 1 | **Задолженность, р.** — enabled |
| `c_zadoldeb` | 115 | Конечная дебитовая задолженность | 1 | Задолженность → debit part |
| `c_zadolkred` | 91 | Конечная кредитовая задолженность | 1 | Задолженность → credit part |

### 5.4 Column Grouping (Vertical grouping of columns)

| INTNAME | KOD_POPTION | ORDNUM | VAL_S | UI Meaning |
|---------|-------------|--------|-------|------------|
| `col_gr` | 135 | 6 | `gv_rper_zaddoc` | Group by **document periods** |
| `col_gr` | 135 | 7 | `c_edizm` | Group by **natural indicators** |
| `col_gr` | 135 | 8 | `vid_t` | Group by **product types** |
| `c_group_col_nachisl` | 117 | 5 | `vid_t` | Charges columns → by product types |
| `c_group_col_nachisl_cust` | 447 | 4 | `c_edizm` | Charges columns → by nat. indicators |
| `c_group_col_zadol` | 119 | 1 | `gv_rper_zaddoc` | Debt columns → by document periods |

**UI match:** "Колонки группируются по периодам возникновения задолженности, натуральным показателям, видам товара." ✅

### 5.5 Document Period Settings

| INTNAME | KOD_POPTION | ORDNUM | VAL_N | UI Meaning |
|---------|-------------|--------|-------|------------|
| `in_zbygod_doc` | 98 | 1 | 1 | **Плат.** (payment documents only) |
| `in_gv_rper_inccurrym_zad` | 405 | 1 | 1 | ✅ Include selected period |
| `in_gv_rper_typecurr_zad` | 408 | 1 | 1 | Current year breakdown: **by months** |
| `in_gv_rper_zad_ym` | 404 | 1 | **2** | Prior period: 2 months |
| `in_gv_rper_zad_ym` | 404 | 2 | **6** | Prior period: 6 months |

**UI match:** "Относительные периоды, текущий год по месяцам, предш. периоды: 2 мес., 6 мес." ✅

### 5.6 Filters (KOD_OPTION_TYPE = 200, 800, 1120)

#### Voltage Levels (`ff_volt`, KOD_POPTION=160) — 6 values

| ORDNUM | VAL_N | VAL_S |
|--------|-------|-------|
| 5 | 3 | ВН  высокое |
| 6 | 6 | ВН.  ВН с шин станций |
| 7 | 5 | ГН  генерация |
| 8 | 1 | НН  низкое |
| 9 | 9 | НН.  НН с шин станций |
| 10 | 2 | СН1  среднее 1 |

#### Realization Types (`vid_real`, KOD_POPTION=27) — 3 values

| ORDNUM | VAL_N | VAL_S |
|--------|-------|-------|
| 11 | 2 | Основная реализация |
| 12 | 9 | Гос.пошлина |
| 13 | 8 | Доходы прошлых периодов |

#### Contract Codes (`f_kod_dog`, KOD_POPTION=30) — 3 values

| ORDNUM | VAL_N (KOD_DOG) | VAL_S |
|--------|-----------------|-------|
| 2 | 959 | 0738 Э veXZrEaMER |
| 3 | 957 | 4528 Э sPPJRFOBOiIe |
| 4 | 790 | 0939 Э IprlZSPSXbtfPKQoAyPzPQwII |

#### Active/Archive Filter (`dd_arch`, KOD_POPTION=443)

| ORDNUM | VAL_N | VAL_S |
|--------|-------|-------|
| 1 | 0 | активные |

**UI match:** all filters match the report header and filters.md ✅

### 5.7 Natural Indicators (`sel_edizm`, KOD_POPTION=136) — 3 values

| ORDNUM | VAL_N | VAL_S |
|--------|-------|-------|
| 1 | 13 | тыс.кВтч в год |
| 2 | 14 | тыс.кВтч/МВА в год |
| 3 | 15 | тыс.кВтч/км в год |

**UI match:** natural-indicators.md ✅

### 5.8 Product/Charge Types (`sel_vidt`, KOD_POPTION=514) — 4 values

| ORDNUM | VAL_N | VAL_S |
|--------|-------|-------|
| 1 | -225 | электроэнергия населению по рег цене |
| 2 | -173 | потребленная электроэнергия по нерегулируемой |
| 3 | -46 | 452 Электроэнергия, приобретаемая Покупателем... |
| 4 | 8 | начисления за превышение расходов воды (тепл...) |

> **Note:** VAL_N=-46 maps to charge type ID 452 (the "452" is visible in VAL_S). The negative sign is an encoding convention in the system.

**UI match:** product-types.md ✅

### 5.9 Attributes / Props (`props`, KOD_POPTION=24) — 6 values

| ORDNUM | VAL_N | VAL_S | UI Meaning |
|--------|-------|-------|------------|
| 1 | 2433 | `c_lim_yrube` | Лимиты на год, руб. |
| 2 | 756 | `c_addr_p` | Адрес для переписки |
| 3 | 36 | `c_inn` | ИНН |
| 4 | 279 | `c_buh_fio` | ФИО бухгалтера |
| 5 | 276 | `c_dir_fio` | ФИО руководителя |
| 6 | 37 | `c_name` | Наименование абонента |

**UI match:** groupings-and-attrs.md → Атрибуты section ✅

### 5.10 Additional Conditions (KOD_OPTION_TYPE = 500)

| INTNAME | KOD_POPTION | OPER | VAL_N | OPERNOT | OPEROR | UI Meaning |
|---------|-------------|------|-------|---------|--------|------------|
| `rc_nachisl` | 219 | `>` | 1000 | 0 | 0 | Начислено за период > 1000 |
| `rc_opl` | 274 | `<` | 1000 | **1** | 0 | Оплачено за период **НЕ** < 1000 |

**Logic:** OPERNOT=1 negates the operator → "НЕ <" = "NOT less than"

**UI match:** additional-conditions.md ✅

### 5.11 Groupings

| INTNAME | KOD_POPTION | VAL_N | VAL_S | UI Meaning |
|---------|-------------|-------|-------|------------|
| `gr_ord2` | 396 | 414 | `grdd_code` | Grouping 2nd method: by contract numbers |
| `l_dogall` | 312 | 0 | — | Don't show "total by contract" row |
| `usl_obj` | 271 | 2 | — | Conditions target: contract level (2) |

> **Note:** The full grouping definitions (Method 1: Участки, Подгруппа потребления; Method 2: Номер договора, Категории потребителей, etc.) are likely resolved from the `gr_ord2` reference code (414 → `grdd_code`) by application logic or stored in other tables not directly linked to this preset. The DB stores only the grouping code reference, not the full grouping tree.

---

## 6. Option Inventory Summary

42 distinct options used, 64 total rows:

| Category | Options (INTNAME) | Row Count |
|----------|-------------------|-----------|
| **Period** | `period`, `is_DefDat`, `ymbegin`, `ymend`, `datbegin`, `datend`, `is_other_date` | 7 |
| **Display flags** | `w_kred_part`, `w_kred_part_1`, `opl20` | 3 |
| **Column visibility** | `c_nach_zad`, `c_nachdeb`, `c_nachkred`, `c_nachisl`, `c_nachisl_nds`, `c_nachisl_cust`, `c_opl`, `c_opldeb`, `c_oplkred`, `c_zadol`, `c_zadoldeb`, `c_zadolkred` | 12 |
| **Column grouping** | `col_gr`(×3), `c_group_col_nachisl`, `c_group_col_nachisl_cust`, `c_group_col_zadol` | 6 |
| **Filters** | `ff_volt`(×6), `vid_real`(×3), `f_kod_dog`(×3), `dd_arch` | 13 |
| **Natural indicators** | `sel_edizm`(×3) | 3 |
| **Product types** | `sel_vidt`(×4) | 4 |
| **Attributes** | `props`(×6) | 6 |
| **Conditions** | `rc_nachisl`, `rc_opl` | 2 |
| **Document periods** | `in_zbygod_doc`, `in_gv_rper_inccurrym_zad`, `in_gv_rper_typecurr_zad`, `in_gv_rper_zad_ym`(×2) | 5 |
| **Groupings** | `gr_ord2`, `l_dogall`, `usl_obj` | 3 |
| **Total** | **42 distinct options** | **64 rows** |

---

## 7. Data Patterns & Rules

### 7.1 Multi-value options
When `INTNAME` has multiple rows (same `KOD_POPTION`, different `ORDNUM`):
- **List items:** `ff_volt`, `vid_real`, `f_kod_dog`, `sel_edizm`, `sel_vidt`, `props`, `col_gr`, `in_gv_rper_zad_ym`
- `VAL_N` = code/ID, `VAL_S` = display label
- `ORDNUM` = position in the list

### 7.2 Boolean flags
When `VAL_N` = 1 or 0, it's a boolean flag:
- 1 = enabled/yes
- 0 = disabled/no

### 7.3 Conditions (KOD_OPTION_TYPE = 500)
Row-level filters use `OPER`, `OPERNOT`, `OPEROR`:
- `OPER`: comparison operator (`>`, `<`, `=`, `>=`, `<=`)
- `OPERNOT`: 1 = negate the condition (NOT)
- `OPEROR`: 1 = OR with previous condition (0 = AND)
- `VAL_N`: threshold value

### 7.4 DT column semantics
The `DT` column in `RR_PRESETOPTION`:
- 1 = numeric/generic value
- 3 = date value (VAL_D is populated)
- 9 = reference/code value

---

## 8. JSON Extraction Strategy

To build a human-readable JSON from a preset, the approach would be:

1. **Fetch header** from `RR_PRESET` + `RR_PRESETSUBJECT`
2. **Fetch all options** from `RR_PRESETOPTION` joined with `RK_PRESETSUBJOPTION`
3. **Group by INTNAME** — each unique `INTNAME` becomes a JSON key
4. **Single-value options** → scalar value (`VAL_N`, `VAL_S`, or `VAL_D` depending on DT)
5. **Multi-value options** → array of objects `[{val_n, val_s, ordnum}, ...]`
6. **Condition options** (type 500) → object with `{operator, value, not, or}`

### Proposed JSON structure

```json
{
  "preset": {
    "kod_preset": 2000493109,
    "name": "bav-test-2",
    "subject": { "kod_psubj": 2, "name": "Оборотная ведомость", "intname": "genz" }
  },
  "period": {
    "format": "ym",
    "ym_begin": 2021.02,
    "ym_end": 2021.03,
    "date_begin": "2021-02-01",
    "date_end": "2021-04-01"
  },
  "display": {
    "debit_credit_parts": true,
    "credit_in_one_column": true,
    "advances_in_payment": true
  },
  "columns": {
    "opening_balance": { "enabled": true, "by_product_types": true },
    "charges": { "enabled": true, "by_product_types": true, "natural_indicators": true, "vat": true },
    "payment": { "enabled": true, "debit_part": true, "credit_part": true },
    "debt": { "enabled": true, "by_document_periods": true, "debit_part": true, "credit_part": true }
  },
  "column_groupings": ["gv_rper_zaddoc", "c_edizm", "vid_t"],
  "filters": {
    "voltage_levels": [
      { "id": 3, "name": "ВН  высокое" },
      { "id": 6, "name": "ВН.  ВН с шин станций" }
    ],
    "realization_types": [
      { "id": 2, "name": "Основная реализация" }
    ],
    "contracts": [
      { "kod_dog": 959, "name": "0738 Э veXZrEaMER" }
    ],
    "active_archive": "активные"
  },
  "natural_indicators": [
    { "id": 13, "name": "тыс.кВтч в год" }
  ],
  "product_types": [
    { "id": -225, "name": "электроэнергия населению по рег цене" }
  ],
  "attributes": [
    { "id": 2433, "intname": "c_lim_yrube", "meaning": "Лимиты на год, руб." }
  ],
  "conditions": [
    { "field": "nachisl", "name": "Начислено за период", "operator": ">", "value": 1000, "not": false },
    { "field": "opl", "name": "Оплачено за период", "operator": "<", "value": 1000, "not": true }
  ],
  "document_periods": {
    "type": "relative",
    "include_current_period": true,
    "current_year_breakdown": "by_months",
    "prior_months": [2, 6]
  }
}
```

---

## 9. Auxiliary Tables — When They Matter

While empty for this preset, these tables may be relevant for other presets:

| Table | When populated |
|-------|---------------|
| `RR_GEN_PRESET_COLS` | When user customizes column titles, widths, colors per preset |
| `RR_GEN_KODES` | When report is generated — stores denormalized subscriber/contract data |
| `RR_PRESETWND` / `RR_PRESETWNDSETUP` | When UI window state is saved |
| `RR_PRESET_COLUMNS` | When serialized grid state (BLOB) is saved |
| `RR_PRESET_COMP` | For composite presets combining multiple simple presets |
| `RR_PRESETENTITY` | When preset is linked to specific entity elements |

---

## 10. Key Queries Reference

### Get preset header
```sql
SELECT p.KOD_PRESET, p.KOD_PSUBJ, p.NAME, p.TITLE, p.U_M, p.D_M,
       p.PR_PROTECTED, p.TMP, p.TYPE_APP, p.PR_DEFAULT,
       s.NAME AS SUBJ_NAME, s.INTNAME AS SUBJ_INTNAME, s.TYPE_POTR
FROM ASUSE.RR_PRESET p
JOIN ASUSE.RR_PRESETSUBJECT s ON s.KOD_PSUBJ = p.KOD_PSUBJ
WHERE p.KOD_PRESET = :kod_preset;
```

### Get all option values with definitions
```sql
SELECT
    so.INTNAME, so.NAME AS OPT_NAME, so.KOD_OPTION_TYPE,
    ot.NAME AS OPTION_TYPE_NAME, so.DT AS OPT_DT, so.FIELD,
    po.ORDNUM, po.VAL_N, po.VAL_S, po.VAL_D, po.DT,
    po.OPER, po.OPERNOT, po.OPEROR, po.VAL_N1, po.VAL_S1, po.VAL_D1
FROM ASUSE.RR_PRESETOPTION po
JOIN ASUSE.RK_PRESETSUBJOPTION so ON so.KOD_POPTION = po.KOD_POPTION
LEFT JOIN ASUSE.RK_OPTION_TYPE ot ON ot.KOD_OPTION_TYPE = so.KOD_OPTION_TYPE
WHERE po.KOD_PRESET = :kod_preset
ORDER BY so.INTNAME, po.ORDNUM;
```

### Get option summary (distinct options with counts)
```sql
SELECT so.INTNAME, so.NAME, so.KOD_OPTION_TYPE,
       ot.NAME AS OPTION_TYPE_NAME, COUNT(*) AS VALUE_COUNT
FROM ASUSE.RR_PRESETOPTION po
JOIN ASUSE.RK_PRESETSUBJOPTION so ON so.KOD_POPTION = po.KOD_POPTION
LEFT JOIN ASUSE.RK_OPTION_TYPE ot ON ot.KOD_OPTION_TYPE = so.KOD_OPTION_TYPE
WHERE po.KOD_PRESET = :kod_preset
GROUP BY so.INTNAME, so.NAME, so.KOD_OPTION_TYPE, ot.NAME
ORDER BY so.KOD_OPTION_TYPE NULLS LAST, so.INTNAME;
```

### Check auxiliary tables (run for completeness)
```sql
SELECT 'RR_GEN_PRESET_COLS' AS TBL, COUNT(*) AS CNT FROM ASUSE.RR_GEN_PRESET_COLS WHERE KOD_PRESET = :kod_preset
UNION ALL
SELECT 'RR_GEN_KODES', COUNT(*) FROM ASUSE.RR_GEN_KODES WHERE KOD_PRESET = :kod_preset
UNION ALL
SELECT 'RR_PRESETWND', COUNT(*) FROM ASUSE.RR_PRESETWND WHERE KOD_PRESET = :kod_preset
UNION ALL
SELECT 'RR_PRESETENTITY', COUNT(*) FROM ASUSE.RR_PRESETENTITY WHERE KOD_PRESET = :kod_preset
UNION ALL
SELECT 'RR_PRESET_COMP', COUNT(*) FROM ASUSE.RR_PRESET_COMP WHERE KOD_PRESET_SIMPLE = :kod_preset OR KOD_PRESET_COMP = :kod_preset
UNION ALL
SELECT 'RR_PRESET_COLUMNS', COUNT(*) FROM ASUSE.RR_PRESET_COLUMNS WHERE KOD_PRESET = :kod_preset;
```
