-- ================================================================
-- CORREÇÃO 25 — Organizador financeiro (Gestão da Vida)
--
-- Pedido do Philipe (12/10/26): ver o financeiro "de uma forma geral
-- mais simplificada". O extrato importado (CORREÇÃO 12) responde
-- "para onde foi o dinheiro"; o Organizador responde as perguntas
-- do dia a dia, tudo preenchido à mão:
--   · quanto eu tenho hoje         → saldo em fin_contas
--   · o que vence este mês         → fin_fixas + fin_fixas_mes
--   · quanto falta para cada meta  → fin_metas
--
-- Mesma regra da CORREÇÃO 12: privado, `dono = auth.uid()`, sem
-- exceção para administrador. Pode rodar mais de uma vez.
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-25.sql
-- ================================================================

-- ── saldo das contas ────────────────────────────────────────────
alter table fin_contas add column if not exists saldo numeric(14,2);
alter table fin_contas add column if not exists saldo_em date;

comment on column fin_contas.saldo is
  'Quanto tem na conta hoje, digitado à mão. Em cartão é a fatura em aberto (positivo) e entra subtraindo do total.';
comment on column fin_contas.saldo_em is
  'Dia em que o saldo foi atualizado — para a tela avisar quando o número envelheceu.';

-- ── contas fixas (o que repete todo mês) ────────────────────────
create table if not exists fin_fixas (
  id           uuid primary key default gen_random_uuid(),
  dono         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome         text not null,
  tipo         text not null default 'pagar' check (tipo in ('pagar','receber')),
  valor        numeric(12,2) not null default 0,
  dia          int not null default 10 check (dia between 1 and 31),
  categoria_id uuid references fin_categorias (id) on delete set null,
  ativa        boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (dono, nome)
);

comment on table fin_fixas is
  'Contas e entradas que repetem todo mês (aluguel, luz, salário). O valor é o previsto; o pago de cada mês fica em fin_fixas_mes.';

-- Uma linha por conta fixa por mês, só quando foi paga/recebida.
-- Mês sem linha = ainda em aberto. Assim virar o mês não exige nada.
create table if not exists fin_fixas_mes (
  id         uuid primary key default gen_random_uuid(),
  dono       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  fixa_id    uuid not null references fin_fixas (id) on delete cascade,
  mes        text not null check (mes ~ '^\d{4}-\d{2}$'),
  valor      numeric(12,2),
  pago_em    date not null default current_date,
  created_at timestamptz not null default now(),
  unique (dono, fixa_id, mes)
);

comment on column fin_fixas_mes.valor is
  'Quanto foi pago de fato. Nulo = o valor previsto da conta fixa.';

-- ── metas / caixinhas ───────────────────────────────────────────
create table if not exists fin_metas (
  id         uuid primary key default gen_random_uuid(),
  dono       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome       text not null,
  alvo       numeric(14,2) not null check (alvo > 0),
  guardado   numeric(14,2) not null default 0,
  prazo      date,
  cor        text,
  ordem      int not null default 100,
  concluida  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (dono, nome)
);

comment on table fin_metas is
  'Caixinhas com objetivo (reserva de emergência, viagem). Guardado é atualizado à mão.';

-- ── updated_at ──────────────────────────────────────────────────
do $$ declare t text;
begin
  foreach t in array array['fin_fixas','fin_metas'] loop
    execute format('drop trigger if exists trg_updated_at on %I', t);
    execute format('create trigger trg_updated_at before update on %I
                    for each row execute function set_updated_at()', t);
  end loop;
end $$;

-- ── RLS: só o dono ──────────────────────────────────────────────
do $$ declare t text;
begin
  foreach t in array array['fin_fixas','fin_fixas_mes','fin_metas'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_dono on %I', t);
    execute format('create policy p_dono on %I for all to authenticated
                    using (dono = auth.uid()) with check (dono = auth.uid())', t);
    execute format('grant all on %I to authenticated', t);
  end loop;
end $$;

select 'fin_fixas' as tabela, count(*) from fin_fixas
union all select 'fin_fixas_mes', count(*) from fin_fixas_mes
union all select 'fin_metas', count(*) from fin_metas;
