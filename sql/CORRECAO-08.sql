-- ================================================================
-- CORREÇÃO 08 — Anotações
--
-- Bloco de notas do gestor: observação sobre alguém do time, ideia
-- que apareceu, decisão de reunião. Coisas que hoje moram no
-- WhatsApp consigo mesmo e somem.
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-08.sql
-- ================================================================

create table if not exists anotacoes (
  id          uuid primary key default gen_random_uuid(),
  titulo      text,
  conteudo    text not null,
  categoria   text not null default 'geral'
              check (categoria in ('geral','time','feedback','ideia','reuniao','decisao','alerta')),
  usuario_id  uuid references usuarios (id) on delete set null,  -- sobre quem é
  autor_id    uuid references usuarios (id) on delete set null,  -- quem escreveu
  fixada      boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table anotacoes is
  'Bloco de notas. usuario_id = sobre quem a nota fala; autor_id = quem escreveu.';
comment on column anotacoes.fixada is
  'Fixada aparece no topo, fora da ordem cronológica.';

create index if not exists idx_anotacoes_data    on anotacoes (created_at desc);
create index if not exists idx_anotacoes_usuario on anotacoes (usuario_id);

drop trigger if exists trg_updated_at on anotacoes;
create trigger trg_updated_at before update on anotacoes
  for each row execute function set_updated_at();

alter table anotacoes enable row level security;
drop policy if exists p_interno on anotacoes;
create policy p_interno on anotacoes for all to authenticated
  using (tem_acesso()) with check (tem_acesso());
grant all on anotacoes to authenticated;

select count(*) as anotacoes from anotacoes;
