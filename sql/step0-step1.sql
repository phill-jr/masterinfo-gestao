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
