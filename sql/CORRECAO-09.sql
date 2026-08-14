-- ================================================================
-- CORREÇÃO 09 — Metas alinhadas ao Dashboard Comercial
--
-- O painel em dash-comercial-masterinfo.onrender.com/financeiro
-- trabalha com: Vendas, Receita, Faturamento, Ticket Médio,
-- Leads Válidos e Ativações — e projeta a meta por DIAS ÚTEIS.
--
-- Aqui o indicador era um enum curto (vendas/leads/ativos/receita) e
-- a projeção usava dias corridos. Duas fontes com contas diferentes
-- é como ter dois relógios: nunca se sabe qual está certo.
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-09.sql
-- ================================================================


-- ----------------------------------------------------------------
-- 1. VOCABULÁRIO DO INDICADOR
-- ----------------------------------------------------------------
-- Vira texto com CHECK em vez de enum: assim o dia em que o painel
-- ganhar um indicador novo, é uma linha e não uma migração de tipo.

-- A view trava a troca de tipo da coluna. O painel do dia depende
-- dela, então as duas caem e são recriadas aqui embaixo.
drop view if exists v_metas_progresso cascade;

alter table metas alter column indicador type text using indicador::text;

update metas set indicador = 'ativacoes' where indicador = 'ativos';

do $$ begin
  alter table metas add constraint metas_indicador_valido
    check (indicador in ('vendas','receita','faturamento','ticket_medio',
                         'leads','ativacoes','cancelamentos'));
exception when duplicate_object then null; end $$;

comment on column metas.indicador is
  'Mesmo vocabulário do Dashboard Comercial: vendas, receita, faturamento, '
  'ticket_medio, leads (válidos), ativacoes, cancelamentos.';


-- ----------------------------------------------------------------
-- 2. PROJEÇÃO POR DIAS ÚTEIS
-- ----------------------------------------------------------------
-- Dia corrido mente: no dia 20 de um mês, metade do "tempo" passou
-- mas 70% dos dias úteis já foram. Quem vende de segunda a sexta
-- precisa da conta em dias úteis, que é a do painel.

create or replace view v_metas_progresso with (security_invoker = on) as
select
  m.id,
  coalesce(c.nome, 'Geral')      as canal,
  m.canal_id,
  m.indicador,
  m.tipo_periodo,
  m.periodo_inicio,
  m.periodo_fim,
  m.valor_meta,
  m.valor_realizado,
  round(100.0 * m.valor_realizado / nullif(m.valor_meta, 0), 1) as pct_atingido,

  du.total       as dias_uteis_total,
  du.decorridos  as dias_uteis_decorridos,
  du.total - du.decorridos as dias_uteis_restantes,

  -- Quanto do esforço útil já passou
  round(100.0 * du.decorridos / nullif(du.total, 0), 1) as pct_periodo,

  -- Mantendo o ritmo atual, onde a meta termina
  round(m.valor_realizado * du.total::numeric / nullif(du.decorridos, 0), 2) as projecao,

  -- Quanto precisa sair por dia útil restante para bater
  round(greatest(m.valor_meta - m.valor_realizado, 0)
        / nullif(du.total - du.decorridos, 0), 2) as ritmo_necessario,

  -- Quanto vinha saindo por dia útil até agora
  round(m.valor_realizado / nullif(du.decorridos, 0), 2) as ritmo_atual,

  case
    when m.valor_realizado >= m.valor_meta                    then 'batida'
    when current_date > m.periodo_fim                         then 'perdida'
    when du.decorridos = 0                                    then 'no_ritmo'
    when m.valor_realizado * du.total::numeric
         / nullif(du.decorridos, 0) >= m.valor_meta           then 'no_ritmo'
    when m.valor_realizado * du.total::numeric
         / nullif(du.decorridos, 0) >= m.valor_meta * 0.85    then 'atencao'
    else 'atrasada'
  end as situacao,

  m.atualizado_em
from metas m
left join canais_venda c on c.id = m.canal_id
cross join lateral (
  select
    count(*) filter (where extract(isodow from d) between 1 and 5) as total,
    count(*) filter (where extract(isodow from d) between 1 and 5
                       and d::date <= current_date)                as decorridos
  from generate_series(m.periodo_inicio, m.periodo_fim, interval '1 day') d
) du
order by m.periodo_inicio desc, canal;

comment on view v_metas_progresso is
  'Meta x realizado com projeção por DIAS ÚTEIS — mesma conta do Dashboard Comercial.';


-- ----------------------------------------------------------------
-- 3. PAINEL DO DIA (recriado por dependência)
-- ----------------------------------------------------------------

create or replace view v_dashboard_dia with (security_invoker = on) as
select
  (select count(*) from v_acoes_hoje where prioridade = 'atrasada')        as acoes_atrasadas,
  (select count(*) from v_acoes_hoje where prioridade = 'hoje')            as acoes_hoje,
  (select count(*) from v_acoes_hoje where prioridade = 'urgente')         as acoes_urgentes,
  (select count(*) from v_acoes_hoje where prioridade = 'destrava')        as pendencias_travando,
  (select count(*) from agendamentos
     where data_hora::date = current_date)                                 as compromissos_hoje,
  (select count(*) from campanhas where status = 'ativa')                  as campanhas_ativas,
  (select count(*) from producao_conteudo
     where status not in ('validado', 'publicado', 'arquivado')
       and data_entrega < current_date)                                    as conteudo_atrasado,
  (select count(*) from v_capacidade_semana where saldo < 0)               as pessoas_sobrecarregadas,
  (select count(*) from v_metas_progresso
     where situacao in ('atrasada', 'atencao') and periodo_fim >= current_date) as metas_atrasadas,
  (select count(*) from v_time_status
     where feedback_situacao in ('atrasado', 'nunca'))                     as feedbacks_atrasados,
  (select count(*) from v_time_status where pdi_situacao = 'ciclo_vencido') as pdis_vencidos;

comment on view v_dashboard_dia is
  'Resumo do dia. Todo número aqui deve disparar uma ação — se não dispara, tire.';


-- ----------------------------------------------------------------
-- Conferência
-- ----------------------------------------------------------------
select indicador, count(*) as metas from metas group by 1 order by 1;
