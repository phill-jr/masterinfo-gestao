-- =====================================================================
-- CORREÇÃO 15 — CANAL VIRA CICLO DE VIDA, NÃO ETIQUETA
-- =====================================================================
-- Até aqui `canais_venda` era cadastro: nome, tipo, área, responsável.
-- Servia para filtrar meta e campanha, e nada mais. A própria tela de
-- canais já denunciava o buraco com a coluna "ativo sem operação" —
-- que é o sistema dizendo "este canal existe no cadastro e não existe
-- na vida".
--
-- Um canal não nasce pronto: ele é aberto, estruturado, testado,
-- operado e escalado. Esta correção dá a ele estágio, plano de
-- abertura e leitura de saúde.
--
-- OS CINCO BLOCOS (metodologia FazUp, em `04 - Canais de Indicação`):
--
--   1 estrutura → dono, regra, oferta + a conta, materiais, rastreio
--                 gate: alguém consegue indicar hoje E ser pago
--   2 ativacao  → acontece UMA vez: 1a leva, D1, treinar quem recebe
--                 gate: 1a indicação convertida em ate 7 dias
--   3 motor     → campanha (tem fim) + rotina (não tem)
--                 gate: 2 ciclos batendo a meta
--   4 medicao   → funil + CPL/CAC/ROI do canal
--                 gate: veredito escalar / ajustar / cortar
--   5 escala    → reativar parado, tier, abrir o próximo canal
--
-- DECISÃO QUE SEGURA O RESTO: item de plano NÃO tem tabela própria de
-- "feito". Aplicar o plano num canal GERA AÇÕES em `acoes`. Feito =
-- ação concluída. Se o checklist tivesse um lugar próprio de marcar,
-- você marcaria em dois lugares e nenhum viraria verdade — e a
-- abertura do canal ficaria fora da fila do dia, que é a única caixa
-- de entrada do sistema. Mesmo princípio do "rotina é modelo, não
-- tarefa" do step 1.
--
-- POR QUE `tipo_acao` NÃO GANHOU O VALOR 'canal': `alter type ... add
-- value` não pode ser USADO na mesma transação em que é criado, e o
-- aplicar-sql.py manda o arquivo inteiro numa query só — o seed do
-- fim deste arquivo estouraria. A semântica ficou na coluna `bloco`:
-- ação com `bloco` não nulo é passo de abertura de canal, e o front
-- reetiqueta a partir disso.
--
--   python aplicar-sql.py sql/CORRECAO-15.sql
--
-- Idempotente: pode rodar de novo sem duplicar nada.
-- =====================================================================


-- =====================================================================
-- 1. TIPOS
-- =====================================================================

