-- =====================================================================
-- CORREÇÃO 13 — ONBOARDING E TREINAMENTOS
-- =====================================================================
-- Dois módulos que nascem juntos porque um alimenta o outro:
--
--   Treinamentos  biblioteca de conteúdo. Cada treinamento é um HTML
--                 inteiro (os que já existem nas pastas do projeto),
--                 um link ou um vídeo. Vive sozinho e pode ser aberto
--                 fora de qualquer trilha.
--
--   Onboarding    trilhas por setor. Uma trilha tem módulos, cada
--                 módulo tem aulas, e uma aula ou traz texto próprio
--                 ou aponta para um treinamento da biblioteca. No fim
--                 do módulo (ou da trilha) vem a prova.
--
-- A separação existe para o conteúdo não ficar preso à trilha: o mesmo
-- treinamento de CRM serve o Comercial e o Financeiro sem ser copiado.
--
-- Idempotente: pode rodar de novo.
--
--   python aplicar-sql.py sql/CORRECAO-13.sql
-- =====================================================================


-- =====================================================================
-- 1. BIBLIOTECA DE TREINAMENTOS
-- =====================================================================
-- `conteudo_html` guarda o arquivo inteiro, com <style> e <script>. O
-- front renderiza dentro de um iframe em sandbox, sem allow-same-origin
-- — os HTMLs internos rodam o script deles (índice lateral, barra de
-- progresso) sem enxergar a sessão do Supabase da aba de fora.
--
-- Guardar o HTML no banco e não no Storage é decisão consciente: são
-- documentos de 20 a 50 KB, versionáveis com um `update`, e assim o
-- treinamento não depende de um link assinado que expira.
-- ---------------------------------------------------------------------

create table if not exists onb_treinamentos (
  id            uuid primary key default gen_random_uuid(),
  titulo        text not null,
  descricao     text,
  setor_id      uuid references setores (id) on delete set null,
  tipo          text not null default 'html'
                  check (tipo in ('html', 'link', 'video')),
  conteudo_html text,
  url           text,
  duracao_min   int,
  tags          text[] default '{}',
  ordem         int default 0,
  ativo         boolean default true,
  criado_em     timestamptz default now(),
  atualizado_em timestamptz default now()
);

create index if not exists ix_trein_setor on onb_treinamentos (setor_id);


-- =====================================================================
-- 2. TRILHAS, MÓDULOS E AULAS
-- =====================================================================
-- `setor_id` nulo = trilha da casa inteira (boas-vindas, cultura). É o
-- que aparece no bloco "Toda a empresa" da tela de trilhas.
-- ---------------------------------------------------------------------

create table if not exists onb_trilhas (
  id           uuid primary key default gen_random_uuid(),
  setor_id     uuid references setores (id) on delete set null,
  nome         text not null,
  descricao    text,
  icone        text default 'book',
  duracao_dias int,
  ordem        int default 0,
  ativo        boolean default true,
  criado_em    timestamptz default now()
);

create table if not exists onb_modulos (
  id        uuid primary key default gen_random_uuid(),
  trilha_id uuid not null references onb_trilhas (id) on delete cascade,
  titulo    text not null,
  resumo    text,
  ordem     int default 0,
  ativo     boolean default true
);

-- Uma aula é uma das três coisas, nesta ordem de precedência no front:
--   treinamento_id  abre o HTML da biblioteca
--   url             abre um link externo
--   conteudo        texto escrito na própria aula (markdown leve)
create table if not exists onb_aulas (
  id             uuid primary key default gen_random_uuid(),
  modulo_id      uuid not null references onb_modulos (id) on delete cascade,
  titulo         text not null,
  resumo         text,
  conteudo       text,
  treinamento_id uuid references onb_treinamentos (id) on delete set null,
  url            text,
  duracao_min    int,
  obrigatoria    boolean default true,
  ordem          int default 0,
  ativo          boolean default true
);

create index if not exists ix_onb_mod_trilha on onb_modulos (trilha_id, ordem);
create index if not exists ix_onb_aula_mod   on onb_aulas   (modulo_id, ordem);


-- =====================================================================
-- 3. PROVAS
-- =====================================================================
-- `modulo_id` nulo = prova final da trilha. Com módulo, é a prova
-- daquele módulo e trava o avanço se `bloqueia` estiver ligado.
--
-- `tentativas_max = 0` significa ilimitado. Não usei null para isso
-- porque "sem limite" e "não preenchido" viram a mesma coisa e alguém
-- acaba lendo errado.
-- ---------------------------------------------------------------------

