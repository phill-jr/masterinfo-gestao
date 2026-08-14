-- ═══════════════════════════════════════════════════════════════════
--  MÓDULO VENDEDORES — instalação completa (dicionário + onboarding)
--
--  Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
--  É a junção de vendedores-01-dicionario.sql e vendedores-02-onboarding.sql,
--  na ordem certa, para não precisar de duas execuções.
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