do $$ begin
  create type estagio_canal as enum
    ('ideia', 'estruturacao', 'piloto', 'operacao', 'escala', 'encerrado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type bloco_canal as enum
    ('estrutura', 'ativacao', 'motor', 'medicao', 'escala');
exception when duplicate_object then null; end $$;


-- =====================================================================
-- 2. O CANAL GANHA CICLO DE VIDA
-- =====================================================================
-- `responsavel_id` já existia e continua sendo o dono do canal.

alter table canais_venda
  add column if not exists estagio       estagio_canal not null default 'ideia',
  add column if not exists data_abertura date,
  add column if not exists publico       text,
  add column if not exists mecanica      text,
  add column if not exists cac_alvo      numeric(12,2),
  add column if not exists meta_30d      int,
  add column if not exists meta_90d      int,
  add column if not exists notas         text;

comment on column canais_venda.estagio is
  'Onde o canal está no ciclo de vida. Avança por gate (ver v_canal_saude), não por opinião.';
comment on column canais_venda.data_abertura is
  'D1 do canal. É a âncora dos prazos do plano: item com dias = -14 vence 14 dias antes daqui.';
comment on column canais_venda.publico is
  'Quem indica / de onde o lead vem. Com tamanho, não adjetivo: "base de 7.000 clientes ativos".';
comment on column canais_venda.mecanica is
  'O que o canal promete, numa frase que o indicador entende sem ler o regulamento.';
comment on column canais_venda.cac_alvo is
  'Teto de custo por venda deste canal. Serve de régua contra o CAC real de v_financeiro_kpi.';

create index if not exists idx_canais_estagio on canais_venda (estagio, ativo);


-- =====================================================================
-- 3. O PLANO PADRÃO — modelo, aplicável a qualquer canal
-- =====================================================================
-- Isto é template, não tarefa. Vale para Base de Clientes, Interno,
-- Afiliados e para o canal que ainda não existe. `tipos` restringe o
-- item a certos tipos de canal (null = serve para todos).

create table if not exists canal_plano_modelo (
  id          uuid primary key default gen_random_uuid(),
  bloco       bloco_canal not null,
  ordem       int not null default 0,
  titulo      text not null,
  criterio    text,                      -- critério de pronto: o que demonstra
  tipos       tipo_canal[],              -- null = todo canal
  obrigatorio boolean not null default true,
  dias        int not null default 0,    -- offset em dias contra data_abertura
  ativo       boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (bloco, titulo)
);

comment on table canal_plano_modelo is
  'Checklist padrão de abertura de canal. Aplicar num canal gera ações — ver canal_aplicar_plano().';
comment on column canal_plano_modelo.criterio is
  'Só marca quem consegue demonstrar funcionando, não quem "já mexeu".';
comment on column canal_plano_modelo.dias is
  'Negativo = antes do D1. Item com dias -14 e abertura em 01/09 vence em 18/08.';

create index if not exists idx_plano_bloco on canal_plano_modelo (bloco, ordem);


-- =====================================================================
-- 4. A AÇÃO PASSA A SABER QUE É PASSO DE CANAL
-- =====================================================================

alter table acoes
  add column if not exists bloco         bloco_canal,
  add column if not exists plano_item_id uuid references canal_plano_modelo (id) on delete set null,
  add column if not exists criterio      text,
  add column if not exists prova         text;

comment on column acoes.bloco is
  'Preenchido = esta ação é um passo de abertura de canal. Nulo = ação comum.';
comment on column acoes.prova is
  'Onde está a demonstração de que ficou pronto: link, print, número. Sem isto o critério é promessa.';

-- Impede aplicar o mesmo plano duas vezes no mesmo canal.
create unique index if not exists uq_acao_plano_canal
  on acoes (canal_id, plano_item_id)
  where plano_item_id is not null;

create index if not exists idx_acoes_bloco on acoes (canal_id, bloco) where bloco is not null;


-- =====================================================================
-- 5. APLICAR O PLANO
-- =====================================================================
-- Insere só o que ainda não existe no canal — rodar de novo depois de
-- acrescentar item ao modelo traz apenas o item novo. `where not
-- exists` em vez de `on conflict`: o índice é parcial, e conflito
-- sobre índice parcial exige repetir o predicado (o 42P10 que já
-- custou tempo neste banco).

create or replace function canal_aplicar_plano(
  p_canal       uuid,
  p_bloco       bloco_canal default null,
  p_responsavel uuid default null
) returns int language plpgsql as $fn$
declare
  v_abertura date;
  v_tipo     tipo_canal;
  v_dono     uuid;
  v_n        int;
begin
  select coalesce(data_abertura, current_date), tipo, responsavel_id
    into v_abertura, v_tipo, v_dono
    from canais_venda where id = p_canal;

  if not found then
    raise exception 'Canal % nao existe', p_canal;
  end if;

  insert into acoes (titulo, descricao, tipo, origem, canal_id, responsavel_id,
                     prazo, bloco, plano_item_id, criterio)
  select m.titulo,
         null,
         'campanha',            -- ver cabeçalho: o enum não ganhou 'canal'
         'manual',
         p_canal,
         coalesce(p_responsavel, v_dono),
         v_abertura + m.dias,
         m.bloco,
         m.id,
         m.criterio
    from canal_plano_modelo m
   where m.ativo
     and (p_bloco is null or m.bloco = p_bloco)
     and (m.tipos is null or v_tipo = any (m.tipos))
     and not exists (select 1 from acoes a
                      where a.canal_id = p_canal and a.plano_item_id = m.id);

  get diagnostics v_n = row_count;
  return v_n;
end $fn$;

comment on function canal_aplicar_plano(uuid, bloco_canal, uuid) is
  'Gera as ações do plano padrão para um canal. Devolve quantas criou. Seguro rodar de novo.';


-- =====================================================================
-- 6. LEITURA — onde cada canal está e o que o trava
-- =====================================================================

-- Um bloco de um canal: quanto tem, quanto fechou, quanto atrasou.
create or replace view v_canal_bloco with (security_invoker = on) as
select
  a.canal_id,
  a.bloco,
  count(*)                                                          as itens,
  count(*) filter (where a.status = 'concluida')                    as feitos,
  count(*) filter (where a.status in ('aberta', 'em_andamento')
                     and a.prazo is not null
                     and a.prazo < current_date)                    as atrasados,
  count(*) filter (where a.status in ('aberta', 'em_andamento')
                     and coalesce(m.obrigatorio, true))             as abertos_obrigatorios,
  round(100.0 * count(*) filter (where a.status = 'concluida')
        / nullif(count(*) filter (where a.status <> 'cancelada'), 0), 0) as pct
from acoes a
left join canal_plano_modelo m on m.id = a.plano_item_id
where a.bloco is not null
  and a.canal_id is not null
  and a.recorrencia = 'nenhuma'
group by 1, 2;

comment on view v_canal_bloco is
  'Progresso de cada bloco em cada canal. Item sem plano_item_id conta como obrigatório.';


-- A tela do canal em uma linha por canal.
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
   where status = 'concluida' and canal_id is not null group by 1)
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
  -- ter direito de avançar — e o que a tela cobra.
  -- Canal sem nenhum item não passa em gate nenhum: lista vazia não é
  -- lista cumprida. É o que impede "0 pendências" virar sinal verde.
  case c.estagio
    when 'ideia'        then coalesce(be.itens, 0) > 0
    when 'estruturacao' then coalesce(be.itens, 0) > 0
                          and coalesce(be.abertos_obrigatorios, 1) = 0
    when 'piloto'       then coalesce(
                              (select b.itens > 0 and b.abertos_obrigatorios = 0
                                 from v_canal_bloco b
                                where b.canal_id = c.id and b.bloco = 'ativacao'), false)
    when 'operacao'     then coalesce(rot.n, 0) > 0 and coalesce(cmp.n, 0) > 0
    when 'escala'       then true
    else true
  end                                                 as gate_ok,

  case c.estagio
    when 'ideia'        then 'Aplicar o plano de abertura'
    when 'estruturacao' then 'Alguém consegue indicar hoje e ser pago'
    when 'piloto'       then 'Primeira indicação convertida e paga'
    when 'operacao'     then 'Rotina viva e campanha no ar'
    when 'escala'       then 'Reativação rodando e próximo canal aberto'
    else                     'Encerrado'
  end                                                 as gate,

  cmp_prox.fim                                        as ultima_campanha_fim
