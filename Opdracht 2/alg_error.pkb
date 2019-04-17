create or replace package body alg_error as


  subtype error_type is varchar2(30);

  gc_err_apex_internal_apex   constant error_type := 'apex_internal_error';
  gc_err_apex_common_runtime  constant error_type := 'apex_common_runtime_error';
  gc_err_apex_other           constant error_type := 'gc_err_apex_other';
  gc_err_plsql_predefined     constant error_type := 'plsql_predefined_error';
  gc_err_plsql_constraint     constant error_type := 'plsql_constraint_error';
  gc_err_plsql_user_defined   constant error_type := 'plsql_user_defined_error';
  gc_err_plsql_non_predefined constant error_type := 'plsql_non_predefined_error';

  function is_display_inline(p_component_id in number) return boolean
  /*****************************************************************************
  *
  *****************************************************************************/
  is
    cursor c_region(b_component_id number)
    is
      select 1
        from apex_application_page_regions aapr
       where aapr.region_id = b_component_id
         and substr(aapr.source_type_code,-5) = 'QUERY';
    l_found  pls_integer;
    l_result boolean;
  begin
    open c_region(b_component_id => p_component_id);
    fetch c_region into l_found;
    close c_region;
    l_result := nvl(l_found,0) = 1;
    return l_result;
  end is_display_inline;

  function strip_ora_code(p_tekst in varchar2) return varchar2
  /*****************************************************************************
  *
  *****************************************************************************/
  is
  begin
    if substr(p_tekst,1,4) = 'ORA-' then
      return substr(p_tekst,12);
    else
      return p_tekst;
    end if;
  end strip_ora_code;


  function is_predefined_error(p_ora_code in number) return boolean
  /*****************************************************************************
  * Alle predefined errors staan in sys.standard
  *****************************************************************************/
  is

  begin

    execute immediate
      'declare
        predefined_error exception;
        pragma exception_init(predefined_error, ' || to_char(p_ora_code) || ');
       begin
        raise predefined_error;
       end;';

  exception
    when CURSOR_ALREADY_OPEN
        or DUP_VAL_ON_INDEX
        or TIMEOUT_ON_RESOURCE
        or INVALID_CURSOR
        or NOT_LOGGED_ON
        or LOGIN_DENIED
        or NO_DATA_FOUND
        or ZERO_DIVIDE
        or INVALID_NUMBER
        or TOO_MANY_ROWS
        or STORAGE_ERROR
        or PROGRAM_ERROR
        or VALUE_ERROR
        or ACCESS_INTO_NULL
        or COLLECTION_IS_NULL
        or SUBSCRIPT_OUTSIDE_LIMIT
        or SUBSCRIPT_BEYOND_COUNT
        or ROWTYPE_MISMATCH
        or SYS_INVALID_ROWID
        or SELF_IS_NULL
        or CASE_NOT_FOUND
        or USERENV_COMMITSCN_ERROR
        or NO_DATA_NEEDED
      then return true;
    when others
      then return false;


  /**/

  end is_predefined_error;

  function is_constraint_error(p_ora_code in number) return boolean
  /*****************************************************************************
  * Alle predefined errors staan in sys.standard
  *****************************************************************************/
  is

  begin

    return p_ora_code in (-1, -2091, -2290, -2291, -2292);

  end is_constraint_error;

  function is_user_defined_error(p_ora_code in number) return boolean
  /*****************************************************************************
  * Alle predefined errors staan in sys.standard
  *****************************************************************************/
  is

  begin

    return p_ora_code between -20999 and -20000 or p_ora_code = 1;

  end is_user_defined_error;

  function get_error_type(p_sqlcode in varchar2) return error_type
  /*****************************************************************************
  *
  *****************************************************************************/
  is
    l_error_type error_type;
  begin
    if is_constraint_error(p_sqlcode) then
      l_error_type := gc_err_plsql_constraint;
    elsif is_predefined_error(p_sqlcode) then
      l_error_type := gc_err_plsql_predefined;
    elsif is_user_defined_error(p_sqlcode) then
      l_error_type := gc_err_plsql_user_defined;
    else
      l_error_type := gc_err_plsql_non_predefined;
    end if;
    return l_error_type;
  end get_error_type;

  function get_error_type(p_error apex_error.t_error) return error_type
  /*****************************************************************************
  * Er zijn 6 type foutmeldingen die allen op hun eigen manier gelogd en vertaald moeten worden
  *****************************************************************************/
  is

    l_error_type    error_type;
    e_stop          exception;

  begin

    if p_error.is_internal_error and not p_error.is_common_runtime_error and p_error.ora_sqlcode is null then

      l_error_type := gc_err_apex_internal_apex;
      raise e_stop;

    end if;

    if p_error.is_common_runtime_error then

      l_error_type := gc_err_apex_common_runtime;
      raise e_stop;

    end if;

    if p_error.ora_sqlcode is not null then

      l_error_type := get_error_type(p_sqlcode => p_error.ora_sqlcode);

      raise e_stop;

    end if;

    if l_error_type is null then

      l_error_type := gc_err_apex_other;

    end if;

    return l_error_type;

  exception
    when e_stop then
      return l_error_type;

  end get_error_type;

  function get_ora_code(p_ora_sqlcode number) return varchar2
  /*****************************************************************************
  * Formatteer foutnr als tekst
  *****************************************************************************/
  is
  begin

    return 'ORA-'||lpad(abs(p_ora_sqlcode),5,0);

  end get_ora_code;

  function apex_error_handling(p_error  in apex_error.t_error
                              ,p_prefix in varchar2 default null) return apex_error.t_error_result
  /******************************************************************************
  * Functie die als Error Handling Function wordt gebruikt in de Application
  * definition in de Apex applicatie(s)
  ******************************************************************************/
  is

    l_error_type      error_type;
    l_result          apex_error.t_error_result;

    l_reference_id    number;
    l_constraint_name varchar2(255);
    l_ora_code        varchar2(30);
    l_log_id          varchar2(256);

    procedure zet_display_location(
      p_error_type  in error_type
      --
    , p_result      in out apex_error.t_error_result
    ) is

      e_verkeerde_type  exception;

    begin

      if p_error_type in (gc_err_apex_internal_apex, gc_err_apex_common_runtime) then
        raise e_verkeerde_type;
      end if;

      if l_result.display_location = apex_error.c_on_error_page then

        l_result.display_location := apex_error.c_inline_in_notification;

      end if;

    exception
      when e_verkeerde_type then
        null;

    end zet_display_location;

  begin

    -- Initaliseer de output
    l_result  := apex_error.init_error_result(p_error => p_error);

    -- Wat voor foutmelding betreft het?
    l_error_type := get_error_type(p_error);
    l_ora_code := get_ora_code(p_error.ora_sqlcode);

    -- Bepaal welke melding uiteindelijk aan de gebruiker getoond moet worden (tekst en helptekst)
    if l_error_type = gc_err_apex_internal_apex then

      -- Normaal gesproken alleen loggen, behalve uitgezonderde apex_error_codes en uitgezonderde ora_sqlcodes
      l_result.message :=
        case p_error.apex_error_code
             when 'APEX.PAGE.DUPLICATE_SUBMIT' then 'Er is een fout opgetreden. Waarschijnlijk is dit ontstaan door een dubbelklik.'
             else 'Er is een onbekende fout opgetreden. Raadpleeg eventueel de servicedesk en vermeld de foutcode.'
         end;

      l_result.additional_info := null;

    elsif l_error_type = gc_err_apex_common_runtime then

      -- Dit soort fouten wel tonen aan gebruiker en ook loggen
      null;

    elsif l_error_type = gc_err_plsql_predefined then

      -- Dit soort meldingen hebben een vaste tekst, voor deze ora-code kan een melding bestaan
      null;

    elsif l_error_type = gc_err_plsql_constraint then

      -- Bepaal de melding op basis van de constraint name
      null;

    elsif l_error_type = gc_err_plsql_user_defined then

      -- User defined wil zeggen dat de melding via raise_application_error al een gebruiksvriendelijke melding heeft
      l_result.message := strip_ora_code(apex_error.get_first_ora_error_text(p_error => p_error));

    elsif l_error_type = gc_err_plsql_non_predefined then

      -- Dit soort fouten alleen teruggeven aan gebruikers als ze bestaan, en altijd loggen
      null;


    end if;


    -- Waar en hoe tonen we de foutmelding?
    -- Er zijn 5 varianten:
    -- 1. error_page (c_on_error_page)
    -- 2. page notification (c_inline_in_notification)
    -- 3. bij page item (c_inline_with_field)
    -- 4. zowel page notification als page item (c_inline_with_field_and_notif)
    -- 5. Inline in region (display_location null)

    zet_display_location(
      p_error_type  => l_error_type
    , p_result      => l_result
    );

    -- Alleen bij page notification de additional info ook toevoegen
    if l_result.display_location = apex_error.c_inline_in_notification then

      l_result.message := '<message>'||l_result.message||'</message> <info>'||l_result.additional_info||'</info>';

      -- Verwijder voor de zekerheid de additional_info zodat het ook in toekomstige versies geen probleem oplevert.
      l_result.additional_info := null;

    end if;

    -- Vervang substitution strings
    l_result.message := replace(l_result.message, '#LOG_ID#', 1);

    return l_result;

  end apex_error_handling;

  function get_constraint_name(p_sqlerrm varchar2) return varchar2
  /******************************************************************************
  * Naam van de constraint ophalen uit de error melding
  ******************************************************************************/
  is
    l_constraint_name varchar2(255);
  begin
    l_constraint_name := ltrim(rtrim(regexp_substr(p_sqlerrm, '\(([^).]+\.[^).]+)\)'), ')'), '(');
    return substr(l_constraint_name,instr(l_constraint_name,'.')+1);
  exception
    when others
    then
      return null;
  end get_constraint_name;


end alg_error;
/

