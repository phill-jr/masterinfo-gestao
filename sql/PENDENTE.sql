-- ================================================================
-- PENDENTE — o que o banco ainda não tem
--
--   1. Cadastro de cargos            (correção 03)
--   2. Convites e acesso travado     (correção 04)
--
-- Cole tudo no SQL Editor e clique em Run. Pode rodar de novo.
-- Depois disto o sistema fica completo — nada mais pendente.
-- ================================================================

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


-- ================================================================
-- CORREÇÃO 04 — Convites, autocadastro e acesso travado
--
-- O QUE ISTO RESOLVE
-- Hoje criar um usuário exige entrar no painel do Supabase. Depois
-- disto, você cria um CONVITE dentro do próprio sistema e a pessoa
-- se cadastra sozinha pelo link.
--
-- POR QUE NÃO É A API DE ADMIN
-- Criar conta pela API exige a chave service_role, que ignora o RLS
-- inteiro. Ela não pode viver num site estático — qualquer um leria
-- o código e teria acesso total. O convite resolve sem essa chave.
--
-- COMO FICA SEGURO
-- O autocadastro cria só a conta de login. Quem não tem convite fica
-- autenticado mas NÃO enxerga nada: as políticas passam a exigir uma
-- pessoa ativa e vinculada em `usuarios`.
--
-- Cole tudo no SQL Editor e clique em Run. Pode rodar de novo.
-- ================================================================


-- ----------------------------------------------------------------
-- 1. CONVITES
-- ----------------------------------------------------------------

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


-- ----------------------------------------------------------------
-- 5. CONFERÊNCIA
-- ----------------------------------------------------------------
-- `bloqueado` deve ser false para você. Se vier true, ninguém entra —
-- rode o socorro que está comentado no fim do arquivo.

select
  (select count(*) from usuarios where auth_user_id is not null) as logins_vinculados,
  (select count(*) from convites where usado_em is null)         as convites_abertos,
  tem_acesso()                                                   as eu_tenho_acesso;


-- ================================================================
-- SOCORRO — se você se trancou para fora
-- ================================================================
-- Acontece se a sua pessoa em `usuarios` não estiver ligada ao seu
-- login, ou estiver inativa. Rode o comando abaixo trocando o e-mail.
-- O SQL Editor ignora o RLS, então ele sempre funciona.
--
-- update usuarios
-- set auth_user_id = (select id from auth.users where email = 'seu@email.com'),
--     ativo = true
-- where nome = 'Seu Nome';