from canais_venda c
left join usuarios u        on u.id = c.responsavel_id
left join v_canal_bloco be  on be.canal_id = c.id and be.bloco = 'estrutura'
left join rot               on rot.canal_id = c.id
left join cmp               on cmp.canal_id = c.id
left join cmp_prox          on cmp_prox.canal_id = c.id
left join mt                on mt.canal_id = c.id
left join ult               on ult.canal_id = c.id;

comment on view v_canal_saude is
  'Uma linha por canal: estágio, progresso do plano, motor rodando e o gate que falta.';


-- A fila do dia precisa saber que a ação é passo de canal, senão o
-- item de estrutura aparece rotulado como "campanha". As colunas
-- novas entram no fim — create or replace exige o prefixo idêntico.
create or replace view v_acoes_hoje with (security_invoker = on) as
select
  a.id,
  a.titulo,
  a.descricao,
  a.tipo,
  a.origem,
  a.status,
  a.prazo,
  a.urgente,
  c.nome  as canal,
  ur.nome as responsavel,
  ub.nome as travando,
  prioridade_score(a.urgente, a.prazo, a.tipo, a.bloqueia_id, current_date) as prioridade_score,
  case prioridade_score(a.urgente, a.prazo, a.tipo, a.bloqueia_id, current_date)
    when 0 then 'urgente'
    when 1 then 'atrasada'
    when 2 then 'hoje'
    when 3 then 'destrava'
    else        'proxima'
  end as prioridade,
  case when a.prazo is not null then current_date - a.prazo end as dias_de_atraso,
  a.canal_id,
  a.responsavel_id,
  a.created_at,
  a.bloco,
  a.criterio
from acoes a
left join canais_venda c on c.id = a.canal_id
left join usuarios    ur on ur.id = a.responsavel_id
left join usuarios    ub on ub.id = a.bloqueia_id
where a.status in ('aberta', 'em_andamento')
  and a.recorrencia = 'nenhuma'          -- modelos não aparecem na tela do dia
order by
  prioridade_score(a.urgente, a.prazo, a.tipo, a.bloqueia_id, current_date),
  a.prazo nulls last,
  a.created_at;


