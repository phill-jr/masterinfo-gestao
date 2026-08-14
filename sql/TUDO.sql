-- ================================================================
-- MasterInfo · Gestão de Marketing e Comercial
-- ARQUIVO ÚNICO — cole tudo no SQL Editor do Supabase e clique Run.
-- Pode rodar de novo quantas vezes quiser, não quebra nada.
-- ================================================================

-- =====================================================================
-- Sistema de Gestão de Marketing e Comercial — MasterInfo
-- Step 0 (Fundação) + Step 1 (Núcleo de ações e prioridades)
--
-- Rode este arquivo inteiro no SQL Editor do Supabase, de uma vez.
-- É idempotente: pode rodar de novo sem quebrar nada.
-- =====================================================================


-- =====================================================================
-- 0. TIPOS
-- =====================================================================

do $$ begin
  create type tipo_canal as enum (
    'organico', 'trafego_pago', 'indicacao', 'outbound', 'parceria', 'base_clientes'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_acao as enum ('rotina', 'campanha', 'pendencia_gestor');
exception when duplicate_object then null; end $$;

-- De onde a linha veio. Sem isso você não distingue o que o sistema
-- gerou sozinho do que alguém digitou.
do $$ begin
  create type origem_acao as enum ('manual', 'recorrencia', 'integracao');
exception when duplicate_object then null; end $$;

do $$ begin
  create type status_acao as enum ('aberta', 'em_andamento', 'concluida', 'cancelada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type recorrencia_acao as enum (
    'nenhuma', 'diaria', 'dias_uteis', 'semanal', 'quinzenal', 'mensal'
  );
exception when duplicate_object then null; end $$;


-- =====================================================================
-- 1. STEP 0 — TABELAS-BASE
-- =====================================================================

-- --- usuarios ---------------------------------------------------------
create table if not exists usuarios (
  id                  uuid primary key default gen_random_uuid(),
  auth_user_id        uuid unique references auth.users (id) on delete set null,
  nome                text not null,
  cargo               text,
  foto                text,          -- data URI; vazio = avatar com as iniciais
  canal_principal_id  uuid,          -- FK adicionada depois (referência circular)
  ativo               boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on column usuarios.auth_user_id is
  'Liga a pessoa ao login do Supabase Auth. Fica nulo para quem ainda não acessa o sistema.';

-- --- canais_venda -----------------------------------------------------
create table if not exists canais_venda (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null unique,
  tipo            tipo_canal not null,
  -- Define em qual submenu o canal aparece (Comercial ou Marketing)
  area            text not null default 'ambos'
                  check (area in ('comercial', 'marketing', 'ambos')),
  responsavel_id  uuid references usuarios (id) on delete set null,
  ativo           boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Fecha a referência circular usuarios -> canais_venda
do $$ begin
  alter table usuarios
    add constraint usuarios_canal_principal_fkey
    foreign key (canal_principal_id) references canais_venda (id) on delete set null;
exception when duplicate_object then null; end $$;

create index if not exists idx_canais_responsavel on canais_venda (responsavel_id);


-- =====================================================================
-- 2. STEP 1 — NÚCLEO DE AÇÕES
-- =====================================================================
-- Duas mudanças em relação ao desenho original:
--
--   1. `origem` e `concluida_em` entraram. Sem `concluida_em` você vê o
--      status atual mas não consegue medir se a rotina vem sendo cumprida.
--
--   2. `prioridade` NÃO é coluna. Prioridade que a pessoa escolhe vira
--      tudo "alta" em duas semanas. Ela é calculada na view
--      `v_acoes_hoje` a partir de prazo e bloqueio. A única alavanca
--      manual é o booleano `urgente`.
-- ---------------------------------------------------------------------

create table if not exists acoes (
  id              uuid primary key default gen_random_uuid(),
  titulo          text not null,
  descricao       text,

  tipo            tipo_acao not null,
  origem          origem_acao not null default 'manual',
  status          status_acao not null default 'aberta',

  canal_id        uuid references canais_venda (id) on delete set null,
  responsavel_id  uuid references usuarios (id) on delete set null,

  -- Para pendencia_gestor: quem está travado esperando você resolver.
  -- É isso que faz a pendência subir na fila do dia.
  bloqueia_id     uuid references usuarios (id) on delete set null,

  prazo           date,
  urgente         boolean not null default false,

  -- --- recorrência (uma ação com recorrencia <> 'nenhuma' é MODELO) ---
  recorrencia            recorrencia_acao not null default 'nenhuma',
  recorrencia_dias       int[],   -- 'semanal': 0=dom … 6=sáb. Ex: '{1,3,5}'
  recorrencia_dia_mes    int,     -- 'mensal': 1–31 (ajusta p/ fim de mês curto)
  recorrencia_inicio     date,    -- 'quinzenal': âncora da contagem de 14 dias
  acao_modelo_id         uuid references acoes (id) on delete cascade,

  concluida_em    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  -- Modelo não tem prazo próprio nem pai; ocorrência não tem recorrência.
  constraint acoes_modelo_sem_pai
    check (recorrencia = 'nenhuma' or acao_modelo_id is null),
  constraint acoes_semanal_precisa_dias
    check (recorrencia <> 'semanal' or coalesce(array_length(recorrencia_dias, 1), 0) > 0),
  constraint acoes_mensal_precisa_dia
    check (recorrencia <> 'mensal' or recorrencia_dia_mes between 1 and 31),
  constraint acoes_quinzenal_precisa_inicio
    check (recorrencia <> 'quinzenal' or recorrencia_inicio is not null),
  constraint acoes_concluida_tem_data
    check ((status = 'concluida') = (concluida_em is not null))
);

comment on table acoes is
  'Coração do sistema. Toda tarefa, rotina, pendência ou passo de campanha vive aqui. '
  'Linha com recorrencia <> nenhuma é MODELO (não aparece na tela do dia); '
  'as ocorrências geradas apontam para ela via acao_modelo_id.';

-- Evita duplicar a mesma ocorrência se a geração rodar duas vezes no dia
create unique index if not exists uq_acoes_ocorrencia
  on acoes (acao_modelo_id, prazo)
  where acao_modelo_id is not null;

create index if not exists idx_acoes_fila       on acoes (status, prazo);
create index if not exists idx_acoes_resp       on acoes (responsavel_id, status);
create index if not exists idx_acoes_canal      on acoes (canal_id, status);
create index if not exists idx_acoes_modelos    on acoes (recorrencia) where recorrencia <> 'nenhuma';


-- =====================================================================
-- 3. TRIGGERS
-- =====================================================================

-- updated_at automático
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['usuarios', 'canais_venda', 'acoes'] loop
    execute format('drop trigger if exists trg_updated_at on %I', t);
    execute format(
      'create trigger trg_updated_at before update on %I
       for each row execute function set_updated_at()', t);
  end loop;
end $$;

-- concluida_em preenchido/limpo sozinho conforme o status muda
create or replace function sync_concluida_em()
returns trigger language plpgsql as $$
begin
  if new.status = 'concluida' and new.concluida_em is null then
    new.concluida_em := now();
  elsif new.status <> 'concluida' then
    new.concluida_em := null;
  end if;
  return new;
end $$;

drop trigger if exists trg_concluida_em on acoes;
create trigger trg_concluida_em before insert or update on acoes
  for each row execute function sync_concluida_em();


-- =====================================================================
-- 4. PRIORIDADE — a regra, em um lugar só
-- =====================================================================
--   0 · urgente      → marcado na mão (escape hatch, use pouco)
--   1 · atrasada     → prazo já passou
--   2 · hoje         → vence hoje
--   3 · destrava     → pendência sua que está travando outra pessoa
--   4 · proxima      → o resto
-- ---------------------------------------------------------------------

create or replace function prioridade_score(
  p_urgente boolean, p_prazo date, p_tipo tipo_acao, p_bloqueia uuid, p_hoje date
) returns int language sql immutable as $$
  select case
    when p_urgente                                              then 0
    when p_prazo is not null and p_prazo <  p_hoje              then 1
    when p_prazo is not null and p_prazo =  p_hoje              then 2
    when p_tipo = 'pendencia_gestor' and p_bloqueia is not null then 3
    else 4
  end
$$;

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
  a.created_at
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

comment on view v_acoes_hoje is
  'A tela da manhã. Já vem ordenada: é só ler de cima para baixo.';


-- =====================================================================
-- 5. GERAÇÃO DAS ROTINAS DO DIA
-- =====================================================================
-- Chame uma vez por dia (pg_cron, Edge Function ou botão na tela).
-- Idempotente: rodar de novo no mesmo dia não duplica nada.
-- ---------------------------------------------------------------------

create or replace function gerar_acoes_do_dia(p_data date default current_date)
returns int language plpgsql as $$
declare v_qtd int;
begin
  with modelos as (
    select m.*
    from acoes m
    where m.recorrencia <> 'nenhuma'
      and m.status = 'aberta'                      -- modelo pausado = status cancelada
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
  -- O índice uq_acoes_ocorrencia é PARCIAL, então o ON CONFLICT precisa
  -- repetir o mesmo predicado para o Postgres conseguir inferi-lo.
  on conflict (acao_modelo_id, prazo) where acao_modelo_id is not null do nothing;

  get diagnostics v_qtd = row_count;
  return v_qtd;
end $$;

comment on function gerar_acoes_do_dia is
  'Cria as ocorrências do dia a partir dos modelos recorrentes. Retorna quantas criou.';


-- =====================================================================
-- 6. RLS
-- =====================================================================
-- Sistema interno, time único: qualquer usuário autenticado enxerga e
-- edita tudo. RLS fica LIGADO desde já para não virar retrabalho quando
-- houver mais de uma empresa aqui dentro.
-- ---------------------------------------------------------------------

alter table usuarios     enable row level security;
alter table canais_venda enable row level security;
alter table acoes        enable row level security;

do $$
declare t text;
begin
  foreach t in array array['usuarios', 'canais_venda', 'acoes'] loop
    execute format('drop policy if exists p_interno on %I', t);
    execute format(
      'create policy p_interno on %I for all to authenticated
       using (true) with check (true)', t);
  end loop;
end $$;


-- =====================================================================
-- 7. SEED — canais iniciais
-- =====================================================================
-- Ajuste os nomes para os canais que você realmente opera hoje.

insert into canais_venda (nome, tipo) values
  ('Tráfego Pago — Meta',      'trafego_pago'),
  ('Tráfego Pago — Google',    'trafego_pago'),
  ('Orgânico — Instagram',     'organico'),
  ('Indicação — Base Clientes','base_clientes'),
  ('Indicação — Afiliados',    'indicacao'),
  ('Outbound — Comercial',     'outbound')
on conflict (nome) do nothing;

-- =====================================================================
-- Sistema de Gestão de Marketing e Comercial — MasterInfo
-- Steps 2 a 7
--
-- PRÉ-REQUISITO: rodar antes o step0-step1.sql.
-- Rode este arquivo inteiro no SQL Editor do Supabase. É idempotente.
-- =====================================================================


-- =====================================================================
-- 0. TIPOS
-- =====================================================================

do $$ begin
  create type status_campanha as enum ('planejada', 'ativa', 'pausada', 'encerrada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type status_conteudo as enum
    ('a_criar', 'em_producao', 'em_validacao', 'validado', 'publicado', 'arquivado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_conteudo as enum ('organico', 'ativo');
exception when duplicate_object then null; end $$;

do $$ begin
  create type etapa_funil as enum
    ('lead', 'contato', 'agendamento', 'proposta', 'fechado', 'perdido');
exception when duplicate_object then null; end $$;

do $$ begin
  create type indicador_meta as enum ('vendas', 'leads', 'ativos', 'receita');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_periodo as enum ('semanal', 'mensal');
exception when duplicate_object then null; end $$;

do $$ begin
  create type status_pdi as enum ('em_andamento', 'aprovado', 'reprovado', 'cancelado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_feedback as enum
    ('um_a_um', 'corretivo', 'reconhecimento', 'avaliacao_ciclo');
exception when duplicate_object then null; end $$;


-- =====================================================================
-- 1. STEP 2 — AGENDAMENTO
-- =====================================================================
-- A ação diz O QUE fazer; o agendamento diz QUANDO. Separado porque a
-- mesma rotina pode ter horário fixo em um canal e ser livre em outro.
-- ---------------------------------------------------------------------

create table if not exists agendamentos (
  id           uuid primary key default gen_random_uuid(),
  acao_id      uuid not null references acoes (id) on delete cascade,
  canal_id     uuid references canais_venda (id) on delete set null,
  data_hora    timestamptz not null,
  duracao_min  int not null default 30 check (duracao_min > 0),
  observacao   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (acao_id, data_hora)
);

create index if not exists idx_agend_data  on agendamentos (data_hora);
create index if not exists idx_agend_canal on agendamentos (canal_id, data_hora);

create or replace view v_agenda_semana with (security_invoker = on) as
select
  ag.id,
  ag.data_hora,
  ag.duracao_min,
  ag.observacao,
  a.titulo,
  a.tipo,
  a.status,
  c.nome  as canal,
  u.nome  as responsavel,
  a.id    as acao_id
from agendamentos ag
join acoes a           on a.id = ag.acao_id
left join canais_venda c on c.id = coalesce(ag.canal_id, a.canal_id)
left join usuarios     u on u.id = a.responsavel_id
where ag.data_hora >= date_trunc('week', current_date)
  and ag.data_hora <  date_trunc('week', current_date) + interval '7 days'
order by ag.data_hora;


-- =====================================================================
-- 2. STEP 3 — CAMPANHAS E PRODUÇÃO DE CONTEÚDO
-- =====================================================================

create table if not exists campanhas (
  id                   uuid primary key default gen_random_uuid(),
  nome                 text not null,
  canal_id             uuid references canais_venda (id) on delete set null,
  objetivo             text,
  status               status_campanha not null default 'planejada',
  data_inicio          date,
  data_fim             date,
  investimento_previsto numeric(12,2),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint campanhas_periodo_valido
    check (data_fim is null or data_inicio is null or data_fim >= data_inicio)
);

create index if not exists idx_campanhas_status on campanhas (status, data_inicio);

-- Liga as rotinas de campanha à campanha que elas servem
do $$ begin
  alter table acoes
    add column campanha_id uuid references campanhas (id) on delete set null;
exception when duplicate_column then null; end $$;

create index if not exists idx_acoes_campanha on acoes (campanha_id);


-- --- produção de conteúdo --------------------------------------------
create table if not exists producao_conteudo (
  id              uuid primary key default gen_random_uuid(),
  titulo          text not null,
  tipo            tipo_conteudo not null default 'organico',
  formato         text,                     -- reel, carrossel, story, VSL…
  canal_id        uuid references canais_venda (id) on delete set null,
  campanha_id     uuid references campanhas (id) on delete set null,
  responsavel_id  uuid references usuarios (id) on delete set null,
  status          status_conteudo not null default 'a_criar',
  data_entrega    date,
  publicado_em    date,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_conteudo_status on producao_conteudo (status, data_entrega);
create index if not exists idx_conteudo_resp   on producao_conteudo (responsavel_id, status);

-- Capacidade declarada por pessoa por semana. Sem isso "o time está
-- dando conta?" vira opinião em vez de conta.
create table if not exists capacidade_producao (
  id              uuid primary key default gen_random_uuid(),
  responsavel_id  uuid not null references usuarios (id) on delete cascade,
  semana_inicio   date not null,            -- sempre a segunda-feira
  capacidade_itens int not null check (capacidade_itens >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (responsavel_id, semana_inicio)
);

create or replace view v_capacidade_semana with (security_invoker = on) as
with semana as (
  select date_trunc('week', current_date)::date as ini
)
select
  u.id                                as responsavel_id,
  u.nome                              as responsavel,
  s.ini                               as semana_inicio,
  coalesce(cap.capacidade_itens, 0)   as capacidade,
  count(pc.id) filter (
    where pc.status in ('validado', 'publicado')
  )                                   as entregue,
  count(pc.id) filter (
    where pc.status not in ('validado', 'publicado', 'arquivado')
  )                                   as em_aberto,
  coalesce(cap.capacidade_itens, 0)
    - count(pc.id) filter (where pc.status in ('validado', 'publicado')) as saldo
from usuarios u
cross join semana s
left join capacidade_producao cap
       on cap.responsavel_id = u.id and cap.semana_inicio = s.ini
left join producao_conteudo pc
       on pc.responsavel_id = u.id
      and pc.data_entrega >= s.ini
      and pc.data_entrega <  s.ini + 7
where u.ativo
group by u.id, u.nome, s.ini, cap.capacidade_itens
order by saldo;

comment on view v_capacidade_semana is
  'Capacidade declarada x entregue na semana corrente. Saldo negativo = pessoa sobrecarregada.';


-- =====================================================================
-- 3. STEP 4 — FUNIL E METAS
-- =====================================================================
-- ATENÇÃO: estas duas tabelas são ALIMENTADAS POR INTEGRAÇÃO, não por
-- formulário. O funil vive no Bitrix (ME11/ME13, funil 0) e o realizado
-- das metas vem de IXC (ativos) + Bitrix (vendas). Se alguém precisar
-- digitar lead aqui na mão, ninguém vai alimentar e o módulo morre.
-- Só `valor_meta` é digitado.
-- ---------------------------------------------------------------------

create table if not exists funil (
  id                 uuid primary key default gen_random_uuid(),
  lead               text not null,
  canal_id           uuid references canais_venda (id) on delete set null,
  responsavel_id     uuid references usuarios (id) on delete set null,
  etapa              etapa_funil not null default 'lead',
  valor_estimado     numeric(12,2),

  data_entrada       date not null default current_date,
  data_etapa         date not null default current_date,
  data_agendamento   date,
  data_fechamento    date,

  sistema_origem     text not null default 'bitrix',
  id_externo         text,                  -- ID do card no Bitrix
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (sistema_origem, id_externo)
);

create index if not exists idx_funil_etapa on funil (etapa, data_entrada);
create index if not exists idx_funil_canal on funil (canal_id, data_entrada);

comment on table funil is
  'Espelho do funil do Bitrix. Escrita esperada via integração (upsert por sistema_origem + id_externo).';

create or replace view v_funil_conversao with (security_invoker = on) as
select
  coalesce(c.nome, 'Sem canal')                       as canal,
  date_trunc('month', f.data_entrada)::date           as mes,
  count(*)                                            as leads,
  count(*) filter (where f.data_agendamento is not null) as agendou,
  count(*) filter (where f.etapa = 'fechado')         as fechou,
  count(*) filter (where f.etapa = 'perdido')         as perdeu,
  round(100.0 * count(*) filter (where f.data_agendamento is not null)
        / nullif(count(*), 0), 1)                     as tx_lead_agend,
  round(100.0 * count(*) filter (where f.etapa = 'fechado')
        / nullif(count(*) filter (where f.data_agendamento is not null), 0), 1)
                                                      as tx_agend_fech,
  round(100.0 * count(*) filter (where f.etapa = 'fechado')
        / nullif(count(*), 0), 1)                     as tx_geral,
  sum(f.valor_estimado) filter (where f.etapa = 'fechado') as receita_fechada
from funil f
left join canais_venda c on c.id = f.canal_id
group by 1, 2
order by 2 desc, 1;

comment on view v_funil_conversao is
  'Onde o lead está vazando. A menor das taxas por canal é a etapa a atacar.';


-- --- metas ------------------------------------------------------------
create table if not exists metas (
  id               uuid primary key default gen_random_uuid(),
  canal_id         uuid references canais_venda (id) on delete cascade,
  indicador        indicador_meta not null,
  tipo_periodo     tipo_periodo not null default 'mensal',
  periodo_inicio   date not null,
  periodo_fim      date not null,
  valor_meta       numeric(14,2) not null check (valor_meta > 0),
  valor_realizado  numeric(14,2) not null default 0,
  atualizado_em    timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint metas_periodo_valido check (periodo_fim >= periodo_inicio),
  unique (canal_id, indicador, periodo_inicio, tipo_periodo)
);

comment on column metas.valor_realizado is
  'NÃO digitar. Alimentado por integração (IXC = ativos, Bitrix = vendas). '
  'Carimbe atualizado_em a cada sincronização.';

create or replace view v_metas_progresso with (security_invoker = on) as
select
  m.id,
  coalesce(c.nome, 'Geral')      as canal,
  m.indicador,
  m.tipo_periodo,
  m.periodo_inicio,
  m.periodo_fim,
  m.valor_meta,
  m.valor_realizado,
  round(100.0 * m.valor_realizado / nullif(m.valor_meta, 0), 1) as pct_atingido,
  -- Quanto do período já passou. Comparar com pct_atingido diz se está
  -- no ritmo — meta em 40% no dia 25 do mês é problema, no dia 10 não é.
  round(100.0 * least(
      greatest(current_date - m.periodo_inicio, 0),
      (m.periodo_fim - m.periodo_inicio) + 1
    ) / nullif((m.periodo_fim - m.periodo_inicio) + 1, 0), 1) as pct_periodo,
  case
    when current_date > m.periodo_fim and m.valor_realizado >= m.valor_meta then 'batida'
    when current_date > m.periodo_fim                                        then 'perdida'
    when m.valor_realizado >= m.valor_meta                                   then 'batida'
    when 100.0 * m.valor_realizado / nullif(m.valor_meta, 0)
       < 100.0 * greatest(current_date - m.periodo_inicio, 0)
         / nullif((m.periodo_fim - m.periodo_inicio) + 1, 0) - 10          then 'atrasada'
    else 'no_ritmo'
  end as situacao,
  m.atualizado_em
from metas m
left join canais_venda c on c.id = m.canal_id
order by m.periodo_inicio desc, canal;


-- =====================================================================
-- 4. STEP 5 — FINANCEIRO DE MARKETING
-- =====================================================================
-- Você digita investimento, leads, vendas e receita. CAC, CPL, ticket e
-- ROI são calculados — nunca digitados.
-- ---------------------------------------------------------------------

create table if not exists financeiro_mkt (
  id             uuid primary key default gen_random_uuid(),
  canal_id       uuid not null references canais_venda (id) on delete cascade,
  periodo        date not null,             -- sempre o dia 1 do mês
  investimento   numeric(14,2) not null default 0 check (investimento >= 0),
  leads_gerados  int not null default 0 check (leads_gerados >= 0),
  vendas         int not null default 0 check (vendas >= 0),
  receita        numeric(14,2) not null default 0 check (receita >= 0),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (canal_id, periodo)
);

create or replace view v_financeiro_kpi with (security_invoker = on) as
select
  f.id,
  c.nome                                              as canal,
  c.tipo                                              as tipo_canal,
  f.periodo,
  f.investimento,
  f.leads_gerados,
  f.vendas,
  f.receita,
  round(f.investimento / nullif(f.leads_gerados, 0), 2) as cpl,
  round(f.investimento / nullif(f.vendas, 0), 2)        as cac,
  round(f.receita      / nullif(f.vendas, 0), 2)        as ticket_medio,
  round(100.0 * f.vendas / nullif(f.leads_gerados, 0), 1) as tx_conversao,
  round((f.receita - f.investimento) / nullif(f.investimento, 0), 2) as roi,
  case
    when f.investimento = 0                     then 'sem_investimento'
    when f.receita > f.investimento * 3         then 'escalar'
    when f.receita > f.investimento             then 'saudavel'
    else                                             'cortar'
  end as veredito,
  f.canal_id
from financeiro_mkt f
join canais_venda c on c.id = f.canal_id
order by f.periodo desc, roi desc nulls last;

comment on view v_financeiro_kpi is
  'CAC, CPL, ticket e ROI calculados. Veredito é sugestão grosseira: '
  'confirme contra o LTV real antes de cortar canal.';


-- =====================================================================
-- 5. STEP 6 — TIME (PDI + FEEDBACK)
-- =====================================================================
-- PDI em ciclos de 1 mês, com prova de aprovação binária e recompensa —
-- mesmo formato já usado no comercial.
-- ---------------------------------------------------------------------

create table if not exists pdi (
  id             uuid primary key default gen_random_uuid(),
  usuario_id     uuid not null references usuarios (id) on delete cascade,
  ciclo_inicio   date not null,
  ciclo_fim      date not null,
  objetivo       text not null,
  marco_atual    text,
  prova          text,                      -- o que precisa ser feito p/ aprovar
  recompensa     text,
  status         status_pdi not null default 'em_andamento',
  avaliado_em    date,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint pdi_ciclo_valido check (ciclo_fim >= ciclo_inicio),
  unique (usuario_id, ciclo_inicio)
);

create table if not exists feedbacks (
  id          uuid primary key default gen_random_uuid(),
  usuario_id  uuid not null references usuarios (id) on delete cascade,
  autor_id    uuid references usuarios (id) on delete set null,
  data        date not null default current_date,
  tipo        tipo_feedback not null default 'um_a_um',
  notas       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_feedbacks_usuario on feedbacks (usuario_id, data desc);

-- Escala semanal. Dia sem linha significa folga.
create table if not exists horarios (
  id            uuid primary key default gen_random_uuid(),
  usuario_id    uuid not null references usuarios (id) on delete cascade,
  dia_semana    smallint not null check (dia_semana between 0 and 6),  -- 0 = domingo
  entrada       time not null,
  saida         time not null,
  intervalo_min int not null default 0 check (intervalo_min >= 0),
  observacao    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (usuario_id, dia_semana),
  constraint horarios_ordem check (saida > entrada)
);

create or replace view v_time_status with (security_invoker = on) as
select
  u.id                                          as usuario_id,
  u.nome,
  u.cargo,
  c.nome                                        as canal_principal,
  p.objetivo                                    as pdi_objetivo,
  p.marco_atual                                 as pdi_marco,
  p.ciclo_fim                                   as pdi_ciclo_fim,
  case
    when p.id is null                then 'sem_pdi'
    when p.ciclo_fim < current_date  then 'ciclo_vencido'
    else 'em_dia'
  end                                           as pdi_situacao,
  f.ultimo_feedback,
  current_date - f.ultimo_feedback              as dias_sem_feedback,
  case
    when f.ultimo_feedback is null            then 'nunca'
    when current_date - f.ultimo_feedback > 30 then 'atrasado'
    when current_date - f.ultimo_feedback > 15 then 'proximo'
    else 'em_dia'
  end                                           as feedback_situacao
from usuarios u
left join canais_venda c on c.id = u.canal_principal_id
left join lateral (
  select * from pdi
  where pdi.usuario_id = u.id and pdi.status = 'em_andamento'
  order by ciclo_inicio desc limit 1
) p on true
left join lateral (
  select max(data) as ultimo_feedback from feedbacks where feedbacks.usuario_id = u.id
) f on true
where u.ativo
order by
  case when f.ultimo_feedback is null then 0 else 1 end,
  f.ultimo_feedback;

comment on view v_time_status is
  'Quem está sem feedback e quem está com ciclo de PDI vencido. Ordenado pelo mais esquecido.';


-- =====================================================================
-- 6. STEP 7 — DASHBOARD CONSOLIDADO
-- =====================================================================
-- A tela da manhã em números. Uma linha só, para carregar rápido.
-- ---------------------------------------------------------------------

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
     where situacao = 'atrasada' and periodo_fim >= current_date)          as metas_atrasadas,

  (select count(*) from v_time_status
     where feedback_situacao in ('atrasado', 'nunca'))                     as feedbacks_atrasados,

  (select count(*) from v_time_status where pdi_situacao = 'ciclo_vencido') as pdis_vencidos;

comment on view v_dashboard_dia is
  'Resumo do dia. Todo número aqui deve disparar uma ação — se não dispara, tire.';


-- =====================================================================
-- 7. TRIGGERS DE updated_at
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array[
    'agendamentos', 'campanhas', 'producao_conteudo', 'capacidade_producao',
    'funil', 'metas', 'financeiro_mkt', 'pdi', 'feedbacks', 'horarios'
  ] loop
    execute format('drop trigger if exists trg_updated_at on %I', t);
    execute format(
      'create trigger trg_updated_at before update on %I
       for each row execute function set_updated_at()', t);
  end loop;
end $$;

-- Carimba atualizado_em sempre que a integração mexer no realizado
create or replace function sync_meta_atualizada()
returns trigger language plpgsql as $$
begin
  if new.valor_realizado is distinct from old.valor_realizado then
    new.atualizado_em := now();
  end if;
  return new;
end $$;

drop trigger if exists trg_meta_atualizada on metas;
create trigger trg_meta_atualizada before update on metas
  for each row execute function sync_meta_atualizada();


-- =====================================================================
-- 8. RLS
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array[
    'agendamentos', 'campanhas', 'producao_conteudo', 'capacidade_producao',
    'funil', 'metas', 'financeiro_mkt', 'pdi', 'feedbacks', 'horarios'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_interno on %I', t);
    execute format(
      'create policy p_interno on %I for all to authenticated
       using (true) with check (true)', t);
  end loop;
end $$;


-- =====================================================================
-- 9. PRIVILÉGIOS
-- =====================================================================
-- RLS diz QUAIS LINHAS a pessoa vê. O GRANT diz se ela pode encostar na
-- tabela. São coisas diferentes e as duas precisam estar certas — sem o
-- GRANT o login entra mas toda tela dá "permission denied".
--
-- `anon` (visitante sem login) fica de fora de propósito.
-- ---------------------------------------------------------------------

grant usage on schema public to authenticated;
grant all    on all tables    in schema public to authenticated;
grant all    on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- Vale também para o que for criado daqui pra frente
alter default privileges in schema public grant all     on tables    to authenticated;
alter default privileges in schema public grant all     on sequences to authenticated;
alter default privileges in schema public grant execute on functions to authenticated;


-- =====================================================================
-- 10. IDENTIDADE VISUAL
-- =====================================================================
-- Logo, cores e grafismo do sistema. Fica no banco para valer para
-- todo o time. Editado em Configurações -> Identidade visual.
-- ---------------------------------------------------------------------

create table if not exists config_visual (
  id            smallint primary key default 1 check (id = 1),
  nome_sistema  text not null default 'MasterInfo',
  subtitulo     text default 'Gestão',
  logo_clara    text,      -- imagem embutida (data URI) para fundo branco
  logo_escura   text,      -- versão para fundo escuro
  favicon       text,      -- ícone da aba; vazio = usa a logo
  accent        text not null default 'orange',   -- preset escolhido
  accent_hex    text,                             -- cor livre, se houver
  grafismo      text not null default 'aurora',   -- aurora | malha | ondas | limpo
  tema_padrao   text not null default 'light',    -- light | dark
  updated_at    timestamptz not null default now()
);

comment on table config_visual is
  'Linha única (id = 1) com a identidade visual do sistema. '
  'Editada pela tela Configurações → Identidade visual.';

insert into config_visual (id) values (1) on conflict (id) do nothing;

drop trigger if exists trg_updated_at on config_visual;
create trigger trg_updated_at before update on config_visual
  for each row execute function set_updated_at();


-- ----------------------------------------------------------------
-- Permissões
-- ----------------------------------------------------------------
-- A tela de login precisa da logo e das cores ANTES de alguém entrar,
-- então a leitura é liberada para visitante. São dados de marca, não
-- há nada sensível aqui. Escrever, só quem está logado.

alter table config_visual enable row level security;

drop policy if exists p_ler      on config_visual;
drop policy if exists p_escrever on config_visual;

create policy p_ler      on config_visual for select to anon, authenticated using (true);
create policy p_escrever on config_visual for all    to authenticated using (true) with check (true);

grant usage  on schema public to anon;
grant select on config_visual to anon;
grant all    on config_visual to authenticated;


-- =====================================================================
-- 11. CARGOS
-- =====================================================================
-- Lista de cargos do time. Sem isto, cargo vira texto livre e o mesmo
-- papel aparece escrito de tres jeitos diferentes.
-- ---------------------------------------------------------------------

create table if not exists cargos (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null unique,
  descricao  text,
  ativo      boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table cargos is 'Lista de cargos do time. Evita cargo digitado de N jeitos diferentes.';

alter table usuarios add column if not exists cargo_id uuid references cargos (id) on delete set null;

create index if not exists idx_usuarios_cargo on usuarios (cargo_id);


-- ----------------------------------------------------------------
-- Aproveita o que já foi digitado
-- ----------------------------------------------------------------
-- Cada cargo distinto que já existe vira uma linha, e a pessoa é
-- ligada a ele. Ninguém perde o que preencheu.

insert into cargos (nome)
select distinct btrim(cargo)
from usuarios
where cargo is not null and btrim(cargo) <> ''
on conflict (nome) do nothing;

update usuarios u
set cargo_id = c.id
from cargos c
where btrim(u.cargo) = c.nome
  and u.cargo_id is null;


-- ----------------------------------------------------------------
-- Mantém o texto em sincronia
-- ----------------------------------------------------------------
-- A coluna `cargo` continua existindo e é preenchida sozinha a partir
-- do cargo escolhido. Assim as telas e views que já leem `cargo`
-- seguem funcionando sem precisar de mudança.

create or replace function sync_cargo_texto()
returns trigger language plpgsql as $$
begin
  if new.cargo_id is not null then
    select nome into new.cargo from cargos where id = new.cargo_id;
  elsif tg_op = 'UPDATE' and old.cargo_id is not null and new.cargo_id is null then
    new.cargo := null;
  end if;
  return new;
end $$;

drop trigger if exists trg_cargo_texto on usuarios;
create trigger trg_cargo_texto before insert or update on usuarios
  for each row execute function sync_cargo_texto();

-- Renomear um cargo atualiza o texto de todo mundo que o usa
create or replace function propaga_nome_cargo()
returns trigger language plpgsql as $$
begin
  if new.nome is distinct from old.nome then
    update usuarios set cargo = new.nome where cargo_id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists trg_propaga_cargo on cargos;
create trigger trg_propaga_cargo after update on cargos
  for each row execute function propaga_nome_cargo();

drop trigger if exists trg_updated_at on cargos;
create trigger trg_updated_at before update on cargos
  for each row execute function set_updated_at();


-- ----------------------------------------------------------------
-- Permissões
-- ----------------------------------------------------------------

alter table cargos enable row level security;
drop policy if exists p_interno on cargos;
create policy p_interno on cargos for all to authenticated using (true) with check (true);
grant all on cargos to authenticated;


-- ----------------------------------------------------------------
-- Sugestões iniciais (só entram se a tabela estiver vazia)
-- ----------------------------------------------------------------

insert into cargos (nome, descricao)
select * from (values
  ('Diretor',                'Responsável pela estratégia e pelo resultado geral'),
  ('Gestor de Marketing',    'Campanhas, conteúdo e tráfego'),
  ('Gestor Comercial',       'Time de vendas, funil e metas'),
  ('Consultor de Vendas',    'Atendimento, negociação e fechamento'),
  ('Analista de Marketing',  'Execução de campanhas e relatórios'),
  ('Editor de Vídeo',        'Produção e edição de conteúdo'),
  ('Designer',               'Criação e artes'),
  ('Social Media',           'Conteúdo orgânico e comunidade')
) as s(nome, descricao)
where not exists (select 1 from cargos)
on conflict (nome) do nothing;


-- =====================================================================
-- 12. CONVITES E CONTROLE DE ACESSO
-- =====================================================================

create table if not exists convites (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  nome        text,
  cargo_id    uuid references cargos (id) on delete set null,
  usuario_id  uuid references usuarios (id) on delete set null,
  criado_por  uuid references usuarios (id) on delete set null,
  expira_em   date not null default (current_date + 14),
  usado_em    timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create unique index if not exists uq_convite_aberto
  on convites (lower(email)) where usado_em is null;

comment on table convites is
  'Autorização de acesso. Sem convite válido, a pessoa até cria login mas não enxerga nada.';

drop trigger if exists trg_updated_at on convites;
create trigger trg_updated_at before update on convites
  for each row execute function set_updated_at();


-- ----------------------------------------------------------------
-- 2. QUEM TEM ACESSO
-- ----------------------------------------------------------------
-- Regra: precisa existir uma pessoa ATIVA em `usuarios` ligada ao
-- login atual.
--
-- A primeira condição é a rede de segurança da instalação: enquanto
-- NINGUÉM estiver vinculado, o sistema aceita qualquer login válido.
-- Sem isso, rodar este arquivo antes de vincular seu próprio usuário
-- trancaria você para fora do seu próprio banco.

create or replace function tem_acesso()
returns boolean
language sql stable security definer set search_path = public
as $$
  select not exists (select 1 from usuarios where auth_user_id is not null)
      or exists (select 1 from usuarios
                  where auth_user_id = auth.uid() and ativo);
$$;

grant execute on function tem_acesso() to authenticated, anon;


-- ----------------------------------------------------------------
-- 3. ACEITAR O CONVITE
-- ----------------------------------------------------------------
-- Roda com privilégio elevado (security definer) porque quem acabou
-- de se cadastrar ainda não tem acesso a nada — é justamente esta
-- função que vai lhe dar. Ela só olha o e-mail do próprio token, então
-- ninguém consegue aceitar convite alheio.

create or replace function aceitar_convite()
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_user  usuarios%rowtype;
  v_conv  convites%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'motivo', 'sem_sessao');
  end if;

  select * into v_user from usuarios where auth_user_id = v_uid;
  if found then
    return jsonb_build_object('ok', true, 'motivo', 'ja_vinculado', 'usuario_id', v_user.id);
  end if;

  select * into v_conv
  from convites
  where lower(email) = v_email
    and usado_em is null
    and (expira_em is null or expira_em >= current_date)
  order by created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'sem_convite', 'email', v_email);
  end if;

  if v_conv.usuario_id is not null then
    -- convite feito para alguém que já está cadastrado: só liga o login
    update usuarios set auth_user_id = v_uid, ativo = true
    where id = v_conv.usuario_id
    returning * into v_user;
  else
    insert into usuarios (nome, cargo_id, auth_user_id, ativo)
    values (coalesce(nullif(btrim(v_conv.nome), ''), split_part(v_email, '@', 1)),
            v_conv.cargo_id, v_uid, true)
    returning * into v_user;
  end if;

  update convites set usado_em = now(), usuario_id = v_user.id where id = v_conv.id;

  return jsonb_build_object('ok', true, 'motivo', 'convite_aceito', 'usuario_id', v_user.id);
end $$;

grant execute on function aceitar_convite() to authenticated;


-- ----------------------------------------------------------------
-- 4. TRAVA AS POLÍTICAS
-- ----------------------------------------------------------------
-- Sai o `using (true)` (qualquer autenticado) e entra `tem_acesso()`.

do $$
declare t text;
begin
  foreach t in array array[
    'usuarios', 'canais_venda', 'acoes', 'agendamentos', 'campanhas',
    'producao_conteudo', 'capacidade_producao', 'funil', 'metas',
    'financeiro_mkt', 'pdi', 'feedbacks', 'horarios', 'cargos', 'convites'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_interno on %I', t);
    execute format(
      'create policy p_interno on %I for all to authenticated
       using (tem_acesso()) with check (tem_acesso())', t);
  end loop;
end $$;

grant all on convites to authenticated;

-- A identidade visual continua legível sem login: a tela de entrada
-- precisa da logo e das cores antes de alguém entrar.
alter table config_visual enable row level security;
drop policy if exists p_ler      on config_visual;
drop policy if exists p_escrever on config_visual;
create policy p_ler      on config_visual for select to anon, authenticated using (true);
create policy p_escrever on config_visual for all    to authenticated
  using (tem_acesso()) with check (tem_acesso());
