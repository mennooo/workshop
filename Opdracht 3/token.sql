declare

  s varchar2(32767);
  token varchar2(100);
s
begin
  
  s := '{ "username": "DEMO", "app": 108176, "page": 5, "items": "P5_ID", "values": "1234"}';

  token := oos_util_crypto.mac_str(
    p_src => s
  , p_typ => oos_util_crypto.gc_hmac_sh256
  , p_key => 'geheim'
  );

  dbms_output.put_line(token);
  
end;