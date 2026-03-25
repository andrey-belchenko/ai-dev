-- =============================================================================
-- ASUSE.PKG_RR_PRESET_JSON (specification)
-- Oracle 11.2: build JSON (CLOB) with report preset settings for KOD_PRESET.
-- No APEX_JSON / no 12c JSON features. Uses DBMS_LOB + manual escaping.
-- See gen/RR_PRESET_REFERENCE.md for table relationships.
--
-- Public API:
--
--   fn_preset_full_json(p_kod_preset, p_max_depth) RETURN CLOB
--     Full JSON document. Returns NULL if preset does not exist.
--     Recursive RR_PRESET_COMP children respect p_max_depth; cycle-safe.
--     RR_PRESET_COLUMNS.TABLE_STATE (BLOB) is omitted (kodPcol only).
--
--   fn_preset_json_init(p_kod_preset, p_max_depth, p_chunk_size) RETURN NUMBER
--     Generates JSON, caches it in a package variable, returns chunk count.
--     Subsequent fn_get_chunk() calls read from the cache.
--
--   fn_get_chunk(p_chunk_no) RETURN VARCHAR2
--     Returns the Nth chunk (1-based) from the cached CLOB.
--
-- No schema-level types required. Deploy: run this file, then _body.sql.
-- =============================================================================

CREATE OR REPLACE PACKAGE ASUSE.PKG_RR_PRESET_JSON AS

  FUNCTION fn_preset_full_json(
    p_kod_preset   IN NUMBER,
    p_max_depth    IN PLS_INTEGER DEFAULT 10
  ) RETURN CLOB;

  FUNCTION fn_preset_json_init(
    p_kod_preset   IN NUMBER,
    p_max_depth    IN PLS_INTEGER DEFAULT 10,
    p_chunk_size   IN PLS_INTEGER DEFAULT 4000
  ) RETURN PLS_INTEGER;

  FUNCTION fn_get_chunk(
    p_chunk_no IN PLS_INTEGER
  ) RETURN VARCHAR2;

END PKG_RR_PRESET_JSON;
/
