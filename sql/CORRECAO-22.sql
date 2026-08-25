-- =====================================================================
-- CORREÇÃO 22 — Time e POPs anexados ao canal
-- ---------------------------------------------------------------------
-- Pedido do Philipe (25/08): dentro do canal tem que ter Configuração,
-- Agenda, o time anexado e os POPs. Agenda e Configuração usam o que
-- já existe (agendamentos com canal_id e os campos do próprio canal);
-- o que falta no banco são estas duas amarrações:
--
--   canal_time  — quem opera o canal, com a função de cada um. O dono
--                 continua sendo responsavel_id em canais_venda; aqui
--                 entra o resto do time.
--   canal_pops  — os POPs do canal, apontando para a biblioteca
--                 (onb_treinamentos). É ponteiro, não cópia: o POP-06
--                 atualizado na biblioteca atualiza em todo canal que
--                 o anexou — mesmo princípio das aulas das trilhas.
--
-- Precisa de CORRECAO-13 (onb_treinamentos) já aplicada.
-- Pode rodar mais de uma vez sem duplicar nada.
-- =====================================================================

create table if not exists canal_time (
  id          uuid primary key default gen_random_uuid(),
  canal_id    uuid not null references canais_venda (id) on delete cascade,
  usuario_id  uuid not null references usuarios (id) on delete cascade,
  funcao      text,
  created_at  timestamptz not null default now(),
  unique (canal_id, usuario_id)
);

comment on table  canal_time is
  'Time do canal de venda. O dono é responsavel_id em canais_venda; aqui entram as outras pessoas, com a função que exercem NESTE canal.';
comment on column canal_time.funcao is
  'O papel da pessoa neste canal (ex.: "atende os leads", "faz o ranking semanal"). Livre de propósito: cargo é do cadastro, função é do canal.';

create index if not exists idx_canal_time_canal   on canal_time (canal_id);
create index if not exists idx_canal_time_usuario on canal_time (usuario_id);


create table if not exists canal_pops (
  id              uuid primary key default gen_random_uuid(),
  canal_id        uuid not null references canais_venda (id) on delete cascade,
  treinamento_id  uuid not null references onb_treinamentos (id) on delete cascade,
  created_at      timestamptz not null default now(),
  unique (canal_id, treinamento_id)
);

comment on table canal_pops is
  'POPs do canal: ponteiros para onb_treinamentos. Apagar o vínculo não apaga o POP da biblioteca; apagar o POP da biblioteca derruba o vínculo (cascade).';

create index if not exists idx_canal_pops_canal on canal_pops (canal_id);


-- ---------------------------------------------------------------------
-- RLS e grants — mesmo padrão da casa: todo autenticado lê e escreve.
-- Sem o GRANT o login entra e a tela dá "permission denied".
-- ---------------------------------------------------------------------

alter table canal_time enable row level security;
drop policy if exists p_interno on canal_time;
create policy p_interno on canal_time for all to authenticated
  using (true) with check (true);
grant all on canal_time to authenticated;

alter table canal_pops enable row level security;
drop policy if exists p_interno on canal_pops;
create policy p_interno on canal_pops for all to authenticated
  using (true) with check (true);
grant all on canal_pops to authenticated;
