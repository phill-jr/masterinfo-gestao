-- ═══════════════════════════════════════════════════════════════════
-- CORREÇÃO 17 — Produção vira um quadro estilo Trello
--
-- As cinco colunas fixas (A criar → Publicado) viram LISTAS de
-- verdade: dá para criar, renomear, reordenar e arquivar. O cartão
-- ganha o que o Trello dá — descrição, etiquetas, membros, checklist,
-- comentários, capa, arquivo — e ordem própria dentro da lista, para
-- o arrastar e soltar ter onde gravar.
--
-- `status` não morre: cada lista pode apontar um `status_equivalente`,
-- e mover o cartão para ela sincroniza o status antigo. É o que
-- mantém vivos a capacidade da semana e os contadores do dashboard
-- sem prender o quadro às cinco colunas de antes.
--
-- Checklist e comentários em jsonb, não em tabela própria: são dados
-- do cartão, lidos e gravados sempre junto dele, por um time pequeno.
-- Se um dia precisar de busca ou relatório por item, aí sim viram
-- tabela.
--
-- Idempotente: pode rodar de novo sem quebrar nada.
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. As listas do quadro ─────────────────────────────────────────
create table if not exists producao_listas (
  id                  uuid primary key default gen_random_uuid(),
  nome                text not null,
  ordem               numeric not null default 0,
  cor                 text,
  status_equivalente  status_conteudo,   -- nulo = lista sem espelho no status antigo
  arquivada           boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

drop trigger if exists trg_updated_at on producao_listas;
create trigger trg_updated_at before update on producao_listas
  for each row execute function set_updated_at();

alter table producao_listas enable row level security;
drop policy if exists p_interno on producao_listas;
create policy p_interno on producao_listas for all to authenticated
  using (tem_acesso()) with check (tem_acesso());
grant all on producao_listas to authenticated;

-- ── 2. O cartão ganha corpo ────────────────────────────────────────
alter table producao_conteudo
  add column if not exists lista_id    uuid references producao_listas (id) on delete set null,
  add column if not exists ordem       numeric not null default 0,
  add column if not exists descricao   text,
  add column if not exists etiquetas   text[],
  add column if not exists membros     uuid[],
  add column if not exists capa        text,      -- cor de capa (#rrggbb)
  add column if not exists checklist   jsonb not null default '[]'::jsonb,
  add column if not exists comentarios jsonb not null default '[]'::jsonb,
  add column if not exists arquivado   boolean not null default false;

comment on column producao_conteudo.checklist is
  'Itens [{t: texto, ok: bool}]. Dado do cartão, vive e morre com ele.';
comment on column producao_conteudo.comentarios is
  'Comentários [{autor_id, texto, em: iso}]. Mesma lógica do checklist.';

create index if not exists idx_conteudo_lista on producao_conteudo (lista_id, ordem);

-- ── 3. Semeadura e migração, uma vez só ────────────────────────────
-- As listas iniciais espelham as colunas antigas. Só nascem se o
-- quadro estiver vazio — quem já criou as suas não ganha duplicata.
insert into producao_listas (nome, ordem, status_equivalente)
select v.nome, v.ordem, v.st::status_conteudo
from (values
  ('A criar',      1, 'a_criar'),
  ('Em produção',  2, 'em_producao'),
  ('Em validação', 3, 'em_validacao'),
  ('Validado',     4, 'validado'),
  ('Publicado',    5, 'publicado')
) as v (nome, ordem, st)
where not exists (select 1 from producao_listas);

-- Cartão antigo sem lista cai na lista do status dele.
update producao_conteudo pc
   set lista_id = l.id
  from producao_listas l
 where pc.lista_id is null
   and l.status_equivalente = pc.status;
