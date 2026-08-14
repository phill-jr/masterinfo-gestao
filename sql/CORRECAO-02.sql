-- ================================================================
-- CORREÇÃO 02 — tudo que o sistema espera e o banco ainda não tem
--
-- 1. Área do canal (Comercial / Marketing) — faz os submenus filtrarem
-- 2. Foto de perfil das pessoas
-- 3. Horário de trabalho do time
-- 4. Identidade visual: logo, cores, grafismo e nome do sistema
--
-- Cole tudo no SQL Editor e clique em Run. Pode rodar de novo.
-- ================================================================


-- ----------------------------------------------------------------
-- 0a. ÁREA DO CANAL
-- ----------------------------------------------------------------
-- É o que faz os submenus Comercial e Marketing mostrarem coisas
-- diferentes. Um canal pode servir às duas áreas ('ambos').

alter table canais_venda add column if not exists area text not null default 'ambos';

do $$ begin
  alter table canais_venda add constraint canais_area_valida
    check (area in ('comercial', 'marketing', 'ambos'));
exception when duplicate_object then null; end $$;

comment on column canais_venda.area is
  'comercial | marketing | ambos. Define em qual submenu o canal aparece.';

-- Chute inicial pelo tipo do canal. Ajuste depois na tela de canais.
update canais_venda set area = case
  when tipo in ('trafego_pago', 'organico')            then 'marketing'
  when tipo in ('outbound', 'indicacao', 'parceria')   then 'comercial'
  else 'ambos'
end
where area = 'ambos';


-- ----------------------------------------------------------------
-- 0b. FOTO DE PERFIL
-- ----------------------------------------------------------------
-- Imagem embutida (data URI). Vazio = o sistema mostra as iniciais.

alter table usuarios add column if not exists foto text;

comment on column usuarios.foto is
  'Foto de perfil embutida como data URI. Vazio = avatar com as iniciais.';

-- ----------------------------------------------------------------
-- 0c. HORÁRIO DE TRABALHO
-- ----------------------------------------------------------------
-- Uma linha por pessoa por dia da semana. Dia sem linha = folga.

create table if not exists horarios (
  id           uuid primary key default gen_random_uuid(),
  usuario_id   uuid not null references usuarios (id) on delete cascade,
  dia_semana   smallint not null check (dia_semana between 0 and 6),  -- 0 = domingo
  entrada      time not null,
  saida        time not null,
  intervalo_min int not null default 0 check (intervalo_min >= 0),
  observacao   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (usuario_id, dia_semana),
  constraint horarios_ordem check (saida > entrada)
);

comment on table horarios is
  'Escala semanal do time. Dia sem linha significa folga.';

drop trigger if exists trg_updated_at on horarios;
create trigger trg_updated_at before update on horarios
  for each row execute function set_updated_at();

alter table horarios enable row level security;
drop policy if exists p_interno on horarios;
create policy p_interno on horarios for all to authenticated using (true) with check (true);
grant all on horarios to authenticated;


-- ----------------------------------------------------------------
-- 1. IDENTIDADE VISUAL
-- ----------------------------------------------------------------

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


-- ----------------------------------------------------------------
-- Conferência — deve retornar uma linha
-- ----------------------------------------------------------------
select id, nome_sistema, accent, grafismo, tema_padrao from config_visual;
