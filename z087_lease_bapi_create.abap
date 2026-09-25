REPORT z087_lease_bapi_create.

*-----------------------------------------------------------------------
* RE-FX lease / real estate contract creation sample report.
*
* BAPI: BAPI_RE_CN_CREATE
* Transaction for reference data: RECN
*
* Fill the mandatory fields according to your RE-FX customizing.
* Start with test run = X, then compare the payload with a contract read
* by BAPI_RE_CN_GET_DETAIL from an already-created RECN contract.
*-----------------------------------------------------------------------

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE gv_title.
PARAMETERS:
  p_bukrs TYPE bapi_re_contract_key-comp_code OBLIGATORY,
  p_ctyp  TYPE bapi_re_contract_key-contract_type OBLIGATORY,
  p_cnum  TYPE bapi_re_contract_key-contract_number,
  p_text  TYPE bapi_re_contract_dat-contract_text OBLIGATORY,
  p_begda TYPE bapi_re_contract_dat-contract_start_date OBLIGATORY,
  p_endda TYPE bapi_re_contract_dat-first_end_date,
  p_waers TYPE bapi_re_contract_dat-currency_contract DEFAULT 'JPY',
  p_testr TYPE bapi_re_additional_fields-testrun AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b01.

DATA:
  gs_contract        TYPE bapi_re_contract_dat,
  gt_return          TYPE STANDARD TABLE OF bapiret2,
  gs_return          TYPE bapiret2,
  gv_compcode        TYPE bapi_re_contract_key-comp_code,
  gv_contractnumber  TYPE bapi_re_contract_key-contract_number,
  gv_has_error       TYPE abap_bool.

INITIALIZATION.
  gv_title = 'RE-FX Contract Header'.

START-OF-SELECTION.
  PERFORM validate_input.
  PERFORM build_contract_data.
  PERFORM create_contract.
  PERFORM finish_transaction.
  PERFORM output_result.

FORM validate_input.
  IF p_endda IS NOT INITIAL AND p_endda LT p_begda.
    MESSAGE 'End date must be greater than or equal to start date.' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM build_contract_data.
  CLEAR gs_contract.

  gs_contract-contract_text             = p_text.
  gs_contract-contract_conclusion_date  = sy-datum.
  gs_contract-contract_start_date       = p_begda.
  gs_contract-first_end_date            = p_endda.
  gs_contract-currency_contract         = p_waers.
  gs_contract-responsible               = sy-uname.

  "Add system-specific mandatory fields here, for example:
  "gs_contract-stat_prof                 = '<status profile>'.
  "gs_contract-tenancy_law               = '<tenancy law>'.
ENDFORM.

FORM create_contract.
  CLEAR:
    gt_return,
    gv_compcode,
    gv_contractnumber.

  CALL FUNCTION 'BAPI_RE_CN_CREATE'
    EXPORTING
      comp_code_ext       = p_bukrs
      contract_type       = p_ctyp
      contract_number_ext = p_cnum
      contract            = gs_contract
      test_run            = p_testr
    IMPORTING
      compcode            = gv_compcode
      contractnumber      = gv_contractnumber
    TABLES
      return              = gt_return.

  gv_has_error = abap_false.

  LOOP AT gt_return INTO gs_return
       WHERE type = 'E'
          OR type = 'A'
          OR type = 'X'.
    gv_has_error = abap_true.
    EXIT.
  ENDLOOP.
ENDFORM.

FORM finish_transaction.
  IF gv_has_error = abap_true OR p_testr = abap_true.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = abap_true.
ENDFORM.

FORM output_result.
  DATA lv_mode TYPE string.

  IF p_testr = abap_true.
    lv_mode = 'TEST RUN - rolled back'.
  ELSEIF gv_has_error = abap_true.
    lv_mode = 'ERROR - rolled back'.
  ELSE.
    lv_mode = 'POSTED - committed'.
  ENDIF.

  WRITE: / 'BAPI_RE_CN_CREATE result:', lv_mode.
  WRITE: / 'Company code:', gv_compcode,
         / 'Contract no.:', gv_contractnumber.
  SKIP.

  IF gt_return IS INITIAL.
    WRITE: / 'No messages returned.'.
    RETURN.
  ENDIF.

  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: / 'Ty', 5 'ID', 27 'No', 34 'Message'.
  FORMAT RESET.

  LOOP AT gt_return INTO gs_return.
    WRITE: / gs_return-type UNDER 'Ty',
             gs_return-id   UNDER 'ID',
             gs_return-number UNDER 'No',
             gs_return-message UNDER 'Message'.
  ENDLOOP.
ENDFORM.
