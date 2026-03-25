-- =============================================================================
-- ASUSE.PKG_RR_PRESET_JSON (package body)
-- Deploy after pkg_rr_preset_json_spec.sql.
-- =============================================================================

CREATE OR REPLACE PACKAGE BODY ASUSE.PKG_RR_PRESET_JSON AS

  TYPE t_path_set IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(20);
  g_path t_path_set;

  ------------------------------------------------------------------------------
  FUNCTION json_escape(p_str IN VARCHAR2) RETURN VARCHAR2 IS
    c     VARCHAR2(1 CHAR);
    o     VARCHAR2(32767);
    n     PLS_INTEGER;
    i     PLS_INTEGER;
    len   PLS_INTEGER;
    hex4  VARCHAR2(4);
  BEGIN
    IF p_str IS NULL THEN
      RETURN NULL;
    END IF;
    len := LENGTH(p_str);
    o   := '';
    FOR i IN 1 .. len LOOP
      c := SUBSTR(p_str, i, 1);
      IF c = '\' THEN
        o := o || '\\';
      ELSIF c = '"' THEN
        o := o || '\"';
      ELSIF c = CHR(8) THEN
        o := o || '\b';
      ELSIF c = CHR(9) THEN
        o := o || '\t';
      ELSIF c = CHR(10) THEN
        o := o || '\n';
      ELSIF c = CHR(12) THEN
        o := o || '\f';
      ELSIF c = CHR(13) THEN
        o := o || '\r';
      ELSE
        n := ASCII(c);
        IF n BETWEEN 1 AND 31 THEN
          hex4 := LPAD(TO_CHAR(n, 'FMXX'), 4, '0');
          o := o || '\u' || hex4;
        ELSE
          o := o || c;
        END IF;
      END IF;
    END LOOP;
    RETURN o;
  END json_escape;

  ------------------------------------------------------------------------------
  PROCEDURE append_raw(p_clob IN OUT NOCOPY CLOB, p_chunk IN VARCHAR2) IS
  BEGIN
    IF p_chunk IS NOT NULL AND LENGTH(p_chunk) > 0 THEN
      DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(p_chunk), p_chunk);
    END IF;
  END append_raw;

  ------------------------------------------------------------------------------
  PROCEDURE sep(p_clob IN OUT NOCOPY CLOB, p_first IN OUT BOOLEAN) IS
  BEGIN
    IF NOT p_first THEN
      append_raw(p_clob, ',');
    END IF;
    p_first := FALSE;
  END sep;

  ------------------------------------------------------------------------------
  PROCEDURE append_kv_str(
    p_clob  IN OUT NOCOPY CLOB,
    p_first IN OUT BOOLEAN,
    p_key   IN VARCHAR2,
    p_val   IN VARCHAR2
  ) IS
  BEGIN
    sep(p_clob, p_first);
    append_raw(p_clob, '"' || p_key || '":');
    IF p_val IS NULL THEN
      append_raw(p_clob, 'null');
    ELSE
      append_raw(p_clob, '"' || json_escape(p_val) || '"');
    END IF;
  END append_kv_str;

  ------------------------------------------------------------------------------
  PROCEDURE append_kv_num(
    p_clob  IN OUT NOCOPY CLOB,
    p_first IN OUT BOOLEAN,
    p_key   IN VARCHAR2,
    p_val   IN NUMBER
  ) IS
  BEGIN
    sep(p_clob, p_first);
    append_raw(p_clob, '"' || p_key || '":');
    IF p_val IS NULL THEN
      append_raw(p_clob, 'null');
    ELSE
      append_raw(p_clob, TRIM(TO_CHAR(p_val, 'TM9', 'NLS_NUMERIC_CHARACTERS=''. ''')));
    END IF;
  END append_kv_num;

  ------------------------------------------------------------------------------
  PROCEDURE append_kv_date(
    p_clob  IN OUT NOCOPY CLOB,
    p_first IN OUT BOOLEAN,
    p_key   IN VARCHAR2,
    p_val   IN DATE
  ) IS
  BEGIN
    sep(p_clob, p_first);
    append_raw(p_clob, '"' || p_key || '":');
    IF p_val IS NULL THEN
      append_raw(p_clob, 'null');
    ELSE
      append_raw(p_clob, '"' || json_escape(TO_CHAR(p_val, 'YYYY-MM-DD"T"HH24:MI:SS')) || '"');
    END IF;
  END append_kv_date;

  ------------------------------------------------------------------------------
  PROCEDURE append_clob_fragment(
    p_clob  IN OUT NOCOPY CLOB,
    p_first IN OUT BOOLEAN,
    p_key   IN VARCHAR2,
    p_json  IN CLOB
  ) IS
    amt    PLS_INTEGER := 32767;
    off    PLS_INTEGER := 1;
    buflen PLS_INTEGER;
    buf    VARCHAR2(32767);
    len    PLS_INTEGER;
  BEGIN
    sep(p_clob, p_first);
    append_raw(p_clob, '"' || p_key || '":');
    IF p_json IS NULL OR DBMS_LOB.GETLENGTH(p_json) = 0 THEN
      append_raw(p_clob, 'null');
      RETURN;
    END IF;
    len := DBMS_LOB.GETLENGTH(p_json);
    WHILE off <= len LOOP
      buflen := LEAST(amt, len - off + 1);
      buf := DBMS_LOB.SUBSTR(p_json, buflen, off);
      append_raw(p_clob, buf);
      off := off + buflen;
    END LOOP;
  END append_clob_fragment;

  ------------------------------------------------------------------------------
  FUNCTION preset_exists(p_kod IN NUMBER) RETURN BOOLEAN IS
    n PLS_INTEGER;
  BEGIN
    SELECT COUNT(*) INTO n FROM ASUSE.RR_PRESET p WHERE p.KOD_PRESET = p_kod;
    RETURN n > 0;
  END preset_exists;

  ------------------------------------------------------------------------------
  PROCEDURE write_stub(
    p_clob   IN OUT NOCOPY CLOB,
    p_kod    IN NUMBER,
    p_reason IN VARCHAR2
  ) IS
    f BOOLEAN := TRUE;
  BEGIN
    append_raw(p_clob, '{');
    append_kv_num(p_clob, f, 'kodPreset', p_kod);
    append_kv_str(p_clob, f, 'skippedReason', p_reason);
    append_raw(p_clob, '}');
  END write_stub;

  ------------------------------------------------------------------------------
  PROCEDURE append_gen_kodes_row(p_clob IN OUT NOCOPY CLOB, r IN ASUSE.RR_GEN_KODES%ROWTYPE) IS
    f BOOLEAN := TRUE;
  BEGIN
    append_raw(p_clob, '{');
    append_kv_num(p_clob, f, 'kodPreset', r.KOD_PRESET);
    append_kv_num(p_clob, f, 'kodp', r.KODP);
    append_kv_str(p_clob, f, 'nump', r.NUMP);
    append_kv_str(p_clob, f, 'name', r.NAME);
    append_kv_num(p_clob, f, 'kodDog', r.KOD_DOG);
    append_kv_str(p_clob, f, 'ndog', r.NDOG);
    append_kv_num(p_clob, f, 'ngr1', r.NGR1);
    append_kv_num(p_clob, f, 'ngr2', r.NGR2);
    append_kv_num(p_clob, f, 'ngr3', r.NGR3);
    append_kv_num(p_clob, f, 'ngr4', r.NGR4);
    append_kv_num(p_clob, f, 'ngr5', r.NGR5);
    append_kv_num(p_clob, f, 'ngr6', r.NGR6);
    append_kv_str(p_clob, f, 'sgr1', r.SGR1);
    append_kv_str(p_clob, f, 'sgr2', r.SGR2);
    append_kv_str(p_clob, f, 'sgr3', r.SGR3);
    append_kv_str(p_clob, f, 'sgr4', r.SGR4);
    append_kv_str(p_clob, f, 'sgr5', r.SGR5);
    append_kv_str(p_clob, f, 'sgr6', r.SGR6);
    append_kv_num(p_clob, f, 'ngrdog1', r.NGRDOG1);
    append_kv_num(p_clob, f, 'ngrdog2', r.NGRDOG2);
    append_kv_num(p_clob, f, 'ngrdog3', r.NGRDOG3);
    append_kv_num(p_clob, f, 'ngrdog4', r.NGRDOG4);
    append_kv_num(p_clob, f, 'ngrdog5', r.NGRDOG5);
    append_kv_num(p_clob, f, 'ngrdog6', r.NGRDOG6);
    append_kv_str(p_clob, f, 'sgrdog1', r.SGRDOG1);
    append_kv_str(p_clob, f, 'sgrdog2', r.SGRDOG2);
    append_kv_str(p_clob, f, 'sgrdog3', r.SGRDOG3);
    append_kv_str(p_clob, f, 'sgrdog4', r.SGRDOG4);
    append_kv_str(p_clob, f, 'sgrdog5', r.SGRDOG5);
    append_kv_str(p_clob, f, 'sgrdog6', r.SGRDOG6);
    append_kv_str(p_clob, f, 'inn', r.INN);
    append_kv_str(p_clob, f, 'sattr1', r.SATTR1);
    append_kv_str(p_clob, f, 'sattr2', r.SATTR2);
    append_kv_str(p_clob, f, 'sattr3', r.SATTR3);
    append_kv_str(p_clob, f, 'sattr4', r.SATTR4);
    append_kv_str(p_clob, f, 'sattr5', r.SATTR5);
    append_kv_str(p_clob, f, 'sattr6', r.SATTR6);
    append_kv_str(p_clob, f, 'sattr7', r.SATTR7);
    append_kv_str(p_clob, f, 'sattr8', r.SATTR8);
    append_kv_str(p_clob, f, 'sattr9', r.SATTR9);
    append_kv_str(p_clob, f, 'sattr10', r.SATTR10);
    append_kv_str(p_clob, f, 'sattr11', r.SATTR11);
    append_kv_str(p_clob, f, 'sattr12', r.SATTR12);
    append_kv_num(p_clob, f, 'rab', r.RAB);
    append_raw(p_clob, '}');
  END append_gen_kodes_row;

  ------------------------------------------------------------------------------
  PROCEDURE preset_json_impl(
    p_kod_preset IN NUMBER,
    p_rem_depth  IN PLS_INTEGER,
    p_clob       IN OUT NOCOPY CLOB
  ) IS
    k VARCHAR2(20);
    pr ASUSE.RR_PRESET%ROWTYPE;
    sj ASUSE.RR_PRESETSUBJECT%ROWTYPE;
    f  BOOLEAN;
    f2 BOOLEAN;
    f3 BOOLEAN;
    l_nested CLOB;
    l_first_arr BOOLEAN;

    CURSOR c_opt IS
      SELECT po.KOD_POPTION,
             po.KOD_PRESET,
             po.VAL_N,
             po.VAL_S,
             po.VAL_D,
             po.ORDNUM,
             po.DT,
             po.OPER,
             po.VAL_N1,
             po.VAL_S1,
             po.VAL_D1,
             po.OPERNOT,
             po.OPEROR,
             po.VAL_SL,
             po.NUM,
             so.NAME AS opt_name,
             so.INTNAME AS opt_intname,
             so.KOD_OPTION_TYPE,
             so.DT AS so_dt,
             so.FIELD AS so_field,
             so.SKOD_ESYS,
             so.TEP_EL,
             so.DT1 AS so_dt1,
             ot.NAME AS option_type_name,
             flt.NAME AS flt_name,
             flt.IS_HIERARCHIC AS flt_is_hier,
             flt."SQL" AS flt_sql
        FROM ASUSE.RR_PRESETOPTION po
        LEFT JOIN ASUSE.RK_PRESETSUBJOPTION so
          ON so.KOD_POPTION = po.KOD_POPTION
         AND so.KOD_PSUBJ = pr.KOD_PSUBJ
        LEFT JOIN ASUSE.RK_OPTION_TYPE ot
          ON ot.KOD_OPTION_TYPE = so.KOD_OPTION_TYPE
        LEFT JOIN ASUSE.RK_PRESETFLTROPTION flt
          ON flt.KOD_POPTION = po.KOD_POPTION
         AND (flt.KOD_PSUBJ IS NULL OR flt.KOD_PSUBJ = pr.KOD_PSUBJ)
       WHERE po.KOD_PRESET = p_kod_preset
       ORDER BY po.KOD_POPTION, po.ORDNUM;

    CURSOR c_gpc IS
      SELECT * FROM ASUSE.RR_GEN_PRESET_COLS g
       WHERE g.KOD_PRESET = p_kod_preset
       ORDER BY g.NAME;

    CURSOR c_pcol IS
      SELECT pc.KOD_PCOL FROM ASUSE.RR_PRESET_COLUMNS pc
       WHERE pc.KOD_PRESET = p_kod_preset
       ORDER BY pc.KOD_PCOL;

    CURSOR c_gk IS
      SELECT * FROM ASUSE.RR_GEN_KODES gk
       WHERE gk.KOD_PRESET = p_kod_preset;

    CURSOR c_wnd IS
      SELECT w.KOD_WND, w.NAME AS wnd_name
        FROM ASUSE.RR_PRESETWND w
       WHERE w.KOD_PRESET = p_kod_preset
       ORDER BY w.KOD_WND;

    CURSOR c_setup(p_wnd NUMBER) IS
      SELECT s."KEY" AS setup_key, s."VALUE" AS setup_val
        FROM ASUSE.RR_PRESETWNDSETUP s
       WHERE s.KOD_WND = p_wnd;

    CURSOR c_ent IS
      SELECT * FROM ASUSE.RR_PRESETENTITY e
       WHERE e.KOD_PRESET = p_kod_preset;

    CURSOR c_imp IS
      SELECT * FROM ASUSE.RR_IMPORT i
       WHERE i.KOD_PRESET = p_kod_preset
       ORDER BY i.KOD_IMP;

    CURSOR c_comp IS
      SELECT c.KOD_INCL, c.KOD_PRESET_SIMPLE
        FROM ASUSE.RR_PRESET_COMP c
       WHERE c.KOD_PRESET_COMP = p_kod_preset
       ORDER BY c.KOD_INCL;

  BEGIN
    k := TO_CHAR(p_kod_preset);

    IF NOT preset_exists(p_kod_preset) THEN
      write_stub(p_clob, p_kod_preset, 'not_found');
      RETURN;
    END IF;

    IF g_path.EXISTS(k) AND g_path(k) = 1 THEN
      write_stub(p_clob, p_kod_preset, 'cycle');
      RETURN;
    END IF;

    SELECT * INTO pr FROM ASUSE.RR_PRESET p WHERE p.KOD_PRESET = p_kod_preset;
    SELECT * INTO sj FROM ASUSE.RR_PRESETSUBJECT s WHERE s.KOD_PSUBJ = pr.KOD_PSUBJ;

    g_path(k) := 1;
    BEGIN
      append_raw(p_clob, '{');

      -- preset
      f := TRUE;
      append_raw(p_clob, '"preset":{');
      append_kv_num(p_clob, f, 'kodPreset', pr.KOD_PRESET);
      append_kv_num(p_clob, f, 'kodPsubj', pr.KOD_PSUBJ);
      append_kv_str(p_clob, f, 'name', pr.NAME);
      append_kv_str(p_clob, f, 'uM', pr.U_M);
      append_kv_date(p_clob, f, 'dM', pr.D_M);
      append_kv_num(p_clob, f, 'prProtected', pr.PR_PROTECTED);
      append_kv_num(p_clob, f, 'tmp', pr.TMP);
      append_kv_str(p_clob, f, 'title', pr.TITLE);
      append_kv_num(p_clob, f, 'typeApp', pr.TYPE_APP);
      append_kv_num(p_clob, f, 'prDefault', pr.PR_DEFAULT);
      append_raw(p_clob, '},');

      -- subject
      f := TRUE;
      append_raw(p_clob, '"subject":{');
      append_kv_num(p_clob, f, 'kodPsubj', sj.KOD_PSUBJ);
      append_kv_str(p_clob, f, 'name', sj.NAME);
      append_kv_str(p_clob, f, 'intName', sj.INTNAME);
      append_kv_num(p_clob, f, 'typePotr', sj.TYPE_POTR);
      append_raw(p_clob, '},');

      -- options
      append_raw(p_clob, '"options":[');
      l_first_arr := TRUE;
      FOR o IN c_opt LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        f2 := TRUE;
        append_raw(p_clob, '{');
        append_kv_num(p_clob, f2, 'kodPoption', o.KOD_POPTION);
        append_kv_num(p_clob, f2, 'kodPreset', o.KOD_PRESET);
        append_kv_num(p_clob, f2, 'valN', o.VAL_N);
        append_kv_str(p_clob, f2, 'valS', o.VAL_S);
        append_kv_date(p_clob, f2, 'valD', o.VAL_D);
        append_kv_num(p_clob, f2, 'ordnum', o.ORDNUM);
        append_kv_num(p_clob, f2, 'dt', o.DT);
        append_kv_str(p_clob, f2, 'oper', o.OPER);
        append_kv_num(p_clob, f2, 'valN1', o.VAL_N1);
        append_kv_str(p_clob, f2, 'valS1', o.VAL_S1);
        append_kv_date(p_clob, f2, 'valD1', o.VAL_D1);
        append_kv_num(p_clob, f2, 'opernot', o.OPERNOT);
        append_kv_num(p_clob, f2, 'operor', o.OPEROR);
        append_kv_str(p_clob, f2, 'valSl', o.VAL_SL);
        append_kv_num(p_clob, f2, 'num', o.NUM);
        append_kv_str(p_clob, f2, 'optName', o.opt_name);
        append_kv_str(p_clob, f2, 'optIntname', o.opt_intname);
        append_kv_num(p_clob, f2, 'kodOptionType', o.KOD_OPTION_TYPE);
        append_kv_num(p_clob, f2, 'defDt', o.so_dt);
        append_kv_str(p_clob, f2, 'field', o.so_field);
        append_kv_str(p_clob, f2, 'skodEsys', o.SKOD_ESYS);
        append_kv_num(p_clob, f2, 'tepEl', o.TEP_EL);
        append_kv_num(p_clob, f2, 'defDt1', o.so_dt1);
        append_kv_str(p_clob, f2, 'optionTypeName', o.option_type_name);
        append_kv_str(p_clob, f2, 'fltName', o.flt_name);
        append_kv_num(p_clob, f2, 'fltIsHierarchic', o.flt_is_hier);
        append_kv_str(p_clob, f2, 'fltSql', o.flt_sql);
        append_raw(p_clob, '}');
      END LOOP;
      append_raw(p_clob, '],');

      -- genPresetColumns
      append_raw(p_clob, '"genPresetColumns":[');
      l_first_arr := TRUE;
      FOR g IN c_gpc LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        f2 := TRUE;
        append_raw(p_clob, '{');
        append_kv_str(p_clob, f2, 'name', g.NAME);
        append_kv_num(p_clob, f2, 'kodPreset', g.KOD_PRESET);
        append_kv_num(p_clob, f2, 'kodPsubj', g.KOD_PSUBJ);
        append_kv_str(p_clob, f2, 'title', g.TITLE);
        append_kv_str(p_clob, f2, 'datatype', g.DATATYPE);
        append_kv_str(p_clob, f2, 'format', g.FORMAT);
        append_kv_num(p_clob, f2, 'alignment', g.ALIGNMENT);
        append_kv_num(p_clob, f2, 'tColor', g.T_COLOR);
        append_kv_num(p_clob, f2, 'bColor', g.B_COLOR);
        append_kv_num(p_clob, f2, 'width', g.WIDTH);
        append_kv_num(p_clob, f2, 'pattern', g.PATTERN);
        append_kv_num(p_clob, f2, 'ord', g.ORD);
        append_kv_str(p_clob, f2, 'varname', g.VARNAME);
        append_kv_num(p_clob, f2, 'decimalPlace', g.DECIMAL_PLACE);
        append_kv_num(p_clob, f2, 'compositeTitle', g.COMPOSITE_TITLE);
        append_kv_num(p_clob, f2, 'sumTotal', g.SUM_TOTAL);
        append_kv_str(p_clob, f2, 'cycleOp', g.CYCLE_OP);
        append_kv_num(p_clob, f2, 'pColor', g.P_COLOR);
        append_kv_str(p_clob, f2, 'rabcols', g.RABCOLS);
        append_kv_num(p_clob, f2, 'prRab', g.PR_RAB);
        append_kv_str(p_clob, f2, 'prTbl', g.PR_TBL);
        append_raw(p_clob, '}');
      END LOOP;
      append_raw(p_clob, '],');

      -- presetColumns (no TABLE_STATE)
      append_raw(p_clob, '"presetColumns":[');
      l_first_arr := TRUE;
      FOR p IN c_pcol LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        f2 := TRUE;
        append_raw(p_clob, '{');
        append_kv_num(p_clob, f2, 'kodPcol', p.KOD_PCOL);
        append_raw(p_clob, '}');
      END LOOP;
      append_raw(p_clob, '],');

      -- genKodes
      append_raw(p_clob, '"genKodes":[');
      l_first_arr := TRUE;
      FOR gk IN c_gk LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        append_gen_kodes_row(p_clob, gk);
      END LOOP;
      append_raw(p_clob, '],');

      -- windows + setup
      append_raw(p_clob, '"windows":[');
      l_first_arr := TRUE;
      FOR w IN c_wnd LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        f2 := TRUE;
        append_raw(p_clob, '{');
        append_kv_num(p_clob, f2, 'kodWnd', w.KOD_WND);
        append_kv_str(p_clob, f2, 'name', w.wnd_name);
        append_raw(p_clob, ',"setup":[');
        f3 := TRUE;
        FOR s IN c_setup(w.KOD_WND) LOOP
          IF NOT f3 THEN
            append_raw(p_clob, ',');
          END IF;
          f3 := FALSE;
          f2 := TRUE;
          append_raw(p_clob, '{');
          append_kv_str(p_clob, f2, 'key', s.setup_key);
          append_kv_str(p_clob, f2, 'value', s.setup_val);
          append_raw(p_clob, '}');
        END LOOP;
        append_raw(p_clob, ']}');
      END LOOP;
      append_raw(p_clob, '],');

      -- presetEntity
      append_raw(p_clob, '"presetEntity":[');
      l_first_arr := TRUE;
      FOR e IN c_ent LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        f2 := TRUE;
        append_raw(p_clob, '{');
        append_kv_num(p_clob, f2, 'kodPreset', e.KOD_PRESET);
        append_kv_num(p_clob, f2, 'kodElement', e.KOD_ELEMENT);
        append_kv_num(p_clob, f2, 'kod', e.KOD);
        append_raw(p_clob, '}');
      END LOOP;
      append_raw(p_clob, '],');

      -- imports
      append_raw(p_clob, '"imports":[');
      l_first_arr := TRUE;
      FOR i IN c_imp LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        f2 := TRUE;
        append_raw(p_clob, '{');
        append_kv_num(p_clob, f2, 'kodImp', i.KOD_IMP);
        append_kv_num(p_clob, f2, 'kodImpParent', i.KOD_IMP_PARENT);
        append_kv_num(p_clob, f2, 'kodType', i.KOD_TYPE);
        append_kv_num(p_clob, f2, 'kodPreset', i.KOD_PRESET);
        append_kv_str(p_clob, f2, 'name', i.NAME);
        append_kv_str(p_clob, f2, 'uM', i.U_M);
        append_kv_date(p_clob, f2, 'dM', i.D_M);
        append_raw(p_clob, '}');
      END LOOP;
      append_raw(p_clob, '],');

      -- compositeIncludes
      append_raw(p_clob, '"compositeIncludes":[');
      l_first_arr := TRUE;
      FOR c IN c_comp LOOP
        IF NOT l_first_arr THEN
          append_raw(p_clob, ',');
        END IF;
        l_first_arr := FALSE;
        f2 := TRUE;
        append_raw(p_clob, '{');
        append_kv_num(p_clob, f2, 'kodIncl', c.KOD_INCL);
        append_kv_num(p_clob, f2, 'kodPresetSimple', c.KOD_PRESET_SIMPLE);
        IF p_rem_depth <= 0 THEN
          DBMS_LOB.CREATETEMPORARY(l_nested, TRUE);
          write_stub(l_nested, c.KOD_PRESET_SIMPLE, 'max_depth');
        ELSE
          DBMS_LOB.CREATETEMPORARY(l_nested, TRUE);
          preset_json_impl(c.KOD_PRESET_SIMPLE, p_rem_depth - 1, l_nested);
        END IF;
        append_clob_fragment(p_clob, f2, 'nested', l_nested);
        IF l_nested IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_nested) = 1 THEN
          DBMS_LOB.FREETEMPORARY(l_nested);
        END IF;
        append_raw(p_clob, '}');
      END LOOP;
      append_raw(p_clob, ']');

      append_raw(p_clob, '}');

      g_path(k) := 0;
    EXCEPTION
      WHEN OTHERS THEN
        g_path(k) := 0;
        RAISE;
    END;
  END preset_json_impl;

  ------------------------------------------------------------------------------
  FUNCTION fn_preset_full_json(
    p_kod_preset IN NUMBER,
    p_max_depth    IN PLS_INTEGER DEFAULT 10
  ) RETURN CLOB IS
    l_clob CLOB;
  BEGIN
    g_path.DELETE;
    IF p_kod_preset IS NULL THEN
      RETURN NULL;
    END IF;
    IF NOT preset_exists(p_kod_preset) THEN
      RETURN NULL;
    END IF;

    DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
    preset_json_impl(p_kod_preset, p_max_depth, l_clob);
    RETURN l_clob;
  END fn_preset_full_json;

END PKG_RR_PRESET_JSON;
/
