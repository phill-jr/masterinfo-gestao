-- =====================================================================
-- CORREÇÃO 23 — O plano de abertura sai do canal
-- ---------------------------------------------------------------------
-- Pedido do Philipe (25/08): o plano de abertura (5 blocos do método)
-- não deve existir na ficha do canal. O canal se configura pelos
-- arquivos anexados (apresentação HTML + configuração .md) e pelos
-- 4 passos: o que é, meta, regras e fluxograma.
--
-- O gate de estágio era baseado nos itens do plano ("lista vazia não
-- é lista cumprida") — sem plano, canal nenhum passaria de ideia.
-- Esta correção troca a régua:
--
--   ideia        → configuração completa (os 4 passos preenchidos)
--   estruturacao → configuração completa + D1 marcada
--   piloto       → primeira venda lançada no financeiro do canal
--   operacao     → rotina viva e campanha no ar (como era)
--   escala       → sempre pode encerrar
--
-- As colunas plano_* e estrutura_* continuam na view (mesma assinatura,
-- o create or replace exige) — passam a valer 0 com as ações de plano
-- removidas. A tabela canal_plano_modelo e a função canal_aplicar_plano
-- ficam no banco, inofensivas, caso o método volte um dia.
-- Pode rodar mais de uma vez.
-- =====================================================================

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

  -- O gate do estágio atual: o que precisa ser verdade para o canal
  -- ter direito de avançar — e o que a tela cobra. Sem plano, a régua
  -- é a configuração (4 passos), a D1, a primeira venda e o motor.
  case c.estagio
    when 'ideia'        then coalesce(cf.completa, false)
    when 'estruturacao' then coalesce(cf.completa, false)
                          and c.data_abertura is not null
    when 'piloto'       then exists (select 1 from financeiro_mkt f
                                      where f.canal_id = c.id and f.vendas > 0)
    when 'operacao'     then coalesce(rot.n, 0) > 0 and coalesce(cmp.n, 0) > 0
    when 'escala'       then true
    else true
  end                                                 as gate_ok,

  case c.estagio
    when 'ideia'        then 'Configuração completa: o que é, meta, regras e fluxograma'
    when 'estruturacao' then 'Configuração completa e D1 marcada'
    when 'piloto'       then 'Primeira venda lançada no financeiro do canal'
    when 'operacao'     then 'Rotina viva e campanha no ar'
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
  'Uma linha por canal: estágio, configuração, motor rodando e o gate que falta. Sem plano de abertura desde a CORREÇÃO 23.';