create table if not exists onb_provas (
  id             uuid primary key default gen_random_uuid(),
  trilha_id      uuid not null references onb_trilhas (id) on delete cascade,
  modulo_id      uuid references onb_modulos (id) on delete cascade,
  titulo         text not null,
  descricao      text,
  nota_corte     int default 70 check (nota_corte between 0 and 100),
  tentativas_max int default 3  check (tentativas_max >= 0),
  embaralhar     boolean default true,
  ativo          boolean default true,
  ordem          int default 0
);

create table if not exists onb_questoes (
  id         uuid primary key default gen_random_uuid(),
  prova_id   uuid not null references onb_provas (id) on delete cascade,
  enunciado  text not null,
  tipo       text not null default 'multipla' check (tipo in ('multipla', 'vf')),
  explicacao text,
  peso       int default 1 check (peso > 0),
  ordem      int default 0
);

create table if not exists onb_alternativas (
  id         uuid primary key default gen_random_uuid(),
  questao_id uuid not null references onb_questoes (id) on delete cascade,
  texto      text not null,
  correta    boolean default false,
  ordem      int default 0
);

create index if not exists ix_onb_q_prova on onb_questoes    (prova_id, ordem);
create index if not exists ix_onb_a_q     on onb_alternativas (questao_id, ordem);


-- =====================================================================
-- 4. MATRÍCULA E PROGRESSO
-- =====================================================================

create table if not exists onb_matriculas (
  id           uuid primary key default gen_random_uuid(),
  trilha_id    uuid not null references onb_trilhas (id) on delete cascade,
  usuario_id   uuid not null references usuarios (id)   on delete cascade,
  status       text default 'em_andamento'
                 check (status in ('em_andamento', 'concluida', 'trancada')),
  iniciada_em  date default current_date,
  prazo        date,
  concluida_em date,
  criado_em    timestamptz default now(),
  unique (trilha_id, usuario_id)
);

create table if not exists onb_progresso (
  id           uuid primary key default gen_random_uuid(),
  matricula_id uuid not null references onb_matriculas (id) on delete cascade,
  aula_id      uuid not null references onb_aulas (id)      on delete cascade,
  concluida_em timestamptz default now(),
  unique (matricula_id, aula_id)
);

-- Uma linha por tentativa, nunca sobrescrita: o histórico de quem
-- refez a prova três vezes é o dado mais útil que existe aqui.
create table if not exists onb_tentativas (
  id           uuid primary key default gen_random_uuid(),
  matricula_id uuid references onb_matriculas (id) on delete cascade,
  prova_id     uuid not null references onb_provas (id) on delete cascade,
  usuario_id   uuid not null references usuarios (id)   on delete cascade,
  nota         numeric(5,2),
  acertos      int,
  total        int,
  aprovado     boolean,
  respostas    jsonb,
  feita_em     timestamptz default now()
);

create index if not exists ix_onb_prog_mat on onb_progresso  (matricula_id);
create index if not exists ix_onb_tent_uq  on onb_tentativas (usuario_id, prova_id, feita_em desc);


-- =====================================================================
-- 5. QUEM SOU EU
-- =====================================================================
-- O front conhece o `usuarios.id` da pessoa logada, mas as funções
-- abaixo não podem confiar nele — vem do cliente. Aqui a identidade sai
-- sempre do token.

create or replace function onb_eu()
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from usuarios where auth_user_id = auth.uid() limit 1;
$$;


-- =====================================================================
-- 6. MATRICULAR
-- =====================================================================
-- Idempotente de propósito: o front chama isto toda vez que alguém
-- abre uma trilha pelo botão "Começar". Chamar duas vezes devolve a
-- mesma matrícula em vez de estourar o unique.