-- =====================================================================
-- 7. RLS E PERMISSÕES
-- =====================================================================
-- Sem o GRANT o login entra e a tela dá "permission denied" — a
-- armadilha que já apareceu duas vezes neste banco.

alter table canal_plano_modelo enable row level security;
drop policy if exists p_interno on canal_plano_modelo;
create policy p_interno on canal_plano_modelo for all to authenticated
  using (true) with check (true);

grant all    on canal_plano_modelo to authenticated;
grant select on v_canal_bloco, v_canal_saude to authenticated;
grant execute on function canal_aplicar_plano(uuid, bloco_canal, uuid) to authenticated;

drop trigger if exists trg_updated_at on canal_plano_modelo;
create trigger trg_updated_at before update on canal_plano_modelo
  for each row execute function set_updated_at();


-- =====================================================================
-- 8. SEED — o plano padrão de abertura de canal
-- =====================================================================
-- `dias` é contado contra a data de abertura (D1) do canal. Negativo é
-- antes do lançamento. Os prazos não são chute: saem da cadência de 90
-- dias do método FazUp.
--
-- on conflict do update: ajustar um critério aqui reflete no modelo,
-- sem tocar nas ações já geradas nos canais.

insert into canal_plano_modelo (bloco, ordem, titulo, criterio, tipos, obrigatorio, dias) values

-- ── 1. ESTRUTURA ────────────────────────────────────────────────────
('estrutura', 10, 'Dono do canal definido, com tempo alocado',
 'Nome no cadastro do canal e uma rotina semanal criada no nome dele. Canal sem dono morre — é a causa mais comum.',
 null, true, -21),

('estrutura', 20, 'Público definido com tamanho, não com adjetivo',
 'Está escrito quem pode indicar e quantos são. "A base" não vale; "7.000 clientes ativos há mais de 90 dias" vale.',
 null, true, -21),

('estrutura', 30, 'Oferta e mecânica numa frase que o indicador entende',
 'Uma frase, sem ler o regulamento: o que ele ganha, o que o indicado ganha e quando.',
 null, true, -18),

('estrutura', 40, 'A conta fecha: CAC-alvo contra margem e permanência',
 'Custo por conversão × meta do mês cabe no orçamento, e o retorno usa margem de contribuição × permanência — não receita bruta.',
 null, true, -18),

('estrutura', 50, 'Regulamento escrito, com carência e critério de desempate',
 'Documento publicado, com carência, o que não vale, acúmulo e desempate. Quem responde dúvida lê deste documento.',
 null, true, -14),

('estrutura', 60, 'Quem paga, em que sistema e em qual fatura — testado ponta a ponta',
 'Um caso real percorrido do começo ao fim: indicação → conversão → recompensa lançada → indicador vendo. Este é o item que mais mata programa de indicação.',
 null, true, -14),

('estrutura', 70, 'Rastreio: o sistema sabe quem indicou',
 'Link ou campo por indicador chegando identificado no CRM, sem alguém digitar depois. Sem isto metade do painel não existe.',
 null, true, -14),

('estrutura', 80, 'Materiais no ar: vídeo de regras, arte e página pública',
 'Links funcionando e acessíveis a quem vai indicar — não arquivo em pasta.',
 null, true, -7),

('estrutura', 90, 'Script e SLA de quem recebe o lead indicado',
 'Script no ar e prazo de primeiro contato acordado com o líder da área. Lead indicado que esfria queima o indicador junto.',
 null, true, -7),

('estrutura', 100, 'Canal cadastrado aqui, com meta de 30 e 90 dias',
 'Canal com dono, estágio, D1 e as duas metas gravadas no sistema.',
 null, true, -7),

-- ── 2. ATIVAÇÃO ─────────────────────────────────────────────────────
('ativacao', 10, 'Time treinado para receber o lead indicado',
 'Treinamento aplicado antes do D1 — e quem vai atender sabe dizer o que o indicado ganha.',
 null, true, -2),

('ativacao', 20, 'Lista da primeira leva escolhida a dedo',
 'Nomes escolhidos, não "a base toda". A primeira leva é quem você consegue acompanhar de perto.',
 null, true, -1),

('ativacao', 30, 'Comunicação de lançamento disparada',
 'Enviado, com taxa de entrega conferida. Se o disparo é pago, o custo está na conta do canal.',
 null, true, 0),

