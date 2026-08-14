-- ================================================================
-- CORREÇÃO 10 — Agenda por área
--
-- Permite jogar uma tarefa pontual direto na agenda do Comercial ou
-- na do Marketing. Antes o compromisso só herdava a área do canal,
-- e compromisso nem sempre tem canal.
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-10.sql
-- ================================================================

alter table agendamentos add column if not exists area text;

do $$ begin
  alter table agendamentos add constraint agendamentos_area_valida
    check (area is null or area in ('comercial', 'marketing', 'ambos'));
exception when duplicate_object then null; end $$;

comment on column agendamentos.area is
  'Em qual agenda o compromisso entra. Vazio = herda a área do canal.';

create index if not exists idx_agend_area on agendamentos (area, data_hora);

-- A view passa a devolver a área já resolvida.
-- `create or replace` não aceita mudar a ordem das colunas, então
-- ela é derrubada e recriada.
drop view if exists v_agenda_semana;

create view v_agenda_semana with (security_invoker = on) as
select
  ag.id,
  ag.data_hora,
  ag.duracao_min,
  ag.observacao,
  coalesce(ag.area, c.area, 'ambos') as area,
  a.titulo,
  a.tipo,
  a.status,
  a.origem,
  a.setor_id,
  c.nome  as canal,
  u.nome  as responsavel,
  a.responsavel_id,
  a.id    as acao_id
from agendamentos ag
join acoes a             on a.id = ag.acao_id
left join canais_venda c on c.id = coalesce(ag.canal_id, a.canal_id)
left join usuarios     u on u.id = a.responsavel_id
where ag.data_hora >= date_trunc('week', current_date)
  and ag.data_hora <  date_trunc('week', current_date) + interval '7 days'
order by ag.data_hora;

comment on view v_agenda_semana is
  'Compromissos da semana corrente, com a área resolvida (do agendamento ou do canal).';

select count(*) as compromissos_semana from v_agenda_semana;
