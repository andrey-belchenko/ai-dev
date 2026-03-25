-- =============================================================================
-- ASUSE.PKG_RR_PRESET_JSON (specification)
-- Oracle 11.2: build JSON (CLOB) with report preset settings for KOD_PRESET.
-- No APEX_JSON / no 12c JSON features. Uses DBMS_LOB + manual escaping.
-- See oracle-mcp/RR_PRESET_REFERENCE.md for table relationships.
--
-- Public: fn_preset_full_json(p_kod_preset, p_max_depth)
--   Returns NULL if preset row does not exist.
--   Recursive RR_PRESET_COMP children respect p_max_depth; cycle-safe.
--   RR_PRESET_COLUMNS.TABLE_STATE (BLOB) is omitted (kodPcol only).
--
-- Deploy: run this file before pkg_rr_preset_json_body.sql.
-- =============================================================================

CREATE OR REPLACE PACKAGE ASUSE.PKG_RR_PRESET_JSON AS

  FUNCTION fn_preset_full_json(
    p_kod_preset IN NUMBER,
    p_max_depth    IN PLS_INTEGER DEFAULT 10
  ) RETURN CLOB;

END PKG_RR_PRESET_JSON;
/
