-- ═══════════════════════════════════════════════════════════════════
--  MÓDULO VENDEDORES — bloco 3: Avaliações
--
--  Rode depois do 01 e do 02. Pode rodar mais de uma vez.
--
--  ── A ideia ────────────────────────────────────────────────────
--  Nota geral não serve para nada: "tirou 6" não diz o que fazer.
--  Toda prova sai dividida em três eixos, e cada questão pertence a
--  exatamente um:
--
--    técnico  — entende o produto e a rede
--    vendas   — sabe conduzir o cliente
--    cultura  — sabe como a empresa trabalha e o que ela não faz
--
--  Passa quem atinge a nota geral E não fica abaixo do piso em
--  nenhum eixo. É a regra que impede o caso clássico: acerta tudo de
--  produto, zera cultura, passa na média e vira problema em três
--  meses.
--
--  ── Onde fica o gabarito ───────────────────────────────────────
--  Em tabela separada (vd_gabarito), sem política de leitura. Nem o
--  app nem o navegador conseguem ler; só as funções abaixo, que são
--  security definer.
--
--  Limite honesto: este sistema não tem papel de admin — todo mundo
--  que loga tem acesso a tudo. Então isto protege do acidente e do
--  olhar casual, não de alguém determinado com o DevTools. A
--  fronteira de verdade só existe quando `usuarios` ganhar um papel
--  (gestor/vendedor) e as funções passarem a checá-lo.
-- ═══════════════════════════════════════════════════════════════════

