-- ================================================================
-- CORREÇÃO 12 — Gestão Pessoal (financeiro privado)
--
-- Extrato bancário importado (OFX/CSV) e categorizado. É o único
-- módulo do sistema onde os dados NÃO são do time: aqui cada pessoa
-- enxerga só o que é dela.
--
-- Por isso a política não é tem_acesso() — é `dono = auth.uid()`.
-- Quem tem acesso ao sistema NÃO vê o extrato de ninguém, nem quem
-- administra. O dono vem do default `auth.uid()`: o front nunca
-- manda essa coluna, e o `with check` recusa se alguém tentar.
--
-- Por que não existe view de resumo aqui: view no Postgres roda com
-- os privilégios de quem a criou, então uma view de agregação
-- devolveria a soma do extrato de todo mundo. Toda a conta é feita
-- no navegador, sobre linhas que a RLS já filtrou.
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-12.sql
-- ================================================================

-- ── contas (banco, cartão, dinheiro) ────────────────────────────
create table if not exists fin_contas (
  id           uuid primary key default gen_random_uuid(),
  dono         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome         text not null,
  tipo         text not null default 'corrente'
               check (tipo in ('corrente','poupanca','cartao','dinheiro','investimento')),
  instituicao  text,
  ativa        boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (dono, nome)
);

comment on table fin_contas is
  'Contas do financeiro pessoal. Privado: cada dono só enxerga as suas.';

-- ── categorias ──────────────────────────────────────────────────
create table if not exists fin_categorias (
  id          uuid primary key default gen_random_uuid(),
  dono        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome        text not null,
  grupo       text not null default 'variavel'
              check (grupo in ('receita','fixo','variavel','divida','investimento','transferencia')),
  essencial   boolean not null default false,
  orcamento   numeric(12,2),
  cor         text,
  icone       text default 'money',
  ordem       int not null default 100,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (dono, nome)
);

comment on column fin_categorias.grupo is
  'transferencia não é gasto nem receita (PIX entre contas próprias, pagamento de fatura) — fica fora de toda soma.';
comment on column fin_categorias.essencial is
  'Separa o que você teria de pagar de qualquer jeito do que é escolha. É o corte que responde "dá para cortar quanto?".';
comment on column fin_categorias.orcamento is
  'Teto mensal em R$. Nulo = sem teto definido.';

-- ── regras aprendidas ───────────────────────────────────────────
create table if not exists fin_regras (
  id           uuid primary key default gen_random_uuid(),
  dono         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  padrao       text not null,
  categoria_id uuid not null references fin_categorias (id) on delete cascade,
  prioridade   int not null default 100,
  origem       text not null default 'manual' check (origem in ('manual','aprendida')),
  created_at   timestamptz not null default now(),
  unique (dono, padrao)
);

comment on table fin_regras is
  'Trecho procurado na descrição → categoria. As regras daqui vencem as sementes embutidas no app: quando você corrige uma categoria, a correção fica.';
comment on column fin_regras.padrao is
  'Comparado em texto minúsculo e sem acento, por "contém". Menor prioridade é testada antes.';

-- ── lançamentos ─────────────────────────────────────────────────
create table if not exists fin_lancamentos (
  id                 uuid primary key default gen_random_uuid(),
  dono               uuid not null default auth.uid() references auth.users (id) on delete cascade,
  conta_id           uuid references fin_contas (id) on delete set null,
  data               date not null,
  descricao          text not null,
  descricao_original text,
  valor              numeric(14,2) not null,
  categoria_id       uuid references fin_categorias (id) on delete set null,
  origem             text not null default 'ofx' check (origem in ('ofx','csv','manual')),
  id_externo         text,
  impressao          text not null,
  ignorado           boolean not null default false,
  observacao         text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (dono, impressao)
);

comment on column fin_lancamentos.valor is
  'Negativo é saída, positivo é entrada. Um só campo com sinal evita a dúvida eterna de qual coluna somar.';
comment on column fin_lancamentos.impressao is
  'Digital do lançamento (conta|data|valor|descrição). É o que impede o mesmo extrato de entrar duas vezes. Repetição legítima no mesmo dia ganha sufixo #1, #2 — por isso a contagem por ocorrência, e não um simples "já existe".';
comment on column fin_lancamentos.id_externo is
  'FITID do OFX quando o banco manda. Quando existe, ele vira a impressão: é identificador do próprio banco, mais confiável que qualquer digital montada por nós.';
comment on column fin_lancamentos.ignorado is
  'Fica no histórico mas sai das somas. Para estorno, duplicata do banco, lançamento que não é seu.';

create index if not exists idx_fin_lanc_dono_data on fin_lancamentos (dono, data desc);
create index if not exists idx_fin_lanc_categoria on fin_lancamentos (categoria_id);

-- ── updated_at ──────────────────────────────────────────────────
do $$ declare t text;
begin
  foreach t in array array['fin_contas','fin_categorias','fin_lancamentos'] loop
    execute format('drop trigger if exists trg_updated_at on %I', t);
    execute format('create trigger trg_updated_at before update on %I
                    for each row execute function set_updated_at()', t);
  end loop;
end $$;

-- ── RLS: só o dono, ponto ───────────────────────────────────────
-- Sem exceção para administrador. Extrato bancário não tem por que
-- ter porta dos fundos, e uma porta que existe um dia é usada.
do $$ declare t text;
begin
  foreach t in array array['fin_contas','fin_categorias','fin_regras','fin_lancamentos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_dono on %I', t);
    execute format('create policy p_dono on %I for all to authenticated
                    using (dono = auth.uid()) with check (dono = auth.uid())', t);
    execute format('grant all on %I to authenticated', t);
  end loop;
end $$;

select 'fin_contas' as tabela, count(*) from fin_contas
union all select 'fin_categorias', count(*) from fin_categorias
union all select 'fin_regras', count(*) from fin_regras
union all select 'fin_lancamentos', count(*) from fin_lancamentos;
