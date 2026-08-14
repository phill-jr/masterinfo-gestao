-- ================================================================
-- CORREÇÃO 06 — Setores e painel de métricas configurável
--
--   1. setores          — cadastro próprio, como cargos
--   2. acoes.setor_id   — a que setor a rotina pertence
--   3. metricas_painel  — quais números aparecem na Rotina semanal
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-06.sql
-- ================================================================


-- ----------------------------------------------------------------
-- 1. SETORES
-- ----------------------------------------------------------------

create table if not exists setores (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null unique,
  descricao  text,
  cor        text,                        -- hex opcional; vazio = cor derivada do nome
  ordem      int  not null default 0,
  ativo      boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table setores is
  'Setores da empresa. Classificam a rotina por área de trabalho — diferente de canal de venda.';

alter table acoes add column if not exists setor_id uuid references setores (id) on delete set null;
create index if not exists idx_acoes_setor on acoes (setor_id);

-- A ocorrência gerada herda o setor do modelo
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
    titulo, descricao, tipo, origem, status, canal_id, responsavel_id,
    bloqueia_id, prazo, acao_modelo_id, hora, tags, setor_id
  )
  select
    m.titulo, m.descricao, m.tipo, 'recorrencia', 'aberta', m.canal_id, m.responsavel_id,
    m.bloqueia_id, p_data, m.id, m.hora, m.tags, m.setor_id
  from modelos m
  on conflict (acao_modelo_id, prazo) where acao_modelo_id is not null do nothing;

  get diagnostics v_qtd = row_count;
  return v_qtd;
end $$;

grant execute on function gerar_acoes_do_dia(date) to authenticated;


-- ----------------------------------------------------------------
-- 2. PAINEL DE MÉTRICAS
-- ----------------------------------------------------------------
-- Cada linha é um cartão do painel. Em vez de um campo de fórmula
-- livre — que parece flexível e quebra calado — a métrica é montada
-- por partes: o que medir, em que período, filtrando o quê.
-- A combinação dá o mesmo alcance, e o sistema consegue validar.

create table if not exists metricas_painel (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  tipo        text not null default 'percentual'
              check (tipo in ('percentual','abertas','previstas','concluidas',
                              'dia_pico','sequencia','atrasadas')),
  periodo     text not null default 'hoje'
              check (periodo in ('hoje','semana','mes')),
  natureza    text not null default 'tudo'
              check (natureza in ('tudo','rotina','pontual')),
  escopo      text not null default 'minha'
              check (escopo in ('minha','time')),
  setor_id    uuid references setores (id) on delete set null,
  tag         text,
  meta        numeric,                    -- alvo; abaixo dele o cartão fica vermelho
  icone       text not null default 'check',
  ordem       int  not null default 0,
  ativo       boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table metricas_painel is
  'Cartões do painel da Rotina semanal. Montados por partes, não por fórmula livre.';


-- ----------------------------------------------------------------
-- 3. GATILHOS E PERMISSÕES
-- ----------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array['setores', 'metricas_painel'] loop
    execute format('drop trigger if exists trg_updated_at on %I', t);
    execute format('create trigger trg_updated_at before update on %I
                    for each row execute function set_updated_at()', t);
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_interno on %I', t);
    execute format('create policy p_interno on %I for all to authenticated
                    using (tem_acesso()) with check (tem_acesso())', t);
    execute format('grant all on %I to authenticated', t);
  end loop;
end $$;


-- ----------------------------------------------------------------
-- 4. CONTEÚDO INICIAL
-- ----------------------------------------------------------------

insert into setores (nome, descricao, ordem) values
  ('Comercial',   'Vendas, funil e relacionamento',      1),
  ('Marketing',   'Campanhas, conteúdo e tráfego',       2),
  ('Operações',   'Instalação, suporte e rede',          3),
  ('Financeiro',  'Cobrança, contas e faturamento',      4),
  ('Gestão',      'Time, indicadores e planejamento',    5)
on conflict (nome) do nothing;

-- As quatro que o Philipe pediu, na ordem em que ele descreveu
insert into metricas_painel (nome, tipo, periodo, escopo, icone, ordem, meta)
select * from (values
  ('Hoje em check',     'percentual', 'hoje',   'minha', 'check',  1, 100),
  ('Semana em check',   'percentual', 'semana', 'minha', 'chart',  2, 80),
  ('Para hoje',         'abertas',    'hoje',   'minha', 'clock',  3, null),
  ('Dia mais carregado','dia_pico',   'semana', 'minha', 'cal',    4, null)
) as s(nome, tipo, periodo, escopo, icone, ordem, meta)
where not exists (select 1 from metricas_painel);


-- ----------------------------------------------------------------
-- Conferência
-- ----------------------------------------------------------------
select (select count(*) from setores)         as setores,
       (select count(*) from metricas_painel) as metricas;
