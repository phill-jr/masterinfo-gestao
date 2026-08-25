-- =====================================================================
-- CORREÇÃO 24 — Campanha é do SETOR, não do canal
-- ---------------------------------------------------------------------
-- Pedido do Philipe (25/08): "não quero que exista campanha por canal,
-- quero campanha por setor — tipo, campanha do setor Comercial".
--
-- A campanha ganha `setor_id` (aponta para o cadastro de setores) e o
-- front para de escrever `canal_id`. A coluna `canal_id` fica na
-- tabela por histórico — nada a apaga — mas sai das telas.
--
-- Consequência no canal: o gate de "operação" exigia rotina + campanha
-- no ar. Com a campanha solta do canal, essa exigência não fecharia
-- nunca — o gate passa a ser só a rotina viva. As colunas
-- `campanhas_ativas` e `ultima_campanha_fim` continuam na view (o
-- create or replace exige a mesma assinatura), contando o legado por
-- canal_id, que tende a zero.
--
-- Pode rodar mais de uma vez sem duplicar nada.
-- =====================================================================

alter table campanhas add column if not exists
  setor_id uuid references setores (id) on delete set null;

comment on column campanhas.setor_id is
  'O setor dono da campanha (Comercial, Marketing…). Desde a CORREÇÃO 24 a campanha é do setor; canal_id é legado e não é mais escrito pelas telas.';

create index if not exists idx_campanhas_setor on campanhas (setor_id);


-- ---------------------------------------------------------------------
-- v_canal_saude: gate de operação vira só "rotina viva"
-- ---------------------------------------------------------------------

create or replace view v_canal_saude with (security_invoker = on) as
with rot as (
  select canal_id, count(*) as n from acoes
   where recorrencia <> 'nenhuma' and status = 'aberta' and canal_id is not null
   group by 1),
cmp as (
  select canal_id, count(*) as n from campanhas
   where status = 'ativa' and canal_id is not null group by 1),
cmp_prox as (
  select canal_id, max(data_fim) as fim from campanhas
   where canal_id is not null group by 1),
mt as (
  select canal_id,
         sum(valor_meta)      as meta,
         sum(valor_realizado) as realizado
    from metas
   where indicador = 'vendas'
     and current_date between periodo_inicio and periodo_fim
   group by 1),
ult as (
  select canal_id, max(concluida_em) as em from acoes
   where status = 'concluida' and canal_id is not null group by 1),
cfg as (
  select c2.id,
         nullif(trim(coalesce(c2.publico,    '')), '') is not null
     and nullif(trim(coalesce(c2.mecanica,   '')), '') is not null
     and c2.meta_30d is not null
     and nullif(trim(coalesce(c2.regras,     '')), '') is not null
     and nullif(trim(coalesce(c2.fluxograma, '')), '') is not null as completa
    from canais_venda c2)
select
  c.id,
  c.nome,
  c.tipo,
  c.area,
  c.ativo,
  c.estagio,
  c.data_abertura,
  c.publico,
  c.mecanica,
  c.cac_alvo,
  c.meta_30d,
  c.meta_90d,
  c.responsavel_id,
  u.nome                                              as dono,

  coalesce(be.itens, 0)                               as estrutura_itens,
  coalesce(be.feitos, 0)                              as estrutura_feitos,
  coalesce(be.pct, 0)                                 as estrutura_pct,
  coalesce(be.abertos_obrigatorios, 0)                as estrutura_falta,

  coalesce((select sum(itens)     from v_canal_bloco b where b.canal_id = c.id), 0) as plano_itens,
  coalesce((select sum(feitos)    from v_canal_bloco b where b.canal_id = c.id), 0) as plano_feitos,
  coalesce((select sum(atrasados) from v_canal_bloco b where b.canal_id = c.id), 0) as plano_atrasados,

  coalesce(rot.n, 0)                                  as rotinas,
  coalesce(cmp.n, 0)                                  as campanhas_ativas,
  mt.meta                                             as meta_mes,
  mt.realizado                                        as realizado_mes,
  ult.em                                              as ultima_conclusao,
  case when ult.em is not null
       then (current_date - ult.em::date) end         as dias_parado,

  -- O gate do estágio atual. Campanha saiu da régua na CORREÇÃO 24:
  -- ela é do setor, então o motor do canal é a rotina.
  case c.estagio
    when 'ideia'        then coalesce(cf.completa, false)
    when 'estruturacao' then coalesce(cf.completa, false)
                          and c.data_abertura is not null
    when 'piloto'       then exists (select 1 from financeiro_mkt f
                                      where f.canal_id = c.id and f.vendas > 0)
    when 'operacao'     then coalesce(rot.n, 0) > 0
    when 'escala'       then true
    else true
  end                                                 as gate_ok,

  case c.estagio
    when 'ideia'        then 'Configuração completa: o que é, meta, regras e fluxograma'
    when 'estruturacao' then 'Configuração completa e D1 marcada'
    when 'piloto'       then 'Primeira venda lançada no financeiro do canal'
    when 'operacao'     then 'Rotina viva no canal'
    when 'escala'       then 'Reativação rodando e próximo canal aberto'
    else                     'Encerrado'
  end                                                 as gate,

  cmp_prox.fim                                        as ultima_campanha_fim
from canais_venda c
left join usuarios u        on u.id = c.responsavel_id
left join v_canal_bloco be  on be.canal_id = c.id and be.bloco = 'estrutura'
left join cfg cf            on cf.id = c.id
left join rot               on rot.canal_id = c.id
left join cmp               on cmp.canal_id = c.id
left join cmp_prox          on cmp_prox.canal_id = c.id
left join mt                on mt.canal_id = c.id
left join ult               on ult.canal_id = c.id;

comment on view v_canal_saude is
  'Uma linha por canal: estágio, configuração, rotina viva e o gate que falta. Campanha é do setor desde a CORREÇÃO 24.';
