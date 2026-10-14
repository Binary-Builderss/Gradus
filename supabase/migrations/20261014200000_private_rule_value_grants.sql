-- private.rule_value nasce dopo il revoke generale della migrazione core: stesso trattamento degli altri helper.
revoke execute on function private.rule_value(jsonb, int) from public, anon;
grant execute on function private.rule_value(jsonb, int) to authenticated;
