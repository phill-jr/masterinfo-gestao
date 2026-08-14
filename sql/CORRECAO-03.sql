-- ================================================================
-- CORREÇÃO 03 — Cadastro de cargos
--
-- Hoje o cargo é texto livre em cada pessoa, o que gera "Gestor",
-- "gestor" e "Gestor de MKT" como se fossem coisas diferentes.
-- Isto cria a tabela de cargos e liga as pessoas a ela.
--
-- Cole tudo no SQL Editor e clique em Run. Pode rodar de novo.
-- ================================================================

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


-- ----------------------------------------------------------------
-- Conferência
-- ----------------------------------------------------------------
select nome, descricao,
       (select count(*) from usuarios u where u.cargo_id = c.id) as pessoas
from cargos c order by nome;