('ativacao', 40, 'Primeira indicação de cada um da primeira leva',
 'Cada pessoa da primeira leva trouxe pelo menos uma indicação em até 7 dias. Quem não trouxe, você liga.',
 null, true, 7),

('ativacao', 50, 'Primeira recompensa paga, comprovada e mostrada',
 'Comprovante em mãos e o indicador avisado. O primeiro pagamento vale 4× em retorno — e o primeiro atraso mata o canal.',
 null, true, 15),

-- ── 3. MOTOR (campanhas + rotina) ───────────────────────────────────
('motor', 10, 'Rotina semanal do canal criada como recorrente',
 'Existe ação recorrente pendurada no canal. Campanha morre no dia do fim; rotina é o que segura o canal entre elas.',
 null, true, 5),

('motor', 20, 'Ranking ou reconhecimento publicado toda semana',
 'Publicado no mesmo dia toda semana, com nome de gente. Programa sem vitrine vira programa fantasma.',
 null, true, 7),

('motor', 30, 'Calendário do ciclo com pelo menos duas campanhas',
 'Duas campanhas cadastradas no canal, com começo, fim e responsável.',
 null, true, 10),

('motor', 40, 'SLA do lead indicado conferido toda semana',
 'Alguém olha o tempo de primeiro contato dos leads indicados e cobra o que estourou.',
 null, true, 10),

('motor', 50, 'Lembrete para quem parou de indicar',
 'Rotina de reativação de quem indicou uma vez e sumiu. É mais barato que trazer indicador novo.',
 null, false, 20),

-- ── 4. MEDIÇÃO ──────────────────────────────────────────────────────
('medicao', 10, 'Funil do canal chegando no sistema por integração',
 'Leads do canal aparecendo no funil sem digitação. Se depender de alguém digitar, ninguém alimenta.',
 null, true, 20),

('medicao', 20, 'CPL, CAC e ROI do canal com número real',
 'Investimento, leads, vendas e receita do mês lançados — os indicadores saem calculados.',
 null, true, 30),

('medicao', 30, 'Veredito do ciclo: escalar, ajustar ou cortar',
 'Decisão escrita, comparada com o CAC-alvo e com os outros canais. Sem veredito, canal ruim vive para sempre.',
 null, true, 30),

-- ── 5. ESCALA ───────────────────────────────────────────────────────
('escala', 10, 'Reativação dos parados rodando sozinha',
 'Fluxo de reativação ativo e medido — quantos voltaram a indicar.',
 null, true, 45),

('escala', 20, 'Reconhecimento dos melhores com tier próprio',
 'Os melhores indicadores têm status e tratamento diferentes, e sabem disso.',
 null, false, 60),

('escala', 30, 'SOP documentado: outro alguém consegue tocar',
 'Passo a passo escrito ao ponto de o canal sobreviver à ausência do dono.',
 null, true, 60),

('escala', 40, 'Próximo canal aberto',
 'Um canal novo em estágio de estruturação, usando o que este ensinou.',
 null, false, 75)

on conflict (bloco, titulo) do update set
  criterio    = excluded.criterio,
  ordem       = excluded.ordem,
  obrigatorio = excluded.obrigatorio,
  dias        = excluded.dias,
  tipos       = excluded.tipos;


-- =====================================================================
-- 9. SEED — estágio dos canais que já existem
-- =====================================================================
-- Heurística de partida, para nenhum canal nascer em 'ideia' por
-- engano. Ajuste na tela depois: quem manda no estágio é você.
--   · inativo                           → encerrado
--   · tem rotina e campanha ativa       → operacao
--   · tem alguma das duas               → piloto
--   · não tem nada                      → estruturacao

update canais_venda c set estagio = case
  when not c.ativo then 'encerrado'::estagio_canal
  when exists (select 1 from acoes a where a.canal_id = c.id and a.recorrencia <> 'nenhuma' and a.status = 'aberta')
   and exists (select 1 from campanhas k where k.canal_id = c.id and k.status = 'ativa')
       then 'operacao'::estagio_canal
  when exists (select 1 from acoes a where a.canal_id = c.id and a.recorrencia <> 'nenhuma' and a.status = 'aberta')
    or exists (select 1 from campanhas k where k.canal_id = c.id and k.status = 'ativa')
       then 'piloto'::estagio_canal
  else 'estruturacao'::estagio_canal
end
where c.estagio = 'ideia';


