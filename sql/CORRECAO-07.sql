-- ================================================================
-- CORREÇÃO 07 — Gerar a semana inteira de uma vez
--
-- gerar_acoes_do_dia() já resolve um dia. Esta função percorre um
-- intervalo chamando aquela, dia a dia — mesma regra, uma ida só
-- ao banco.
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-07.sql
-- ================================================================

create or replace function gerar_acoes_do_periodo(
  p_de  date default current_date,
  p_ate date default current_date
) returns int
language plpgsql as $$
declare
  v_dia   date;
  v_total int := 0;
begin
  if p_ate < p_de then
    raise exception 'A data final (%) é anterior à inicial (%)', p_ate, p_de;
  end if;
  -- Trava de segurança: ninguém gera um ano inteiro por engano
  if p_ate - p_de > 62 then
    raise exception 'Intervalo de % dias é grande demais (máximo 62)', p_ate - p_de;
  end if;

  for v_dia in select generate_series(p_de, p_ate, interval '1 day')::date loop
    v_total := v_total + gerar_acoes_do_dia(v_dia);
  end loop;

  return v_total;
end $$;

comment on function gerar_acoes_do_periodo is
  'Gera as ocorrências de um intervalo. Idempotente: rodar de novo não duplica.';

grant execute on function gerar_acoes_do_periodo(date, date) to authenticated;

-- Conferência: não cria nada, só confirma que a função responde
select gerar_acoes_do_periodo(current_date, current_date) as geradas_hoje;
