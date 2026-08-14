-- ================================================================
-- CORREÇÃO 05 — Horário e tags nas rotinas
--
-- Duas colunas:
--   hora — a que horas a rotina acontece, para a tela "Rotina
--          semanal" montar o dia em ordem cronológica
--   tags — assunto da rotina (comercial, conteúdo, gestão…), para
--          filtrar o check do dia
--
-- As telas funcionam sem isto, só sem horário e sem filtro por tag.
--
-- Cole no SQL Editor e clique em Run. Pode rodar de novo.
-- ================================================================

alter table acoes add column if not exists hora time;
alter table acoes add column if not exists tags text[];

comment on column acoes.hora is
  'Horário previsto. Vazio = sem hora marcada, cai no fim do dia na tela semanal.';
comment on column acoes.tags is
  'Assunto livre da ação. Usado para filtrar o check do dia.';

-- Índice para o filtro por tag não varrer a tabela inteira
create index if not exists idx_acoes_tags on acoes using gin (tags);

-- A ocorrência gerada herda hora e tags do modelo
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
    canal_id, responsavel_id, bloqueia_id, prazo, acao_modelo_id, hora, tags
  )
  select
    m.titulo, m.descricao, m.tipo, 'recorrencia', 'aberta',
    m.canal_id, m.responsavel_id, m.bloqueia_id, p_data, m.id, m.hora, m.tags
  from modelos m
  on conflict (acao_modelo_id, prazo) where acao_modelo_id is not null do nothing;

  get diagnostics v_qtd = row_count;
  return v_qtd;
end $$;

grant execute on function gerar_acoes_do_dia(date) to authenticated;


-- Conferência
select count(*) filter (where hora is not null) as com_horario,
       count(*) filter (where tags is not null) as com_tag,
       count(*)                                 as rotinas
from acoes where recorrencia <> 'nenhuma';
