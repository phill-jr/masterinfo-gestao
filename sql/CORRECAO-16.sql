-- ═══════════════════════════════════════════════════════════════════
-- CORREÇÃO 16 — Pendência da semana, liderança e acesso por módulo
--
-- Três coisas que chegaram juntas porque se apoiam:
--
-- 1. `acoes.semana_de` — a tarefa que é DESTA SEMANA mas não tem dia
--    certo. Ela não entra em nenhum bloco do kanban (prazo fica nulo);
--    vive na faixa horizontal do topo da visão Semana. Quando ganhar
--    um dia, `prazo` é preenchido e `semana_de` limpo — vira tarefa
--    comum do bloco.
--
-- 2. `usuarios.lider_id` — quem é o líder direto de quem. É o que
--    liga o filtro "Dos meus liderados" na Rotina semanal.
--
-- 3. `usuarios.papel` + `usuarios.modulos` — o começo do sistema
--    modular. `papel` separa quem administra de quem usa; `modulos`
--    lista as telas que a pessoa enxerga (nulo = todas). A trava é
--    na interface: o menu só mostra o que a pessoa pode ver e as
--    rotas bloqueadas não abrem. O RLS continua `tem_acesso()` para
--    todos — quando houver dado sensível por papel, a política
--    aperta aqui no banco (a coluna já existe para isso).
--
-- Idempotente: pode rodar de novo sem quebrar nada.
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. Pendência da semana ─────────────────────────────────────────
alter table acoes add column if not exists semana_de date;

comment on column acoes.semana_de is
  'Segunda-feira da semana. Preenchido = pendência da semana, sem dia marcado (prazo nulo). Ao ganhar um dia, prazo é preenchido e semana_de limpo.';

-- Modelo de rotina não vira pendência de semana: pendência é tarefa.
do $$ begin
  alter table acoes add constraint acoes_pendencia_nao_e_modelo
    check (semana_de is null or recorrencia = 'nenhuma');
exception when duplicate_object then null; end $$;

create index if not exists idx_acoes_semana_de
  on acoes (semana_de) where semana_de is not null;

-- ── 2. Liderança ───────────────────────────────────────────────────
alter table usuarios add column if not exists
  lider_id uuid references usuarios (id) on delete set null;

comment on column usuarios.lider_id is
  'Líder direto. Liga o filtro "Dos meus liderados" na Rotina semanal.';

-- ── 3. Papel e módulos ─────────────────────────────────────────────
alter table usuarios add column if not exists papel text not null default 'membro';

do $$ begin
  alter table usuarios add constraint usuarios_papel_valido
    check (papel in ('admin', 'membro'));
exception when duplicate_object then null; end $$;

alter table usuarios add column if not exists modulos text[];

comment on column usuarios.papel is
  'admin = configura o sistema (time, convites, identidade, acesso); membro = usa.';
comment on column usuarios.modulos is
  'Rotas que a pessoa enxerga no menu. Nulo = todas. Admin ignora a lista.';

-- Primeira execução: quem já tem login vira admin, para ninguém se
-- trancar do lado de fora. Depois que existe um admin, não mexe mais.
update usuarios set papel = 'admin'
 where auth_user_id is not null
   and not exists (select 1 from usuarios u2 where u2.papel = 'admin');
