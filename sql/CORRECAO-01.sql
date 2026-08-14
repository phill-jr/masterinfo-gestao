-- ================================================================
-- CORREÇÃO 01 — rode isto no SQL Editor do projeto ivkmsrypetpcmaatbvtx
--
-- Conserta duas coisas encontradas no primeiro teste:
--   1. Permissão: o login entrava mas toda tela dava "permission denied"
--   2. A função que gera as rotinas do dia estava quebrando
--
-- Cole tudo, clique em Run. Pode rodar de novo sem problema.
-- ================================================================


-- ----------------------------------------------------------------
-- 1. PRIVILÉGIOS
-- ----------------------------------------------------------------
-- RLS diz QUAIS LINHAS a pessoa vê. O GRANT diz se ela pode encostar
-- na tabela. São coisas diferentes, e faltava a segunda.
-- `anon` (visitante sem login) fica de fora de propósito.

grant usage    on schema public to authenticated;
grant all      on all tables    in schema public to authenticated;
grant all      on all sequences in schema public to authenticated;
grant execute  on all functions in schema public to authenticated;

alter default privileges in schema public grant all     on tables    to authenticated;
alter default privileges in schema public grant all     on sequences to authenticated;
alter default privileges in schema public grant execute on functions to authenticated;


-- ----------------------------------------------------------------
-- 2. gerar_acoes_do_dia
-- ----------------------------------------------------------------
-- O índice uq_acoes_ocorrencia é PARCIAL (só vale quando
-- acao_modelo_id não é nulo). Nesse caso o Postgres exige que o
-- ON CONFLICT repita o mesmo predicado, senão não consegue inferir
-- qual índice usar e estoura o erro 42P10.

create or replace function gerar_acoes_do_dia(p_data date default current_date)
returns int language plpgsql as $$
declare v_qtd int;
begin
  with modelos as (
    select m.*
    from acoes m
    where m.recorrencia <> 'nenhuma'
      and m.status = 'aberta'
      and case m.recorrencia
        when 'diaria'     then true
        when 'dias_uteis' then extract(isodow from p_data) between 1 and 5
        when 'semanal'    then extract(dow from p_data)::int = any (m.recorrencia_dias)
        when 'quinzenal'  then p_data >= m.recorrencia_inicio
                               and (p_data - m.recorrencia_inicio) % 14 = 0
        when 'mensal'     then extract(day from p_data)::int = least(
                                 m.recorrencia_dia_mes,
                                 extract(day from (date_trunc('month', p_data)
                                                   + interval '1 month - 1 day'))::int)
        else false
      end
  )
  insert into acoes (
    titulo, descricao, tipo, origem, status,
    canal_id, responsavel_id, bloqueia_id, prazo, acao_modelo_id
  )
  select
    m.titulo, m.descricao, m.tipo, 'recorrencia', 'aberta',
    m.canal_id, m.responsavel_id, m.bloqueia_id, p_data, m.id
  from modelos m
  on conflict (acao_modelo_id, prazo) where acao_modelo_id is not null do nothing;

  get diagnostics v_qtd = row_count;
  return v_qtd;
end $$;

grant execute on function gerar_acoes_do_dia(date) to authenticated;


-- ----------------------------------------------------------------
-- 3. Conferência — deve retornar 0 e nenhum erro
-- ----------------------------------------------------------------
select gerar_acoes_do_dia() as rotinas_criadas;