create or replace function onb_matricular(p_trilha_id uuid, p_usuario_id uuid default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_user uuid := coalesce(p_usuario_id, onb_eu());
  v_id   uuid;
begin
  if v_user is null then
    raise exception 'Sem usuário vinculado ao login. Cadastre a pessoa em Time e ligue o auth_user_id.';
  end if;

  insert into onb_matriculas (trilha_id, usuario_id)
  values (p_trilha_id, v_user)
  on conflict (trilha_id, usuario_id) do update set status = onb_matriculas.status
  returning id into v_id;

  return v_id;
end $$;


-- =====================================================================
-- 7. CORRIGIR A PROVA
-- =====================================================================
-- A nota é calculada no banco e não no navegador. Sem isto qualquer um
-- com o console aberto grava "nota 100, aprovado" direto na tabela — e
-- de fato o front NÃO tem permissão de inserir em onb_tentativas (ver
-- seção 9). A única porta é esta função.
--
-- Limite honesto do que isto protege: como o sistema ainda não tem
-- papéis (todo mundo logado é administrador), `onb_alternativas.correta`
-- continua legível pela API por quem souber procurar. Ou seja: a prova
-- é confiável contra erro e contra a chutação, não contra alguém
-- decidido a colar. O dia que existir uma coluna `papel` em `usuarios`,
-- o conserto é revogar o select da coluna `correta` para quem não for
-- gestor — a função aqui já não depende disso.
--
-- p_respostas: { "<questao_id>": "<alternativa_id>", ... }
-- Devolve o resultado E o gabarito comentado, para a tela de correção.

create or replace function onb_corrigir(p_prova_id uuid, p_respostas jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_user     uuid := onb_eu();
  v_prova    onb_provas%rowtype;
  v_mat      uuid;
  v_feitas   int;
  v_peso_tot int  := 0;
  v_peso_ok  int  := 0;
  v_acertos  int  := 0;
  v_total    int  := 0;
  v_nota     numeric(5,2);
  v_aprov    boolean;
  v_gab      jsonb := '[]'::jsonb;
  r          record;
begin
  if v_user is null then
    raise exception 'Sem usuário vinculado ao login.';
  end if;

  select * into v_prova from onb_provas where id = p_prova_id and ativo;
  if not found then
    raise exception 'Prova não encontrada ou inativa.';
  end if;

  select id into v_mat from onb_matriculas
   where trilha_id = v_prova.trilha_id and usuario_id = v_user;
  if v_mat is null then
    v_mat := onb_matricular(v_prova.trilha_id, v_user);
  end if;

  -- O limite de tentativas vale aqui, não no botão da tela.
  if v_prova.tentativas_max > 0 then
    select count(*) into v_feitas from onb_tentativas
     where prova_id = p_prova_id and usuario_id = v_user;
    if v_feitas >= v_prova.tentativas_max then
      raise exception 'Limite de % tentativa(s) atingido nesta prova.', v_prova.tentativas_max;
    end if;
  end if;

  for r in
    select q.id, q.enunciado, q.peso, q.explicacao,
           (select a.id   from onb_alternativas a
             where a.questao_id = q.id and a.correta order by a.ordem limit 1) as certa_id,
           (select a.texto from onb_alternativas a
             where a.questao_id = q.id and a.correta order by a.ordem limit 1) as certa_txt
      from onb_questoes q
     where q.prova_id = p_prova_id
     order by q.ordem, q.id
  loop
    declare
      v_marcada uuid := nullif(p_respostas ->> r.id::text, '')::uuid;
      v_ok      boolean := v_marcada is not null and v_marcada = r.certa_id;
    begin
      v_total    := v_total + 1;
      v_peso_tot := v_peso_tot + r.peso;
      if v_ok then
        v_acertos := v_acertos + 1;
        v_peso_ok := v_peso_ok + r.peso;
      end if;

      v_gab := v_gab || jsonb_build_object(
        'questao_id',  r.id,
        'enunciado',   r.enunciado,
        'acertou',     v_ok,
        'marcada_id',  v_marcada,
        'correta_id',  r.certa_id,
        'correta_txt', r.certa_txt,
        'explicacao',  r.explicacao);
    end;
  end loop;

  if v_peso_tot = 0 then
    raise exception 'Esta prova ainda não tem questões.';
  end if;

  v_nota  := round(v_peso_ok * 100.0 / v_peso_tot, 2);
  v_aprov := v_nota >= v_prova.nota_corte;

  insert into onb_tentativas (matricula_id, prova_id, usuario_id, nota, acertos, total, aprovado, respostas)
  values (v_mat, p_prova_id, v_user, v_nota, v_acertos, v_total, v_aprov, p_respostas);

  return jsonb_build_object(
    'nota',       v_nota,
    'acertos',    v_acertos,
    'total',      v_total,
    'aprovado',   v_aprov,
    'nota_corte', v_prova.nota_corte,
    'gabarito',   v_gab);
end $$;


-- =====================================================================
-- 8. VIEWS
-- =====================================================================

-- Uma linha por trilha, com o tamanho dela já contado. É o que a tela
-- de blocos por setor precisa sem varrer aula por aula no navegador.
create or replace view v_onb_trilhas as
select t.id,
       t.setor_id,
       s.nome  as setor,
       s.ordem as setor_ordem,
       t.nome,
       t.descricao,
       t.icone,
       t.duracao_dias,
       t.ordem,
       t.ativo,
       (select count(*) from onb_modulos m
         where m.trilha_id = t.id and m.ativo)                       as modulos,
       (select count(*) from onb_aulas a
          join onb_modulos m on m.id = a.modulo_id
         where m.trilha_id = t.id and m.ativo and a.ativo)           as aulas,
       -- as que travam a conclusão; o resto é material de referência
       (select count(*) from onb_aulas a
          join onb_modulos m on m.id = a.modulo_id
         where m.trilha_id = t.id and m.ativo and a.ativo
           and a.obrigatoria)                                        as aulas_req,
       (select coalesce(sum(a.duracao_min), 0) from onb_aulas a
          join onb_modulos m on m.id = a.modulo_id
         where m.trilha_id = t.id and m.ativo and a.ativo)           as minutos,
       (select count(*) from onb_provas p
         where p.trilha_id = t.id and p.ativo)                       as provas,
       (select count(*) from onb_matriculas mt
         where mt.trilha_id = t.id)                                  as matriculados,
       (select count(*) from onb_matriculas mt
         where mt.trilha_id = t.id and mt.status = 'concluida')      as concluidas
  from onb_trilhas t
  left join setores s on s.id = t.setor_id;

-- Uma linha por matrícula: quem está em qual trilha, quanto andou e
-- se passou nas provas. Alimenta o painel de acompanhamento e a barra
-- de progresso da própria pessoa.
--
-- Só aula OBRIGATÓRIA entra na conta. Material de referência — os POPs,
-- o documento original da trilha — é aula opcional, e uma barra que
-- exige ler os doze POPs para chegar a 100% empurra a pessoa a marcar
-- tudo sem ler. O que trava a conclusão é o que a trilha exige.
create or replace view v_onb_matriculas as
with base as (
  select mt.id,
         mt.trilha_id,
         mt.usuario_id,
         mt.status,
         mt.iniciada_em,
         mt.prazo,
         mt.concluida_em,
         (select count(*) from onb_aulas a
            join onb_modulos m on m.id = a.modulo_id
           where m.trilha_id = mt.trilha_id and m.ativo and a.ativo
             and a.obrigatoria)                                       as aulas_total,
         (select count(*) from onb_progresso pg
            join onb_aulas a  on a.id = pg.aula_id
            join onb_modulos m on m.id = a.modulo_id
           where pg.matricula_id = mt.id and m.ativo and a.ativo
             and a.obrigatoria)                                       as aulas_feitas,
         (select count(*) from onb_provas p
           where p.trilha_id = mt.trilha_id and p.ativo)              as provas_total,
         (select count(distinct tt.prova_id) from onb_tentativas tt
            join onb_provas p on p.id = tt.prova_id
           where tt.usuario_id = mt.usuario_id and tt.aprovado
             and p.trilha_id = mt.trilha_id and p.ativo)              as provas_ok,
         greatest(
           coalesce((select max(pg.concluida_em) from onb_progresso pg
                      where pg.matricula_id = mt.id), mt.criado_em),
           coalesce((select max(tt.feita_em) from onb_tentativas tt
                      where tt.matricula_id = mt.id), mt.criado_em)
         )                                                            as ultima_atividade
    from onb_matriculas mt
)
select b.*,
       u.nome  as pessoa,
       u.foto,
       u.cargo,
       u.ativo as pessoa_ativa,
       t.nome  as trilha,
       t.setor_id,
       s.nome  as setor,
       case when b.aulas_total = 0 then 0
            else round(b.aulas_feitas * 100.0 / b.aulas_total) end    as pct_aulas,
       case when (b.aulas_total + b.provas_total) = 0 then 0
            else round((b.aulas_feitas + b.provas_ok) * 100.0
                       / (b.aulas_total + b.provas_total)) end        as pct,
       (b.aulas_feitas >= b.aulas_total and b.provas_ok >= b.provas_total
        and b.aulas_total > 0)                                        as completa,
       extract(day from now() - b.ultima_atividade)::int              as dias_parado
  from base b
  join usuarios     u on u.id = b.usuario_id
  join onb_trilhas  t on t.id = b.trilha_id
  left join setores s on s.id = t.setor_id;

-- Cartões do topo da tela de onboarding.
create or replace view v_onb_painel as
select (select count(*) from onb_trilhas where ativo)                            as trilhas,
       (select count(*) from onb_matriculas where status = 'em_andamento')       as em_andamento,
       (select count(*) from onb_matriculas where status = 'concluida')          as concluidas,
       (select count(*) from v_onb_matriculas
         where status = 'em_andamento' and dias_parado >= 7)                     as parados,
       (select count(*) from onb_treinamentos where ativo)                       as treinamentos;

-- A biblioteca sem o HTML junto. Uma listagem de 30 treinamentos não
-- pode arrastar 1,5 MB de markup para desenhar 30 cartões.
create or replace view v_onb_treinamentos as
select t.id, t.titulo, t.descricao, t.setor_id, s.nome as setor,
       t.tipo, t.url, t.duracao_min, t.tags, t.ordem, t.ativo,
       t.criado_em, t.atualizado_em,
       length(coalesce(t.conteudo_html, ''))                          as tamanho,
       (select count(*) from onb_aulas a where a.treinamento_id = t.id) as usos
  from onb_treinamentos t
  left join setores s on s.id = t.setor_id;


-- =====================================================================
-- 9. RLS E PRIVILÉGIOS
-- =====================================================================
-- Mesmo desenho do resto do sistema: quem está logado enxerga tudo.
-- A exceção é onb_tentativas, que só aceita escrita pela função de
-- correção — o motivo está na seção 7.
-- ---------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'onb_treinamentos', 'onb_trilhas', 'onb_modulos', 'onb_aulas',
    'onb_provas', 'onb_questoes', 'onb_alternativas',
    'onb_matriculas', 'onb_progresso', 'onb_tentativas']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_interno on %I', t);
  end loop;

  foreach t in array array[
    'onb_treinamentos', 'onb_trilhas', 'onb_modulos', 'onb_aulas',
    'onb_provas', 'onb_questoes', 'onb_alternativas',
    'onb_matriculas', 'onb_progresso']
  loop
    execute format(
      'create policy p_interno on %I for all to authenticated
       using (true) with check (true)', t);
  end loop;
end $$;

-- Tentativa: lê quem está logado, escreve só a função (security definer).
create policy p_interno on onb_tentativas for select to authenticated using (true);

grant all    on onb_treinamentos, onb_trilhas, onb_modulos, onb_aulas,
                onb_provas, onb_questoes, onb_alternativas,
                onb_matriculas, onb_progresso        to authenticated;
revoke all   on onb_tentativas from authenticated;
grant select on onb_tentativas to authenticated;

grant select on v_onb_trilhas, v_onb_matriculas, v_onb_painel, v_onb_treinamentos
  to authenticated;

grant execute on function onb_eu()                       to authenticated;
grant execute on function onb_matricular(uuid, uuid)     to authenticated;
grant execute on function onb_corrigir(uuid, jsonb)      to authenticated;


-- =====================================================================
-- 10. CARIMBO DE ATUALIZAÇÃO
-- =====================================================================
-- Um treinamento revisado sem data de revisão é um treinamento que
-- ninguém sabe se está velho.

create or replace function onb_toca_treinamento()
returns trigger language plpgsql as $$
begin
  new.atualizado_em := now();
  return new;
end $$;

drop trigger if exists tg_onb_treinamento on onb_treinamentos;
create trigger tg_onb_treinamento before update on onb_treinamentos
  for each row execute function onb_toca_treinamento();


-- =====================================================================
-- 11. FECHAMENTO AUTOMÁTICO DA MATRÍCULA
-- =====================================================================
-- Concluir a última aula fecha a trilha sozinho. Deixar isso na mão de
-- alguém significa painel cheio de "em andamento" que já acabou.

create or replace function onb_fecha_matricula()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_m uuid := new.matricula_id;
begin
  if v_m is null then return new; end if;
  update onb_matriculas mt
     set status = 'concluida', concluida_em = current_date
   from v_onb_matriculas v
  where mt.id = v_m and v.id = mt.id
    and v.completa and mt.status = 'em_andamento';
  return new;
end $$;

drop trigger if exists tg_onb_progresso on onb_progresso;
create trigger tg_onb_progresso after insert on onb_progresso
  for each row execute function onb_fecha_matricula();

drop trigger if exists tg_onb_tentativa on onb_tentativas;
create trigger tg_onb_tentativa after insert on onb_tentativas
  for each row when (new.aprovado) execute function onb_fecha_matricula();


-- =====================================================================
-- Conferência
-- =====================================================================
select 'onb_trilhas'      as tabela, count(*) from onb_trilhas
union all select 'onb_treinamentos', count(*) from onb_treinamentos
union all select 'onb_matriculas',   count(*) from onb_matriculas;
