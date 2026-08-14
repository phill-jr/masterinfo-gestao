-- ═══════════════════════════════════════════════════════════════════
--  MÓDULO VENDEDORES — instalação completa
--  (dicionário + onboarding + avaliações)
--
--  Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
--  É a junção dos três arquivos numerados, na ordem certa.
--
--  Pode ser rodado de novo sem duplicar nada.
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
--  MÓDULO VENDEDORES — bloco 1: Dicionário da Casa
--
--  Rode este arquivo inteiro no SQL Editor do Supabase deste projeto
--  (o mesmo que está em config.js). Pode rodar mais de uma vez: tudo
--  é "if not exists" / "create or replace".
--
--  O que ele cria:
--    vd_termos               — os verbetes
--    vd_buscas_sem_resultado — o que procuraram e não acharam
--
--  Segurança: mesmo padrão das outras tabelas de empresa deste
--  sistema — quem está logado lê e escreve; quem não está, não vê
--  nada. O campo `status` é fluxo de trabalho (rascunho → publicado),
--  não é controle de acesso.
-- ═══════════════════════════════════════════════════════════════════

create extension if not exists pg_trgm;

-- ── Verbetes ──────────────────────────────────────────────────────
create table if not exists vd_termos (
  id            uuid primary key default gen_random_uuid(),
  termo         text not null,
  sinonimos     text,           -- separados por vírgula; é o que faz achar com escrita errada
  categoria     text not null default 'tecnico',   -- tecnico | produto | processo | comercial | cultura
  nivel         text not null default 'basico',    -- basico | avancado
  explicacao    text not null,
  cliente_chama text,           -- como o CLIENTE chama isso
  explicar_ao_cliente text,     -- a frase pronta, do jeito que pode ser dita numa ligação
  cuidado       text,           -- o erro comum do vendedor novo, e o que acontece quando erra
  status        text not null default 'rascunho',  -- rascunho | publicado | arquivado
  autor_id      uuid references usuarios(id) on delete set null,
  revisado_em   date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create unique index if not exists vd_termos_unico   on vd_termos (lower(termo));
create index        if not exists vd_termos_trgm    on vd_termos using gin (termo gin_trgm_ops);
create index        if not exists vd_termos_sin_trgm on vd_termos using gin (coalesce(sinonimos,'') gin_trgm_ops);
create index        if not exists vd_termos_status  on vd_termos (status);

-- updated_at sem depender do frontend
create or replace function vd_touch() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists vd_termos_touch on vd_termos;
create trigger vd_termos_touch before update on vd_termos
  for each row execute function vd_touch();

-- ── Buscas sem resultado ──────────────────────────────────────────
-- A lista mais honesta do que falta escrever: veio de dúvida real.
create table if not exists vd_buscas_sem_resultado (
  id         uuid primary key default gen_random_uuid(),
  texto      text not null,
  usuario_id uuid references usuarios(id) on delete set null,
  resolvido  boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists vd_buscas_data on vd_buscas_sem_resultado (created_at desc);

-- ── RLS ───────────────────────────────────────────────────────────
alter table vd_termos               enable row level security;
alter table vd_buscas_sem_resultado enable row level security;

drop policy if exists vd_termos_rw on vd_termos;
create policy vd_termos_rw on vd_termos
  for all to authenticated using (true) with check (true);

drop policy if exists vd_buscas_rw on vd_buscas_sem_resultado;
create policy vd_buscas_rw on vd_buscas_sem_resultado
  for all to authenticated using (true) with check (true);

-- ── Conteúdo inicial ──────────────────────────────────────────────
-- Cinco verbetes em RASCUNHO, como modelo de formato. Ninguém vê como
-- material oficial até alguém revisar e publicar.
insert into vd_termos (termo, sinonimos, categoria, nivel, explicacao,
                       cliente_chama, explicar_ao_cliente, cuidado, status)
values
('Viabilidade', 'viabilidade técnica, tem viabilidade, viabilidade de instalação', 'processo', 'basico',
 'Consulta que diz se o endereço do cliente pode ser atendido pela nossa rede: se existe caixa (CTO) por perto e se ela tem porta livre.',
 'O cliente pergunta "vocês atendem aqui na minha rua?".',
 'Vou confirmar se a nossa fibra já chega no seu endereço. É rápido, só preciso do endereço completo com número.',
 'Vender sem consultar viabilidade. O contrato entra, o técnico vai até o local, não instala, e a visita perdida sai do bolso da operação — além do cliente começar a relação com uma frustração.',
 'rascunho'),

('FTTH', 'fibra até a casa, fiber to the home, fibra pura, 100% fibra', 'tecnico', 'basico',
 'Fibra óptica que entra dentro da casa do cliente, sem trecho de cabo metálico no caminho. É o que sustenta a promessa de sinal estável.',
 'O cliente chama de "fibra" ou "internet a laser".',
 'A fibra entra dentro da sua casa, não para no poste. Por isso o sinal não oscila quando chove nem cai no horário de pico.',
 'Falar "FTTH" com o cliente. A sigla não significa nada para ele — o que significa é "não cai quando chove".',
 'rascunho'),

('ONU', 'onu, modem da fibra, caixinha da fibra, ont', 'tecnico', 'basico',
 'O aparelho instalado na casa do cliente que recebe a fibra e entrega a internet. Em muitos casos é ele também que faz o Wi-Fi.',
 'O cliente chama de "modem", "roteador" ou "a caixinha de vocês".',
 'É o aparelho que fica na sua casa recebendo a fibra. Ele é nosso e fica com você enquanto o plano estiver ativo.',
 'Prometer troca de aparelho por conta própria. Troca tem regra — confirme antes de falar qualquer coisa para o cliente.',
 'rascunho'),

('Wi-Fi mesh', 'mesh, repetidor, wifi na casa toda, roteador secundário', 'produto', 'basico',
 'Segundo roteador que trabalha junto com o principal e espalha o mesmo Wi-Fi pela casa, sem o cliente precisar trocar de rede ao andar de um cômodo para outro.',
 'O cliente diz "não pega no quarto" ou "quero internet no fundo da casa".',
 'A gente coloca um segundo ponto de Wi-Fi na parte da casa onde o sinal não chega. É a mesma rede, o celular não precisa trocar.',
 'Vender mais velocidade para quem tem problema de alcance. O cliente paga mais caro, o Wi-Fi continua fraco no fundo da casa, e ele cancela achando que foi enganado.',
 'rascunho'),

('Upload x download', 'upload, download, subida e descida, banda simétrica', 'tecnico', 'basico',
 'Download é o que chega até o cliente (assistir, baixar). Upload é o que sai dele (chamada de vídeo, enviar arquivo, câmera de segurança). Quem trabalha em casa sente mais o upload.',
 'O cliente diz "minha reunião trava" ou "a câmera fica falhando".',
 'Reunião travando quase nunca é a velocidade de descida — é a de subida. É nela que a gente precisa olhar no seu caso.',
 'Ouvir "reunião travando" e oferecer o plano mais caro. Antes de subir o plano, entenda se o problema é upload, Wi-Fi ou o aparelho do cliente.',
 'rascunho')
on conflict do nothing;


-- ═══════════════════════════════════════════════════════════════════
--  MÓDULO VENDEDORES — bloco 2: Onboarding (trilhas, POPs e fluxos)
--
--  Rode no SQL Editor do Supabase deste projeto, depois do
--  vendedores-01-dicionario.sql. Pode rodar mais de uma vez.
--
--  ── Por que tudo tem setor_id ──────────────────────────────────
--  A empresa tem 14 setores e o comercial é um deles. Se o onboarding
--  nascer preso ao comercial, cada setor novo vira uma cópia do
--  código. Aqui trilha, POP e fluxo pertencem a um setor; a tela
--  filtra por setor e a estrutura é a mesma para todos.
--  setor_id nulo = vale para a empresa inteira (ex.: POP de cultura).
--
--  O que cria:
--    vd_trilhas          — uma trilha por setor (ex.: Trilha do Calouro)
--    vd_trilha_etapas    — o dia a dia: estudar, fazer, comprovar
--    vd_trilha_progresso — o que cada pessoa já concluiu
--    vd_pops             — os procedimentos operacionais padrão
--    vd_fluxos           — os fluxos do setor (funil, cadência, handoff)
-- ═══════════════════════════════════════════════════════════════════

-- ── Trilhas ───────────────────────────────────────────────────────
create table if not exists vd_trilhas (
  id         uuid primary key default gen_random_uuid(),
  setor_id   uuid references setores(id) on delete set null,
  nome       text not null,
  descricao  text,
  duracao_dias int,
  status     text not null default 'rascunho',   -- rascunho | publicada | arquivada
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists vd_trilha_etapas (
  id          uuid primary key default gen_random_uuid(),
  trilha_id   uuid not null references vd_trilhas(id) on delete cascade,
  dia         int  not null,
  titulo      text not null,
  foco        text,          -- o que a pessoa estuda
  tarefa      text,          -- o que ela faz
  comprovacao text,          -- o que prova que fez
  conduz      text,          -- quem conduz: Gestor, Líder, Time (buddy)
  pops        text,          -- códigos de POP ligados, separados por vírgula
  ordem       int  not null default 0
);

create index if not exists vd_etapas_trilha on vd_trilha_etapas (trilha_id, dia, ordem);

-- Uma linha por etapa concluída. Sem linha = não concluída.
create table if not exists vd_trilha_progresso (
  id           uuid primary key default gen_random_uuid(),
  etapa_id     uuid not null references vd_trilha_etapas(id) on delete cascade,
  usuario_id   uuid not null references usuarios(id) on delete cascade,
  concluida_em timestamptz not null default now(),
  observacao   text,
  unique (etapa_id, usuario_id)
);

-- ── POPs ──────────────────────────────────────────────────────────
create table if not exists vd_pops (
  id             uuid primary key default gen_random_uuid(),
  setor_id       uuid references setores(id) on delete set null,
  codigo         text not null,          -- POP-01, POP-02…
  titulo         text not null,
  resumo         text,
  conteudo       text,                   -- o procedimento em si
  versao         text default '1',
  responsavel_id uuid references usuarios(id) on delete set null,
  revisado_em    date,
  status         text not null default 'a_receber',  -- a_receber | rascunho | publicado | arquivado
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create unique index if not exists vd_pops_codigo on vd_pops (lower(codigo));

-- ── Fluxos ────────────────────────────────────────────────────────
-- `etapas` é uma lista ordenada: [{"nome":"Lead","detalhe":"..."}]
create table if not exists vd_fluxos (
  id         uuid primary key default gen_random_uuid(),
  setor_id   uuid references setores(id) on delete set null,
  nome       text not null,
  tipo       text not null default 'processo',  -- processo | cadencia | handoff | atendimento
  descricao  text,
  etapas     jsonb not null default '[]'::jsonb,
  observacao text,
  status     text not null default 'rascunho',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── updated_at por trigger ────────────────────────────────────────
-- vd_touch() vem do vendedores-01-dicionario.sql
drop trigger if exists vd_trilhas_touch on vd_trilhas;
create trigger vd_trilhas_touch before update on vd_trilhas
  for each row execute function vd_touch();

drop trigger if exists vd_pops_touch on vd_pops;
create trigger vd_pops_touch before update on vd_pops
  for each row execute function vd_touch();

drop trigger if exists vd_fluxos_touch on vd_fluxos;
create trigger vd_fluxos_touch before update on vd_fluxos
  for each row execute function vd_touch();

-- ── RLS ───────────────────────────────────────────────────────────
alter table vd_trilhas          enable row level security;
alter table vd_trilha_etapas    enable row level security;
alter table vd_trilha_progresso enable row level security;
alter table vd_pops             enable row level security;
alter table vd_fluxos           enable row level security;

drop policy if exists vd_trilhas_rw on vd_trilhas;
create policy vd_trilhas_rw on vd_trilhas for all to authenticated using (true) with check (true);

drop policy if exists vd_etapas_rw on vd_trilha_etapas;
create policy vd_etapas_rw on vd_trilha_etapas for all to authenticated using (true) with check (true);

drop policy if exists vd_progresso_rw on vd_trilha_progresso;
create policy vd_progresso_rw on vd_trilha_progresso for all to authenticated using (true) with check (true);

drop policy if exists vd_pops_rw on vd_pops;
create policy vd_pops_rw on vd_pops for all to authenticated using (true) with check (true);

drop policy if exists vd_fluxos_rw on vd_fluxos;
create policy vd_fluxos_rw on vd_fluxos for all to authenticated using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════
--  CONTEÚDO INICIAL — setor Comercial
--
--  Vem do documento "Contexto — Onboarding Comercial MasterInfo"
--  (08/07/2026). O que lá está marcado como pendente entra aqui como
--  pendente, e não como texto inventado: dias 6–7 e 11–15 ainda não
--  foram definidos, e os 12 POPs ainda não foram recebidos.
--
--  O setor é buscado pelo nome. Se não existir um setor "Comercial"
--  cadastrado, tudo entra com setor nulo (= empresa inteira) e pode
--  ser ajustado pela tela.
-- ═══════════════════════════════════════════════════════════════════
do $$
declare
  v_setor  uuid;
  v_trilha uuid;
begin
  select id into v_setor from setores where nome ilike '%comercial%' limit 1;

  -- ── Trilha do Calouro ───────────────────────────────────────────
  select id into v_trilha from vd_trilhas where nome = 'Trilha do Calouro' limit 1;

  if v_trilha is null then
    insert into vd_trilhas (setor_id, nome, descricao, duracao_dias, status)
    values (v_setor, 'Trilha do Calouro',
      'Leva o vendedor novo de zero a produtivo em 15 dias. É treinamento e período de avaliação ao mesmo tempo: no Dia 15 a liderança decide entre efetivação e desligamento. Teste prático e teórico todos os dias.',
      15, 'rascunho')
    returning id into v_trilha;

    insert into vd_trilha_etapas (trilha_id, dia, titulo, foco, tarefa, comprovacao, conduz, pops, ordem) values
    (v_trilha, 1, 'Imersão, produtos e ferramentas',
     'Quem é a MasterInfo, os 14 setores, planos e produtos, CRM e ferramentas do time.',
     'Receber todos os acessos e navegar no CRM com o líder.',
     'Teste do dia 1.', 'Gestor · Líder', 'POP-01, POP-02, POP-04, POP-05', 1),

    (v_trilha, 2, 'Cadastro, viabilidade e scripts',
     'Como se cadastra um cliente, como se consulta viabilidade e os scripts de atendimento.',
     'Já começa a cadastrar — a prática arranca junto com a teoria.',
     'Teste do dia 2 e primeiros cadastros de treino.', 'Líder · Time', 'POP-06, POP-07, POP-08', 2),

    (v_trilha, 3, 'Origens de lead, organização e rotina',
     'De onde vêm os leads, como o time se organiza e qual é a rotina do dia.',
     'Montar a própria rotina do dia seguindo o padrão do time.',
     'Teste do dia 3.', 'Líder', 'POP-09, POP-10, POP-01', 3),

    (v_trilha, 4, 'Role-play e fluxo da venda',
     'O fluxo comercial de ponta a ponta.',
     'Role-play de script e ligação, mais cadastros.',
     'Teste do dia 4 e role-play avaliado.', 'Líder · Time', 'POP-06, POP-08, POP-11', 4),

    (v_trilha, 5, 'Shadowing',
     'Dia inteiro acompanhando um vendedor experiente.',
     'Observar atendimentos reais do começo ao fim.',
     'Teste do dia 5 e registro do que observou.', 'Time (buddy)', 'POP-08, POP-11', 5),

    (v_trilha, 6, 'A definir',
     'Tema ainda não definido. Provável continuação: shadowing, cadastros e scripts.',
     null, null, 'Time (buddy)', null, 6),

    (v_trilha, 7, 'A definir',
     'Tema ainda não definido. Provável continuação: shadowing, cadastros e scripts.',
     null, null, 'Time (buddy)', null, 7),

    (v_trilha, 8, 'Começa a atender (assistido)',
     'Follow-up e cadência: 3 toques por dia, às 11h, 15h e 18h.',
     'Atender a fase "Em Contato" com acompanhamento.',
     'Teste do dia 8 e registros no CRM.', 'Líder · Time', 'POP-12', 8),

    (v_trilha, 9, 'Qualificar e fazer handoff',
     'Qualificação do lead e passagem para a etapa seguinte.',
     'Atender "Em Contato" e conduzir o handoff.',
     'Teste-chave do dia 9: qualificar e fazer handoff.', 'Líder · Time', null, 9),

    (v_trilha, 10, 'Entra na fila',
     'Operação real, supervisionada.',
     'Atender a fila junto com o time.',
     'Registros do dia no CRM.', 'Time (buddy)', null, 10),

    (v_trilha, 11, 'A definir', 'Operação assistida — detalhamento pendente.', null, null, 'Time (buddy)', null, 11),
    (v_trilha, 12, 'A definir', 'Operação assistida — detalhamento pendente.', null, null, 'Time (buddy)', null, 12),
    (v_trilha, 13, 'A definir', 'Operação assistida — detalhamento pendente.', null, null, 'Time (buddy)', null, 13),
    (v_trilha, 14, 'A definir', 'Operação assistida — detalhamento pendente.', null, null, 'Time (buddy)', null, 14),

    (v_trilha, 15, 'Avaliação final e decisão',
     'Os 5 pilares: conhecimento técnico, execução, comportamento, cultura e disponibilidade/evolução.',
     'Fechar o checklist de efetivação: treinamentos concluídos, ~15 cadastros aprovados, domínio de CRM e produtos, fluxo comercial entendido, testes práticos aprovados.',
     'Avaliação consolidada pela Líder e decisão do Gestor: efetivação ou desligamento.',
     'Gestor · Líder', null, 15);
  end if;

  -- ── Os 12 POPs ──────────────────────────────────────────────────
  insert into vd_pops (setor_id, codigo, titulo, resumo, status) values
  (v_setor, 'POP-01', 'Imersão na Empresa',      'História, missão, visão, comportamentos e o fluxo entre os setores.', 'a_receber'),
  (v_setor, 'POP-02', 'Planos e Produtos',       'Tabela de planos, valores e a recomendação por perfil de cliente.',   'a_receber'),
  (v_setor, 'POP-03', 'Conhecimento Técnico',    'CTO, drop, rede própria x neutra, viabilidade, mesh, Wi-Fi 2.4/5 GHz, Wi-Fi 6 e equipamentos.', 'a_receber'),
  (v_setor, 'POP-04', 'CRM e Funil',             'Estágios, fontes e motivos de descartado e perdido.',                 'a_receber'),
  (v_setor, 'POP-05', 'Ferramentas',             'Bitrix24, Erika, IXC Soft, WhatsApp Business e EraCloud.',            'a_receber'),
  (v_setor, 'POP-06', 'Cadastro de Cliente',     'Atendimento, cobertura (XC), MapSales, crédito, revisão, assinatura e agendamento.', 'a_receber'),
  (v_setor, 'POP-07', 'Consulta de Viabilidade', 'XC e InMap, cores de caixa, rede neutra (grupos SIM/UT), raio de 700–800 m.', 'a_receber'),
  (v_setor, 'POP-08', 'Scripts de Atendimento',  'O que falar em cada momento do atendimento.',                         'a_receber'),
  (v_setor, 'POP-09', 'Marketing e Origens',     'De onde vêm os leads.',                                              'a_receber'),
  (v_setor, 'POP-10', 'Organização',             'Como o vendedor organiza o próprio dia.',                            'a_receber'),
  (v_setor, 'POP-11', 'Processo Comercial',      'O fluxo de ponta a ponta, validado no Bitrix24.',                    'a_receber'),
  (v_setor, 'POP-12', 'Follow-up e Cadência',    '3 toques por dia às 11h, 15h e 18h. Regra dos 3 dias, com o dia 3 como ultimato.', 'a_receber')
  on conflict (lower(codigo)) do nothing;

  -- ── Fluxos ──────────────────────────────────────────────────────
  if not exists (select 1 from vd_fluxos where nome = 'Funil de ponta a ponta') then
    insert into vd_fluxos (setor_id, nome, tipo, descricao, etapas, observacao, status) values
    (v_setor, 'Funil de ponta a ponta', 'processo',
     'Do tráfego até a ativação. O lead passa pela Erika (IA/SDR) antes de chegar ao vendedor humano.',
     '[{"nome":"Tráfego / Marketing","detalhe":"Origem do lead — ver POP-09"},
       {"nome":"Funil da Erika (IA)","detalhe":"Primeiro contato e qualificação"},
       {"nome":"Funil de negócio","detalhe":"Time comercial humano assume"},
       {"nome":"Ativação","detalhe":"Cliente instalado e ativo"}]'::jsonb,
     'Validado no Bitrix24. Detalhamento em POP-11 e POP-04.', 'rascunho'),

    (v_setor, 'Detalhamento operacional da venda', 'processo',
     'O mesmo funil visto pelo que o vendedor faz em cada etapa.',
     '[{"nome":"Lead","detalhe":"Chega pela Erika ou pelo receptivo"},
       {"nome":"Atendimento","detalhe":"Primeiro contato humano"},
       {"nome":"Negociação","detalhe":"Plano recomendado por perfil — POP-02"},
       {"nome":"Cadastro","detalhe":"Cobertura, crédito e revisão — POP-06"},
       {"nome":"Assinatura","detalhe":"Contrato fechado"},
       {"nome":"Instalação","detalhe":"Agendamento e visita técnica"},
       {"nome":"Ativação","detalhe":"Cliente no ar"}]'::jsonb,
     null, 'rascunho'),

    (v_setor, 'Cadência de follow-up', 'cadencia',
     '3 toques por dia, nos horários oficiais. Cada toque tem checklist próprio.',
     '[{"nome":"11h — 1º toque","detalhe":"Ligação, mensagem, vídeo ou áudio — sempre com registro no CRM"},
       {"nome":"15h — 2º toque","detalhe":"Mesmo checklist, canal diferente do primeiro"},
       {"nome":"18h — 3º toque","detalhe":"Último toque do dia"},
       {"nome":"Dia 3 — ultimato","detalhe":"Regra do POP-12: três dias de cadência, e o terceiro é o ultimato"}]'::jsonb,
     'A ação de cada dia muda conforme a etapa do funil — ver material "Cadência por Etapa".', 'rascunho');
  end if;
end $$;


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