-- =====================================================================
-- 10. SEED — o canal que está sendo aberto agora
-- =====================================================================
-- Indicação da base de clientes: regra dos R$ 50 + R$ 50 de desconto
-- em fatura, meta de 30 vendas no primeiro mês e 50/mês até 90 dias.
-- Materiais em `04 - Canais de Indicação/02 - Indicação Base de
-- Clientes/`.
--
-- D1 proposto: 08/09/2026 (terça). A data prevista antes já passou —
-- troque na tela se o combinado for outro, e os prazos do plano
-- acompanham no próximo "aplicar plano".

do $seed$
declare
  v_canal uuid;
  v_jr    uuid;
  v_d1    date := date '2026-09-08';
  v_n     int;
begin
  select id into v_jr from usuarios
   where nome ilike 'philipe j%' or nome ilike 'philipe%jr%'
   order by nome limit 1;

  select id into v_canal from canais_venda
   where tipo = 'base_clientes'
      or nome ilike '%base%client%'
   order by ativo desc limit 1;

  if v_canal is null then
    insert into canais_venda (nome, tipo, area)
    values ('Indicação — Base de Clientes', 'base_clientes', 'ambos')
    returning id into v_canal;
  end if;

  update canais_venda set
    estagio       = case when estagio in ('ideia', 'encerrado') then 'estruturacao'::estagio_canal else estagio end,
    data_abertura = coalesce(data_abertura, v_d1),
    publico       = coalesce(publico, 'Base de ~7.000 clientes ativos. Meta de ativar 10% (~700 indicadores).'),
    mecanica      = coalesce(mecanica, 'R$ 50 de desconto na fatura para quem indica e R$ 50 para quem é indicado, por indicação convertida. Sempre desconto em fatura — nunca PIX.'),
    cac_alvo      = coalesce(cac_alvo, 227),
    meta_30d      = coalesce(meta_30d, 30),
    meta_90d      = coalesce(meta_90d, 50),
    responsavel_id= coalesce(responsavel_id, v_jr),
    ativo         = true
  where id = v_canal;

  -- Bloco 1 inteiro, mais o bloco 2 (que já tem item vencendo antes do D1).
  v_n := canal_aplicar_plano(v_canal, 'estrutura');
  v_n := v_n + canal_aplicar_plano(v_canal, 'ativacao');
  raise notice 'Plano aplicado no canal da base: % item(ns) criado(s).', v_n;

  -- Nada nasce atrasado: item cujo offset caiu no passado vai para
  -- depois de amanhã, e a partir daí o prazo é seu.
  update acoes set prazo = current_date + 2
   where canal_id = v_canal and bloco is not null
     and status in ('aberta', 'em_andamento')
     and prazo < current_date;

  -- Os itens que são deste canal e não do modelo. Prazo 25/08/2026,
  -- a terça combinada.
  insert into acoes (titulo, tipo, origem, canal_id, responsavel_id, prazo, bloco, criterio)
  select v.titulo, 'campanha', 'manual', v_canal, v_jr, v.prazo, 'estrutura'::bloco_canal, v.criterio
  from (values
    ('Vídeo de explicação da indicação para o YouTube',
     date '2026-08-25',
     'Vídeo publicado e o link colado no manual de regras do site.'),
    ('Vídeo das regras para o site',
     date '2026-08-25',
     'Vídeo no ar na página de indicação, com a regra dos R$ 50 + R$ 50 dita em voz alta.'),
    ('Mockup da página de indicação no site',
     date '2026-08-25',
     'Mockup aprovado e pronto para virar página — com o campo que gera o link rastreável do cliente.'),
    ('Estrutura FazUp do canal',
     date '2026-08-25',
     'Os quatro blocos do checklist de criação com dono e data. Responsável: Philipe pai.'),
    ('Decidir sorteio ou mérito (ranking)',
     date '2026-08-28',
     'Decisão registrada. Se for sorteio vinculado a contratação, o certificado SECAP está protocolado — senão, o programa roda por mérito. Bloqueia a comunicação de lançamento.')
  ) as v(titulo, prazo, criterio)
  where not exists (
    select 1 from acoes a where a.canal_id = v_canal and a.titulo = v.titulo);
end $seed$;


-- =====================================================================
-- 11. CONFERÊNCIA
-- =====================================================================

select bloco, count(*) as itens_no_modelo
  from canal_plano_modelo group by bloco order by bloco;

select nome, estagio, data_abertura,
       estrutura_feitos || '/' || estrutura_itens as estrutura,
       gate
  from v_canal_saude
 order by ativo desc, nome;