-- ── Configuração de cada prova ────────────────────────────────────
create table if not exists vd_avaliacoes (
  id              uuid primary key default gen_random_uuid(),
  setor_id        uuid references setores(id) on delete set null,
  nome            text not null,
  nivel           text not null default 'basico',   -- basico | avancado
  descricao       text,
  qtd_questoes    int  not null default 20,
  minutos         int  not null default 20,
  nota_minima     numeric not null default 70,      -- nota geral
  minimo_por_eixo numeric not null default 60,      -- o piso que impede passar na média
  status          text not null default 'rascunho', -- rascunho | publicada | arquivada
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ── Banco de questões ─────────────────────────────────────────────
-- Sem o gabarito: ele mora em vd_gabarito.
create table if not exists vd_questoes (
  id           uuid primary key default gen_random_uuid(),
  setor_id     uuid references setores(id) on delete set null,
  eixo         text not null,                      -- tecnico | vendas | cultura
  nivel        text not null default 'basico',
  enunciado    text not null,
  alternativas jsonb not null default '[]'::jsonb, -- [{"id":"a","texto":"…"}]
  termo_id     uuid references vd_termos(id) on delete set null,
  pop_id       uuid references vd_pops(id)   on delete set null,
  status       text not null default 'rascunho',   -- rascunho | publicada | aposentada
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists vd_questoes_pool on vd_questoes (status, nivel, eixo);

-- ── O gabarito, separado ──────────────────────────────────────────
create table if not exists vd_gabarito (
  questao_id uuid primary key references vd_questoes(id) on delete cascade,
  correta    text not null,     -- id da alternativa
  explicacao text not null      -- por que essa é a certa: é aqui que a prova ensina
);

-- ── Tentativas e respostas ────────────────────────────────────────
create table if not exists vd_tentativas (
  id           uuid primary key default gen_random_uuid(),
  avaliacao_id uuid not null references vd_avaliacoes(id) on delete cascade,
  usuario_id   uuid not null references usuarios(id) on delete cascade,
  iniciada_em  timestamptz not null default now(),
  enviada_em   timestamptz,
  nota_geral   numeric,
  nota_tecnico numeric,
  nota_vendas  numeric,
  nota_cultura numeric,
  aprovado     boolean
);

create index if not exists vd_tentativas_pessoa on vd_tentativas (usuario_id, avaliacao_id);

create table if not exists vd_respostas (
  id           uuid primary key default gen_random_uuid(),
  tentativa_id uuid not null references vd_tentativas(id) on delete cascade,
  questao_id   uuid not null references vd_questoes(id) on delete cascade,
  ordem        int not null default 0,
  resposta     text,
  correta      boolean,
  unique (tentativa_id, questao_id)
);

-- ── updated_at ────────────────────────────────────────────────────
drop trigger if exists vd_avaliacoes_touch on vd_avaliacoes;
create trigger vd_avaliacoes_touch before update on vd_avaliacoes
  for each row execute function vd_touch();

drop trigger if exists vd_questoes_touch on vd_questoes;
create trigger vd_questoes_touch before update on vd_questoes
  for each row execute function vd_touch();

-- ── RLS ───────────────────────────────────────────────────────────
alter table vd_avaliacoes enable row level security;
alter table vd_questoes   enable row level security;
alter table vd_gabarito   enable row level security;
alter table vd_tentativas enable row level security;
alter table vd_respostas  enable row level security;

drop policy if exists vd_avaliacoes_rw on vd_avaliacoes;
create policy vd_avaliacoes_rw on vd_avaliacoes for all to authenticated using (true) with check (true);

drop policy if exists vd_questoes_rw on vd_questoes;
create policy vd_questoes_rw on vd_questoes for all to authenticated using (true) with check (true);

-- vd_gabarito NÃO ganha política: sem política, a RLS nega tudo pelo
-- cliente. Só as funções security definer abaixo enxergam.

-- Cada um vê as próprias tentativas. As notas são escritas pela
-- função de correção, nunca pelo navegador.
drop policy if exists vd_tentativas_minhas on vd_tentativas;
create policy vd_tentativas_minhas on vd_tentativas for select to authenticated
  using (usuario_id in (select id from usuarios where auth_user_id = auth.uid()));

drop policy if exists vd_respostas_minhas on vd_respostas;
create policy vd_respostas_minhas on vd_respostas for select to authenticated
  using (tentativa_id in (
    select t.id from vd_tentativas t join usuarios u on u.id = t.usuario_id
    where u.auth_user_id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════════
--  FUNÇÕES DA PROVA
--  O vendedor nunca faz select em vd_gabarito. Ele passa por aqui.
-- ═══════════════════════════════════════════════════════════════════

-- Quem sou eu na tabela usuarios
create or replace function vd_eu() returns uuid
language sql stable security definer set search_path = public as $$
  select id from usuarios where auth_user_id = auth.uid() limit 1;
$$;

/* Retoma a tentativa aberta ou cria uma nova, sorteando as questões
   de forma equilibrada entre os três eixos — uma prova que caia toda
   em produto não mede cultura, e é a nota de cultura que costuma
   antecipar problema. */
create or replace function vd_iniciar_tentativa(p_avaliacao uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_eu     uuid := vd_eu();
  v_t      uuid;
  v_av     vd_avaliacoes%rowtype;
  v_por_eixo int;
  v_i      int := 0;
  r        record;
begin
  if v_eu is null then raise exception 'Seu login não está vinculado a um usuário.'; end if;
  select * into v_av from vd_avaliacoes where id = p_avaliacao;
  if not found then raise exception 'Avaliação não encontrada.'; end if;

  select id into v_t from vd_tentativas
   where avaliacao_id = p_avaliacao and usuario_id = v_eu and enviada_em is null
   limit 1;
  if v_t is not null then return v_t; end if;

  insert into vd_tentativas (avaliacao_id, usuario_id) values (p_avaliacao, v_eu)
  returning id into v_t;

  v_por_eixo := greatest(1, v_av.qtd_questoes / 3);

  for r in
    select q.id from (
      select q.*, row_number() over (partition by q.eixo order by random()) as pos
        from vd_questoes q
        join vd_gabarito g on g.questao_id = q.id
       where q.status = 'publicada' and q.nivel = v_av.nivel
         and (v_av.setor_id is null or q.setor_id is null or q.setor_id = v_av.setor_id)
    ) q
    where q.pos <= v_por_eixo
    order by random()
  loop
    v_i := v_i + 1;
    insert into vd_respostas (tentativa_id, questao_id, ordem) values (v_t, r.id, v_i);
  end loop;

  if v_i = 0 then
    delete from vd_tentativas where id = v_t;
    raise exception 'Nenhuma questão publicada para este nível. Publique questões antes de aplicar a prova.';
  end if;
  return v_t;
end $$;

-- As questões da prova, sem o gabarito.
create or replace function vd_prova(p_tentativa uuid)
returns table (questao_id uuid, ordem int, eixo text, enunciado text,
               alternativas jsonb, resposta text)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from vd_tentativas where id = p_tentativa and usuario_id = vd_eu()) then
    raise exception 'Esta tentativa não é sua.';
  end if;
  return query
    select q.id, r.ordem, q.eixo, q.enunciado, q.alternativas, r.resposta
      from vd_respostas r join vd_questoes q on q.id = r.questao_id
     where r.tentativa_id = p_tentativa
     order by r.ordem;
end $$;

-- Grava uma resposta, só enquanto a prova está aberta.
create or replace function vd_responder(p_tentativa uuid, p_questao uuid, p_resposta text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from vd_tentativas
                  where id = p_tentativa and usuario_id = vd_eu() and enviada_em is null) then
    raise exception 'Prova já enviada ou não é sua.';
  end if;
  update vd_respostas set resposta = p_resposta
   where tentativa_id = p_tentativa and questao_id = p_questao;
end $$;

/* Corrige, calcula nota geral e por eixo e aplica o piso por eixo.
   A conta é feita aqui e não no navegador — é o que impede alguém
   de "passar" mexendo no DevTools. */
create or replace function vd_enviar_tentativa(p_tentativa uuid)
returns table (nota_geral numeric, nota_tecnico numeric, nota_vendas numeric,
               nota_cultura numeric, aprovado boolean)
language plpgsql security definer set search_path = public as $$
declare
  v_av vd_avaliacoes%rowtype;
  n_ger numeric; n_tec numeric; n_ven numeric; n_cul numeric; v_ok boolean;
begin
  if not exists (select 1 from vd_tentativas
                  where id = p_tentativa and usuario_id = vd_eu() and enviada_em is null) then
    raise exception 'Prova já enviada ou não é sua.';
  end if;

  update vd_respostas r set correta = (r.resposta is not null and r.resposta = g.correta)
    from vd_gabarito g where g.questao_id = r.questao_id and r.tentativa_id = p_tentativa;

  select a.* into v_av from vd_avaliacoes a
    join vd_tentativas t on t.avaliacao_id = a.id where t.id = p_tentativa;

  select round(100.0 * count(*) filter (where r.correta) / nullif(count(*), 0), 1)
    into n_ger from vd_respostas r where r.tentativa_id = p_tentativa;

  select
    round(100.0 * count(*) filter (where r.correta and q.eixo = 'tecnico')
          / nullif(count(*) filter (where q.eixo = 'tecnico'), 0), 1),
    round(100.0 * count(*) filter (where r.correta and q.eixo = 'vendas')
          / nullif(count(*) filter (where q.eixo = 'vendas'), 0), 1),
    round(100.0 * count(*) filter (where r.correta and q.eixo = 'cultura')
          / nullif(count(*) filter (where q.eixo = 'cultura'), 0), 1)
    into n_tec, n_ven, n_cul
    from vd_respostas r join vd_questoes q on q.id = r.questao_id
   where r.tentativa_id = p_tentativa;

  -- Eixo que não caiu na prova não reprova ninguém (coalesce para o piso).
  v_ok := coalesce(n_ger, 0) >= v_av.nota_minima
      and coalesce(n_tec, v_av.minimo_por_eixo) >= v_av.minimo_por_eixo
      and coalesce(n_ven, v_av.minimo_por_eixo) >= v_av.minimo_por_eixo
      and coalesce(n_cul, v_av.minimo_por_eixo) >= v_av.minimo_por_eixo;

  update vd_tentativas set enviada_em = now(), nota_geral = n_ger,
         nota_tecnico = n_tec, nota_vendas = n_ven, nota_cultura = n_cul, aprovado = v_ok
   where id = p_tentativa;

  return query select n_ger, n_tec, n_ven, n_cul, v_ok;
end $$;

-- Revisão comentada: gabarito e explicação, só depois do envio.
create or replace function vd_revisao(p_tentativa uuid)
returns table (ordem int, eixo text, enunciado text, alternativas jsonb,
               resposta text, correta text, acertou boolean, explicacao text)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from vd_tentativas
                  where id = p_tentativa and usuario_id = vd_eu() and enviada_em is not null) then
    raise exception 'Revisão disponível só depois de enviar a prova.';
  end if;
  return query
    select r.ordem, q.eixo, q.enunciado, q.alternativas, r.resposta,
           g.correta, coalesce(r.correta, false), g.explicacao
      from vd_respostas r
      join vd_questoes q on q.id = r.questao_id
      join vd_gabarito g on g.questao_id = q.id
     where r.tentativa_id = p_tentativa
     order by r.ordem;
end $$;

-- Ler e salvar o gabarito pela tela de questões (o cliente não
-- alcança a tabela direto).
create or replace function vd_gabarito_ver(p_questao uuid)
returns table (correta text, explicacao text)
language sql stable security definer set search_path = public as $$
  select g.correta, g.explicacao from vd_gabarito g where g.questao_id = p_questao;
$$;

create or replace function vd_gabarito_salvar(p_questao uuid, p_correta text, p_explicacao text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into vd_gabarito (questao_id, correta, explicacao)
  values (p_questao, p_correta, p_explicacao)
  on conflict (questao_id) do update
    set correta = excluded.correta, explicacao = excluded.explicacao;
end $$;

revoke all on function vd_iniciar_tentativa(uuid), vd_prova(uuid), vd_responder(uuid, uuid, text),
  vd_enviar_tentativa(uuid), vd_revisao(uuid), vd_gabarito_ver(uuid),
  vd_gabarito_salvar(uuid, text, text), vd_eu() from public;
grant execute on function vd_iniciar_tentativa(uuid), vd_prova(uuid), vd_responder(uuid, uuid, text),
  vd_enviar_tentativa(uuid), vd_revisao(uuid), vd_gabarito_ver(uuid),
  vd_gabarito_salvar(uuid, text, text), vd_eu() to authenticated;

-- ═══════════════════════════════════════════════════════════════════
--  CONTEÚDO INICIAL — uma prova e seis questões de exemplo
--
--  Tudo em RASCUNHO: serve de modelo de formato, não de banco de
--  questões pronto. A meta real é 60 questões básicas, 20 por eixo.
-- ═══════════════════════════════════════════════════════════════════
do $$
declare
  v_setor uuid;
  v_q     uuid;
begin
  select id into v_setor from setores where nome ilike '%comercial%' limit 1;

  if not exists (select 1 from vd_avaliacoes where nome = 'Avaliação básica — 7 dias') then
    insert into vd_avaliacoes (setor_id, nome, nivel, descricao, qtd_questoes, minutos,
                               nota_minima, minimo_por_eixo, status)
    values (v_setor, 'Avaliação básica — 7 dias', 'basico',
      'Aplicada ao fim da primeira semana. Mede se a pessoa entendeu o essencial para atender sem errar. Passa quem faz 70 no geral e não fica abaixo de 60 em nenhum eixo.',
      20, 20, 70, 60, 'rascunho');
  end if;

  if not exists (select 1 from vd_questoes where enunciado like 'O cliente diz que a internet cai só no quarto%') then
    insert into vd_questoes (setor_id, eixo, nivel, enunciado, alternativas, status) values
    (v_setor, 'tecnico', 'basico',
     'O cliente diz que a internet cai só no quarto, e no resto da casa funciona. Onde está o problema mais provável?',
     '[{"id":"a","texto":"No link contratado — precisa subir de plano"},
       {"id":"b","texto":"No alcance do Wi-Fi dentro da casa"},
       {"id":"c","texto":"Na CTO da rua"},
       {"id":"d","texto":"No cabo drop"}]'::jsonb, 'rascunho')
    returning id into v_q;
    perform vd_gabarito_salvar(v_q, 'b',
      'Se cai só em um cômodo e no resto funciona, o link está entregando — o que não chega é o Wi-Fi. Subir o plano nesse caso é vender mais caro sem resolver, e o cliente cancela achando que foi enganado.');

    insert into vd_questoes (setor_id, eixo, nivel, enunciado, alternativas, status) values
    (v_setor, 'tecnico', 'basico',
     'O cliente trabalha em casa e reclama que a reunião trava quando ele fala. O que olhar primeiro?',
     '[{"id":"a","texto":"A velocidade de download"},
       {"id":"b","texto":"A velocidade de upload e a estabilidade"},
       {"id":"c","texto":"A quantidade de TVs na casa"},
       {"id":"d","texto":"A cor da caixa na rua"}]'::jsonb, 'rascunho')
    returning id into v_q;
    perform vd_gabarito_salvar(v_q, 'b',
      'Travar quando ele fala é o que sai dele: upload. Download alto não resolve reunião travando.');

    insert into vd_questoes (setor_id, eixo, nivel, enunciado, alternativas, status) values
    (v_setor, 'vendas', 'basico',
     'O cliente pede desconto antes de você apresentar o plano. Qual a melhor resposta?',
     '[{"id":"a","texto":"Dar o desconto máximo logo, para não perder o cliente"},
       {"id":"b","texto":"Dizer que não trabalha com desconto e encerrar o assunto"},
       {"id":"c","texto":"Entender o uso da casa primeiro e só depois falar de preço"},
       {"id":"d","texto":"Mandar a tabela completa e deixar ele escolher"}]'::jsonb, 'rascunho')
    returning id into v_q;
    perform vd_gabarito_salvar(v_q, 'c',
      'Preço sem contexto é caro por definição. Entendendo quantos aparelhos, quantos cômodos e o que ele faz online, o plano certo se justifica sozinho — e o desconto deixa de ser o único argumento.');

    insert into vd_questoes (setor_id, eixo, nivel, enunciado, alternativas, status) values
    (v_setor, 'vendas', 'basico',
     'O lead sumiu depois da proposta. O que diz a cadência do time?',
     '[{"id":"a","texto":"Esperar ele voltar quando quiser"},
       {"id":"b","texto":"3 toques por dia, nos horários oficiais, com registro no CRM"},
       {"id":"c","texto":"Ligar de hora em hora até ele atender"},
       {"id":"d","texto":"Mandar uma mensagem por semana"}]'::jsonb, 'rascunho')
    returning id into v_q;
    perform vd_gabarito_salvar(v_q, 'b',
      'A cadência é 11h, 15h e 18h, com canal variado e registro no CRM. Sem registro, o próximo que pegar o lead não sabe o que já foi tentado.');

    insert into vd_questoes (setor_id, eixo, nivel, enunciado, alternativas, status) values
    (v_setor, 'cultura', 'basico',
     'O concorrente anuncia o dobro da velocidade pelo mesmo preço e o cliente traz isso na conversa. O que fazer?',
     '[{"id":"a","texto":"Dizer que o concorrente mente"},
       {"id":"b","texto":"Falar do que a gente entrega e como isso aparece no dia a dia dele"},
       {"id":"c","texto":"Prometer cobrir qualquer oferta"},
       {"id":"d","texto":"Encerrar o atendimento"}]'::jsonb, 'rascunho')
    returning id into v_q;
    perform vd_gabarito_salvar(v_q, 'b',
      'Falar mal de concorrente entrega a conversa para ele. O que sustenta a venda é o que o cliente sente em casa: estabilidade, suporte local e o Wi-Fi funcionando onde ele usa.');

    insert into vd_questoes (setor_id, eixo, nivel, enunciado, alternativas, status) values
    (v_setor, 'cultura', 'basico',
     'Você não tem certeza se o endereço do cliente tem cobertura. O que fazer antes de fechar?',
     '[{"id":"a","texto":"Fechar e resolver depois — se não der, cancela"},
       {"id":"b","texto":"Consultar a viabilidade e confirmar o endereço completo"},
       {"id":"c","texto":"Perguntar se o vizinho tem"},
       {"id":"d","texto":"Fechar e avisar que pode não dar certo"}]'::jsonb, 'rascunho')
    returning id into v_q;
    perform vd_gabarito_salvar(v_q, 'b',
      'Vender sem viabilidade gera visita técnica perdida, prejuízo para a operação e um cliente que começa a relação frustrado. A consulta leva um minuto.');
  end if;
end $$;
