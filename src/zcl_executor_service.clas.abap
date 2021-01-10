CLASS zcl_executor_service DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_executor_service .

    METHODS constructor
      IMPORTING
        !iv_server_group             TYPE rfcgr
        !iv_max_no_of_tasks          TYPE i DEFAULT 10
        !iv_no_resubmission_on_error TYPE boole_d DEFAULT abap_false
        !io_message_handler          TYPE REF TO zif_message_handler .
  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA mo_spta_wrapper TYPE REF TO zcl_spta_wrapper .
    DATA mv_server_group TYPE rfcgr .
    DATA mv_max_no_of_tasks TYPE i .
    DATA mv_no_resubmission_on_error TYPE boole_d .
    DATA mo_message_handler TYPE REF TO zif_message_handler .
ENDCLASS.



CLASS ZCL_EXECUTOR_SERVICE IMPLEMENTATION.


  METHOD constructor.

    mv_server_group = iv_server_group.
    mv_max_no_of_tasks = iv_max_no_of_tasks.
    mv_no_resubmission_on_error = iv_no_resubmission_on_error.
    mo_message_handler = io_message_handler.

  ENDMETHOD.


  METHOD zif_executor_service~invoke_all.

    CREATE OBJECT mo_spta_wrapper
      EXPORTING
        iv_server_group             = mv_server_group
        iv_max_no_of_tasks          = mv_max_no_of_tasks
        iv_no_resubmission_on_error = mv_no_resubmission_on_error
        io_message_handler          = mo_message_handler.

    ro_results = mo_spta_wrapper->start( io_tasks ).

  ENDMETHOD.
ENDCLASS.