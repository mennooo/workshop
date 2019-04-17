create or replace package alg_error as

  type info_rectype is record( melding      varchar2(8000)
                             , proc_schema  all_objects.owner%TYPE
                             , proc_naam    all_objects.object_name%TYPE
                             , regelnr      pls_integer);

  g_ind_test     boolean := false;
  e_handled_exception exception;
  pragma exception_init(e_handled_exception, -20000);

  gc_toon_error_nr  constant number := -20999;

  /******************************************************************************
  * Functie die als Error Handling Function wordt gebruikt in de Application
  * definition in de Apex applicatie(s)
  ******************************************************************************/
  function apex_error_handling(p_error  in apex_error.t_error
                              ,p_prefix in varchar2 default null) return apex_error.t_error_result;
  
end alg_error;
/

