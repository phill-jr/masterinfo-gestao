-- =====================================================================
-- ONBOARDING — CONTEÚDO INICIAL
-- =====================================================================
-- Roda depois de CORRECAO-13.sql:
--
--   python aplicar-sql.py sql/ONBOARDING-SEED.sql
--
-- Idempotente. Trilhas, módulos e aulas têm id fixo e sobem por upsert,
-- porque `onb_progresso` aponta para a aula — recriar a aula apagaria o
-- progresso de quem já a concluiu.
--
-- Provas são o contrário: questões e alternativas são apagadas e
-- reescritas a cada execução, porque é ali que o texto muda mais e
-- nada aponta para elas (a tentativa guarda o resultado, não o link).
-- Então: EDITE AS QUESTÕES AQUI e rode de novo, ou edite pela tela —
-- mas não os dois, ou este arquivo sobrescreve o que você fez na tela.
--
-- Os setores vêm por nome. Se um deles não existir, a trilha nasce
-- sem setor (bloco "Toda a empresa") em vez de estourar.
-- =====================================================================

do $seed$
declare
  s_comercial  uuid := (select id from setores where nome = 'Comercial'  limit 1);
  s_marketing  uuid := (select id from setores where nome = 'Marketing'  limit 1);
  s_operacoes  uuid := (select id from setores where nome ilike 'Opera%' limit 1);
  s_financeiro uuid := (select id from setores where nome = 'Financeiro' limit 1);
  s_gestao     uuid := (select id from setores where nome ilike 'Gest%'  limit 1);
begin

-- =====================================================================
-- TRILHAS
-- =====================================================================
insert into onb_trilhas (id, setor_id, nome, descricao, icone, duracao_dias, ordem) values
  ('a1000000-0000-4000-8000-000000000001', null,
   'Boas-vindas MasterInfo',
   'Todo mundo começa por aqui, de qualquer setor. Quem somos, para onde vamos, como nos comportamos e o que vendemos.',
   'star', 2, 0),

  ('a1000000-0000-4000-8000-000000000002', s_comercial,
   'Trilha do Calouro',
   'O caminho do novo consultor comercial. Cada dia tem o que estudar, o que fazer e um teste. E o tempo que sobra tem destino: o Tempo Ocioso.',
   'money', 15, 1),

  ('a1000000-0000-4000-8000-000000000003', s_comercial,
   'Conduzir o Onboarding (liderança)',
   'A outra ponta da Trilha do Calouro: o que gestor, líder e buddy fazem nos 15 dias, e como sai a decisão do Dia 15.',
   'users', 15, 2),

  ('a1000000-0000-4000-8000-000000000004', s_marketing,
   'Onboarding Marketing',
   'Primeiros passos, as seis tarefas fixas da semana, onde salvar cada coisa e as regras de ouro do conteúdo.',
   'film', 5, 1),

  ('a1000000-0000-4000-8000-000000000005', s_operacoes,
   'Onboarding Operações',
   'Estrutura criada, conteúdo a escrever.',
   'cog', null, 1),

  ('a1000000-0000-4000-8000-000000000006', s_financeiro,
   'Onboarding Financeiro',
   'Estrutura criada, conteúdo a escrever.',
   'chart', null, 1),

  ('a1000000-0000-4000-8000-000000000007', s_gestao,
   'Onboarding Gestão',
   'Estrutura criada, conteúdo a escrever.',
   'target', null, 1)
on conflict (id) do update set
  setor_id = excluded.setor_id, nome = excluded.nome,
  descricao = excluded.descricao, icone = excluded.icone,
  duracao_dias = excluded.duracao_dias, ordem = excluded.ordem;


-- =====================================================================
-- MÓDULOS
-- =====================================================================
insert into onb_modulos (id, trilha_id, titulo, resumo, ordem) values
  -- Boas-vindas
  ('a2000000-0000-4000-8000-000000000101', 'a1000000-0000-4000-8000-000000000001',
   'A empresa', 'De onde a MasterInfo veio, o que defende e como se comporta.', 1),
  ('a2000000-0000-4000-8000-000000000102', 'a1000000-0000-4000-8000-000000000001',
   'O que vendemos', 'Planos, roteadores e apps. Vale para qualquer setor: todo mundo é perguntado sobre isso.', 2),

  -- Trilha do Calouro
  ('a2000000-0000-4000-8000-000000000201', 'a1000000-0000-4000-8000-000000000002',
   'Como usar a trilha', 'A regra do jogo e a regra de ouro.', 1),
  ('a2000000-0000-4000-8000-000000000202', 'a1000000-0000-4000-8000-000000000002',
   'Dias 1 a 4 — Fundamentos', 'Empresa, produtos, CRM, cadastro, viabilidade e scripts. Teoria e prática juntas.', 2),
  ('a2000000-0000-4000-8000-000000000203', 'a1000000-0000-4000-8000-000000000002',
   'Dias 5 a 14 — Operação', 'Sai da sala e vai para o lado do vendedor. No Dia 10 você entra na fila.', 3),
  ('a2000000-0000-4000-8000-000000000206', 'a1000000-0000-4000-8000-000000000002',
   'Os fluxos do Comercial', 'Por onde o trabalho passa: o funil de ponta a ponta, a venda etapa por etapa e a cadência.', 6),
  ('a2000000-0000-4000-8000-000000000204', 'a1000000-0000-4000-8000-000000000002',
   'Avaliação e decisão', 'Os cinco pilares e o checklist do Dia 15.', 4),

  -- Liderança
  ('a2000000-0000-4000-8000-000000000301', 'a1000000-0000-4000-8000-000000000003',
   'O processo de 15 dias', 'Quem faz o quê, o que precisa estar pronto antes do Dia 1 e como se decide no fim.', 1),

  -- Marketing
  ('a2000000-0000-4000-8000-000000000401', 'a1000000-0000-4000-8000-000000000004',
   'Primeiros passos', 'Treinamentos, acessos e o mapa da operação.', 1),
  ('a2000000-0000-4000-8000-000000000402', 'a1000000-0000-4000-8000-000000000004',
   'A rotina', 'As seis tarefas fixas, o dia-casa de cada uma e onde cada arquivo mora.', 2),

  -- Setores a escrever
  ('a2000000-0000-4000-8000-000000000501', 'a1000000-0000-4000-8000-000000000005',
   'Fundamentos do setor', 'A escrever.', 1),
  ('a2000000-0000-4000-8000-000000000601', 'a1000000-0000-4000-8000-000000000006',
   'Fundamentos do setor', 'A escrever.', 1),
  ('a2000000-0000-4000-8000-000000000701', 'a1000000-0000-4000-8000-000000000007',
   'Fundamentos do setor', 'A escrever.', 1)
on conflict (id) do update set
  trilha_id = excluded.trilha_id, titulo = excluded.titulo,
  resumo = excluded.resumo, ordem = excluded.ordem;


-- =====================================================================
-- AULAS
-- =====================================================================
insert into onb_aulas (id, modulo_id, titulo, resumo, conteudo, duracao_min, ordem) values

-- ── Boas-vindas · A empresa ─────────────────────────────────────────
('a3000000-0000-4000-8000-000000000101', 'a2000000-0000-4000-8000-000000000101',
 'Quem é a MasterInfo', 'Vinte anos em cinco minutos.',
'## Começou com um casal de 18 anos e um bebê

Philipe e Tati abriram a **MasterInfo Computadores** em 2004, consertando PC. Tinham 18 anos e um filho recém-nascido — o Philipe Jr, que hoje trabalha aqui. Não foi plano de negócio bonito no papel: foi na raça.

## A linha do tempo

- **2004/2005** — MasterInfo Computadores. Manutenção de computador.
- **Depois** — internet via rádio. O primeiro passo para virar provedor.
- **2018** — fibra óptica, FTTH. O que a empresa é hoje.

O primeiro bairro de fibra foi o **Comasa**. Foi difícil no começo, e destravou com uma promoção.

## Onde estamos agora

Rede própria em **10 bairros de Joinville (SC)** — mais alguns atendidos por rede neutra. Somos a internet mais bem avaliada da cidade, e o motivo não é a velocidade: é estar perto.

> Não somos a grande operadora. Somos daqui. Essa é a única vantagem que uma nacional não copia.', 8, 1),

('a3000000-0000-4000-8000-000000000102', 'a2000000-0000-4000-8000-000000000101',
 'Missão, visão e propósito', 'O que a gente promete e onde quer chegar.',
'## Missão

Atender e **resolver rápido** qualquer problema de internet.

Repare no verbo: resolver. Não "abrir chamado", não "encaminhar ao setor responsável". Resolver.

## Propósito

Conectar cada pessoa em Joinville.

## Visão

- **10.000 assinantes até 2028**
- Ser marca empregadora que **forma lideranças** — as próximas lideranças da casa saem de dentro

## O que isso muda no seu dia

Toda vez que você tiver dúvida entre o processo e o cliente resolvido, lembre da missão. O processo existe para resolver rápido; quando ele atrapalha, o problema é o processo.', 5, 2),

('a3000000-0000-4000-8000-000000000103', 'a2000000-0000-4000-8000-000000000101',
 'Os 12 comportamentos', 'O comportamento antecede o resultado.',
'## Os doze

1. **Comprometimento**
2. **Disciplina**
3. **Presença**
4. **Pontualidade**
5. **Proatividade**
6. **Organização**
7. **Limpeza**
8. **Disponibilidade**
9. **Trabalho em equipe**
10. **Responsabilidade**
11. **Gratidão**
12. **Senso de dono**

## O lema

> O comportamento antecede o resultado.

Ninguém aqui é avaliado só pelo número. Duas pessoas com o mesmo resultado e comportamentos diferentes não têm o mesmo futuro na empresa — e isso é dito na cara, não por trás.

## Na prática

Proatividade é o que mais aparece na avaliação de quem está entrando. Traduzindo: **não esperar ordem para tudo**. Terminou uma tarefa e não tem instrução? Puxa a próxima coisa sozinho.', 6, 3),

('a3000000-0000-4000-8000-000000000104', 'a2000000-0000-4000-8000-000000000101',
 'Os 14 setores', 'Para saber para quem mandar quando não for com você.',
'## Os setores da casa

- **RH**
- **Financeiro**
- **Comercial** — vende
- **Marketing** — gera o lead
- **Equipe Técnica** — instala
- **Manutenção**
- **Almoxarifado**
- **Equipe de Fibra** — constrói e mantém a rede
- **Sucesso do Cliente**
- **Suporte Técnico**
- **Cobrança**
- **Agendamento** — agendas e rotas dos técnicos
- **Back Office** — administrativo e contratual
- **Limpeza Interna**

## Por que você precisa saber isso na primeira semana

Porque o erro mais comum de quem chega é segurar um problema que não é seu. Saber o nome do setor certo é metade do "resolver rápido".', 5, 4),

-- ── Boas-vindas · O que vendemos ────────────────────────────────────
('a3000000-0000-4000-8000-000000000105', 'a2000000-0000-4000-8000-000000000102',
 'Planos LITE e ULTRA', 'A diferença de verdade não é a velocidade.',
'## A diferença entre as linhas é o roteador

- **LITE** — 1 roteador, Wi-Fi comum
- **ULTRA** — 2 roteadores, **Mesh Wi-Fi 6**

O Wi-Fi 6 é **exclusivo da linha Ultra**. Dizer que um plano Lite tem Wi-Fi 6 é erro, e é o erro mais comum de quem está aprendendo a tabela.

## Linha LITE

| Plano | Velocidade | Em dia | Cheio |
|---|---|---|---|
| Lite Casa | 600 Mega | R$ 99,99 | R$ 109,99 |
| Lite Premium | 800 Mega | R$ 119,90 | R$ 129,90 |
| Lite Basic | 1 Giga | R$ 119,00 | R$ 129,00 |

O **Lite Premium é o mais procurado**.

## Linha ULTRA

| Plano | Velocidade | Em dia | Cheio | Extra |
|---|---|---|---|---|
| Ultra Família | 1 Giga | R$ 149,90 | R$ 159,90 | 1 app Premium/mês |
| Ultra Home Office | 1 Giga | R$ 179,90 | R$ 189,90 | Kaspersky + 3 apps |
| Ultra Gamer | 1 Giga | R$ 189,90 | R$ 199,90 | ExitLag + 2 apps |

## O preço "em dia"

Todo preço em dia já traz **R$ 10 de desconto** sobre o cheio. É desconto por pagar em dia — não é promoção por tempo limitado.

## Sempre incluso

Instalação em até 3 dias · suporte sábado e domingo · atendimento por WhatsApp.', 10, 1),

('a3000000-0000-4000-8000-000000000106', 'a2000000-0000-4000-8000-000000000102',
 'Apps e streaming', 'Onde quase todo mundo erra na primeira semana.',
'## As quatro categorias

- **Premium** — Disney+, HBO Max, Globoplay
- **Top** — SKY com Globo, Prime, Apple TV
- **Advanced** — SKY+ Light, Deezer, HotGo
- **Standard** — Looke, ExitLag, PlayKids+

## As três armadilhas

**1. A SKY é um app.** Não é "SKY mais um app". É um app de TV ao vivo, e ele ocupa a vaga da categoria dele.

Nos planos Lite:
- Lite Casa → o **SKY+ Light já É** o app Standard do mês
- Lite Premium → o **SKY+ Light com Globo já É** o app Advanced do mês

Ou seja: nunca liste "SKY+ Light" e "1 app" como dois benefícios separados. É o mesmo benefício contado duas vezes, e o cliente percebe.

**2. Ultra Família dá 1 app Premium por mês** — o cliente **escolhe um**. Não é Disney+ e HBO Max e Globoplay juntos.

**3. Lite Basic não tem app nenhum.** É 1 Giga puro.

## A indicação

O programa de indicação **não é benefício de plano**. Não entra na apresentação como se fosse item da tabela.', 8, 2),

-- ── Calouro · Como usar ─────────────────────────────────────────────
('a3000000-0000-4000-8000-000000000201', 'a2000000-0000-4000-8000-000000000201',
 'Como funciona e qual é a meta', 'Leia antes de tudo.',
'## O que são estes 15 dias

Treinamento **e** avaliação, ao mesmo tempo. Tem teste prático e teórico todo dia, e no Dia 15 a liderança decide pela efetivação.

Isso não é ameaça — é clareza. Você sabe desde o primeiro dia o que está sendo olhado.

## O formato de cada dia

- **Estude** — os POPs indicados no dia. É seu material de referência para sempre.
- **Faça** — a prática do dia, com destaque para os cadastros supervisionados.
- **Teste** — todo dia. Você apresenta para alguém.
- **Tempo livre** — o treino não ocupa o dia inteiro. O resto é seu para praticar.

## A meta

Chegar no Dia 15 podendo dizer "sim" para tudo do checklist de efetivação — e chegar antes, se der.

> Esta é a visão de quem faz. A visão de quem conduz está na trilha da liderança.', 5, 1),

('a3000000-0000-4000-8000-000000000202', 'a2000000-0000-4000-8000-000000000201',
 'Tempo Ocioso — nunca fique parado', 'A regra que mais separa as pessoas aqui dentro.',
'## A regra de ouro

Terminou uma tarefa e não tem instrução? **Não espere.** Escolha algo desta lista.

É literalmente isso que separa quem só assiste de quem evolui rápido — e é o item que mais pesa na avaliação de proatividade.

## Estudar

- Reler e reassistir os POPs
- Decorar a tabela de planos
- Decorar o glossário técnico
- Revisar os testes que você errou

## Praticar

- Fazer mais cadastros de treino (supervisionados)
- Fazer consultas de viabilidade de treino
- Gravar áudios e vídeos de script, com legenda
- Praticar movimentação no CRM

## Observar (shadowing)

- Acompanhar um consultor experiente atendendo ao vivo
- Ouvir ligações e atendimentos gravados
- Assistir aos role-plays do time

## Ajudar (sob supervisão)

- Entrar na fila de follow-up das fases frias
- Ajudar a organizar o CRM e a cadência
- Pegar leads simples junto com o Buddy

> Sobrou tempo? Cadastro de treino, POP na tela ou shadowing. Sempre tem o que fazer para ficar pronto mais rápido.', 6, 2),

-- ── Calouro · Dias 1 a 4 ────────────────────────────────────────────
('a3000000-0000-4000-8000-000000000211', 'a2000000-0000-4000-8000-000000000202',
 'Dia 1 — Imersão, Produtos, CRM e Ferramentas', 'O dia mais cheio da trilha.',
'## Estude

POP-01 Imersão · POP-02 Planos · POP-04 CRM · POP-05 Ferramentas

## Faça

Conheça história, missão, valores e os 14 setores. Decore a tabela de planos. Navegue no CRM — funil, oportunidades, etapas — e teste os acessos de todas as ferramentas.

## Teste — você apresenta

- Contar os valores, a cultura e a visão da empresa
- Apresentar os planos
- Apresentar o CRM
- Apresentar as ferramentas que usamos

## No tempo livre

Decorar planos, praticar no CRM e reler os POPs do dia.

**Quem conduz:** Gestor · Líder', null, 1),

('a3000000-0000-4000-8000-000000000212', 'a2000000-0000-4000-8000-000000000202',
 'Dia 2 — Cadastro, Viabilidade e Scripts', 'A mão na massa começa aqui.',
'## Estude

POP-06 Cadastro · POP-07 Viabilidade · POP-08 Scripts

## Faça

Comece os **primeiros cadastros supervisionados**. Consulte viabilidade (XC/InMap, cores de caixa) e treine os scripts de apresentação.

## Teste — você apresenta

- Fazer um cadastro do zero
- Consultar a viabilidade e explicar as cores de caixa
- Apresentar os scripts: apresentação e pedido do dado que falta

## No tempo livre

Mais cadastros de treino, viabilidades de treino e gravar áudios de script.

**Quem conduz:** Líder · Time', null, 2),

('a3000000-0000-4000-8000-000000000213', 'a2000000-0000-4000-8000-000000000202',
 'Dia 3 — Origens de lead, Organização e Rotina', 'De onde vem o lead muda como você fala com ele.',
'## Estude

POP-09 Marketing · POP-10 Organização · POP-01 Cultura · Rotina

## Faça

Aprenda as origens de lead e como tratar cada uma. Aplique os combinados da casa. Entenda a rotina: **3 follow-ups por dia** e o painel.

## Teste — você apresenta

- Explicar as origens de lead e como tratar cada uma
- Apresentar os combinados da casa
- Explicar a rotina: os 3 follow-ups e o painel

## No tempo livre

Cadastros de treino e shadowing.

**Quem conduz:** Líder', null, 3),

('a3000000-0000-4000-8000-000000000214', 'a2000000-0000-4000-8000-000000000202',
 'Dia 4 — Role play e Fluxo da Venda', 'Do lead à ativação, de ponta a ponta.',
'## Estude

POP-06 Cadastro · POP-08 Scripts · POP-11 Fluxo da Venda

## Faça

Mais cadastros de cliente. Role-play de scripts e de ligação (EraCloud/WhatsApp). Entenda o fluxo da venda de ponta a ponta: funil → negócio → ativação.

## Teste — você apresenta

- Fazer um cadastro de cliente
- Role-play: conduzir a ligação com o script
- Explicar o fluxo da venda, do lead à ativação

## No tempo livre

Cadastros, ouvir ligações gravadas e repetir role-plays.

**Quem conduz:** Líder · Time', null, 4),

-- ── Calouro · Dias 5 a 10 ───────────────────────────────────────────
('a3000000-0000-4000-8000-000000000221', 'a2000000-0000-4000-8000-000000000203',
 'Dia 5 — Dia inteiro acompanhando o vendedor', 'Shadowing.',
'## Faça

Passe o dia ao lado de um vendedor. Observe cada atendimento, faça cadastros e aprenda os scripts e o roteiro comercial na prática — não no papel.

## Estude

POP-08 Scripts · POP-11 Roteiro comercial

## Teste

Apresentar o roteiro comercial e fazer um cadastro.

## No tempo livre

Ouvir ligações e repetir scripts.

**Quem conduz:** Time (buddy)', null, 1),

('a3000000-0000-4000-8000-000000000222', 'a2000000-0000-4000-8000-000000000203',
 'Dias 6 e 7 — Continuação da prática', 'Conteúdo a confirmar.',
'## Faça

*A confirmar com o Philipe.*

Provável continuação: shadowing, cadastros e prática de scripts, ganhando autonomia antes de atender sozinho.

## Teste

Teste do dia, a definir conforme o foco escolhido para 6 e 7.

> Esta aula está aberta de propósito. Quando o conteúdo fechar, ela é editada aqui e todo mundo passa a ver a versão nova.

**Quem conduz:** Time (buddy)', null, 2),

('a3000000-0000-4000-8000-000000000223', 'a2000000-0000-4000-8000-000000000203',
 'Dia 8 — Começa a atender "Em Contato"', 'Assistido, com o Buddy do lado.',
'## Estude

POP-12 Follow-up · Cadência

## Faça

Comece a atender leads na fase **Em Contato**, com o Buddy ao lado. Rode a cadência e os scripts para fazer o cliente responder.

## Teste

Conduzir um atendimento de Em Contato com a cadência certa.

## Lembre

Os três horários de follow-up são **11h, 15h e 18h**. E cada toque tem registro no CRM — toque sem registro não aconteceu.

**Quem conduz:** Líder · Time', null, 3),

('a3000000-0000-4000-8000-000000000224', 'a2000000-0000-4000-8000-000000000203',
 'Dia 9 — Qualificação', 'O grande teste do onboarding.',
'## Faça

Continua atendendo os Em Contato e levando o lead até a qualificação.

## Teste — o mais importante da trilha

**Qualificar um lead e entregá-lo (handoff) qualificado para o comercial.**

É aqui que fica claro se você aprendeu ou só assistiu.

**Quem conduz:** Líder · Time', null, 4),

('a3000000-0000-4000-8000-000000000225', 'a2000000-0000-4000-8000-000000000203',
 'Dia 10 — Entra na fila', 'Operação real, supervisionada.',
'## Faça

Você entra na fila: operação de verdade, supervisionada — fila do discador e follow-up das fases frias. A partir daqui é rodar.

## Teste

Operar na fila mantendo o funil atualizado e o padrão dos toques.

## Entre um lead e outro

Sem parar: Tempo Ocioso — estudo, cadastro de treino, shadowing.

**Quem conduz:** Time (buddy)', null, 5),

('a3000000-0000-4000-8000-000000000226', 'a2000000-0000-4000-8000-000000000203',
 'Dias 11 a 14 — Operação assistida', 'Detalhamento pendente.',
'## Faça

Operação assistida: você segue atendendo, agora com menos supervisão a cada dia, até a avaliação do Dia 15.

*O detalhamento destes quatro dias ainda não fechou.*

## Teste

A definir, conforme o foco escolhido para estes dias.

> Esta aula está aberta de propósito, igual à dos Dias 6 e 7. Quando o
> conteúdo fechar, ela é editada aqui e todo mundo passa a ver a versão nova.

**Quem conduz:** Time (buddy)', null, 6),

-- ── Calouro · Os fluxos ─────────────────────────────────────────────
-- Vieram do módulo Vendedores, que guardava fluxo como registro próprio
-- (vd_fluxos). Aqui viram aula: é a mesma informação, num lugar só, e
-- deixa de existir um segundo cadastro para manter.
('a3000000-0000-4000-8000-000000000261', 'a2000000-0000-4000-8000-000000000206',
 'O funil de ponta a ponta', 'Do tráfego até a ativação. Validado no Bitrix24.',
'## As quatro grandes etapas

1. **Tráfego / Marketing** — origem do lead, ver POP-09
2. **Funil da Erika (IA)** — primeiro contato e qualificação
3. **Funil de negócio** — o time comercial humano assume
4. **Ativação** — cliente instalado e no ar

## O detalhe que muda tudo

O lead passa pela **Erika antes** de chegar no vendedor humano. Quando
você recebe um lead, ele já foi tocado — abrir a conversa como se fosse
o primeiro contato queima a credibilidade da casa.

> Validado no Bitrix24. Detalhamento em POP-11 e POP-04.', 5, 1),

('a3000000-0000-4000-8000-000000000262', 'a2000000-0000-4000-8000-000000000206',
 'A venda, etapa por etapa', 'O mesmo funil visto pelo que o vendedor faz.',
'## O que você faz em cada etapa

1. **Lead** — chega pela Erika ou pelo receptivo
2. **Atendimento** — primeiro contato humano
3. **Negociação** — plano recomendado por perfil, ver POP-02
4. **Cadastro** — cobertura, crédito e revisão, ver POP-06
5. **Assinatura** — contrato fechado
6. **Instalação** — agendamento e visita técnica
7. **Ativação** — cliente no ar

## Por que decorar a ordem

Porque a pergunta que mais chega do cliente é "e agora?". Saber a etapa
seguinte de cor é o que transforma uma resposta vaga em previsibilidade.', 5, 2),

('a3000000-0000-4000-8000-000000000263', 'a2000000-0000-4000-8000-000000000206',
 'A cadência de follow-up', 'Três toques por dia, e o terceiro dia é o ultimato.',
'## Os três toques do dia

- **11h — 1º toque.** Ligação, mensagem, vídeo ou áudio — sempre com registro no CRM.
- **15h — 2º toque.** Mesmo checklist, **canal diferente** do primeiro.
- **18h — 3º toque.** Último do dia.

## A regra dos três dias

Três dias de cadência, e o **terceiro é o ultimato**. É o POP-12.

## O que muda por etapa

A ação de cada dia muda conforme a etapa do funil — ver o material
"Cadência por Etapa".

> Toque sem registro no CRM não aconteceu. Vale repetir: é o erro que
> mais aparece na avaliação de quem está entrando.', 5, 3),

-- ── Calouro · Avaliação ─────────────────────────────────────────────
('a3000000-0000-4000-8000-000000000231', 'a2000000-0000-4000-8000-000000000204',
 'Os 5 pilares da avaliação', 'O que exatamente está sendo olhado.',
'## 1 · Conhecimento técnico

Produtos e planos, CRM, cadastro, rede própria e neutra, conceitos técnicos.

## 2 · Execução

Treinamentos concluídos, os ~15 cadastros, atividades cumpridas e qualidade na entrega.

## 3 · Comportamento

Organização, comprometimento, proatividade, postura e comunicação.

## 4 · Cultura

Alinhamento aos valores, trabalho em equipe, respeito aos processos e **saber receber feedback**.

## 5 · Disponibilidade e evolução

Interesse em aprender, evolução ao longo dos 15 dias e agilidade na adaptação.

> Não é só o que você aprendeu. Pesa postura, cultura e potencial. Quem antecipa e não espera ordem para tudo se destaca.', 5, 1),

('a3000000-0000-4000-8000-000000000232', 'a2000000-0000-4000-8000-000000000204',
 'Checklist de efetivação', 'Chegue no Dia 15 podendo dizer sim para tudo.',
'## O que precisa estar verdadeiro

- Estudei os POPs e passei nos testes diários
- Fiz os cadastros supervisionados e foram aprovados
- Domino produtos, CRM e viabilidade
- Entendo o fluxo da venda, do lead à ativação
- Nunca fiquei parado — usei o tempo ocioso para evoluir
- Demonstrei os comportamentos da casa

## Quem decide

A **líder consolida** a avaliação dos 5 pilares com evidências. O **gestor decide** — efetivação ou desligamento.

## Como se preparar

Vá marcando este checklist em voz alta com você mesmo a partir do Dia 8. Se algum item não tem resposta, ainda dá tempo: fale com a liderança antes do Dia 15, não depois.', 5, 2),

-- ── Liderança ───────────────────────────────────────────────────────
('a3000000-0000-4000-8000-000000000301', 'a2000000-0000-4000-8000-000000000301',
 'Os quatro papéis', 'Quem decide, quem ensina, quem apadrinha, quem executa.',
'## Gestor Comercial

Dono do processo. Garante recursos e acessos, define critérios, acompanha os checkpoints e **toma a decisão final**. Conduz o feedback comportamental.

## Líder Comercial

Conduz o onboarding no dia a dia. Ministra os treinamentos, aplica os testes diários, revisa os cadastros, faz os check-ins e **consolida a avaliação** para o gestor.

## Time Comercial (Buddy)

Um consultor experiente é o padrinho. Mentoria par a par, supervisão dos cadastros, condução dos role-plays e dúvidas do dia a dia.

## Novo Colaborador (Calouro)

Executa. Assiste aos conteúdos, estuda produtos e técnica, faz os ~15 cadastros, pratica scripts e follow-up, realiza os testes. Avaliado do Dia 1 ao 15.

## A regra em uma linha

> Gestor decide e garante recursos · Líder ensina e avalia · Time apadrinha e supervisiona · Calouro executa e evolui.', 6, 1),

('a3000000-0000-4000-8000-000000000302', 'a2000000-0000-4000-8000-000000000301',
 'Preparação — antes do Dia 1', 'Nada trava mais um onboarding do que acesso faltando.',
'## Do gestor

- **Aprovar a entrada** no período de avaliação e comunicar ao time
- **Liberar todos os acessos** — CRM, WhatsApp Business, Érica, FSchool e sistemas internos, criados **e testados**
- **Preparar mesa e equipamento** — estação, headset, celular do time e login prontos no primeiro dia
- **Definir o Buddy** junto com a líder

## Da líder

- **Montar o cronograma** dos 15 dias, dia a dia, com treinamentos, testes e checkpoints
- **Separar o Drive Comercial** — playbook, Manual de Cadastro, scripts e vídeos reunidos e acessíveis

## Por que isso é seção separada

Porque acesso que não foi testado antes vira meio dia perdido no Dia 1 — e o calouro começa achando que a casa é desorganizada. A primeira impressão do processo também é avaliação, só que da empresa.', 6, 2),

('a3000000-0000-4000-8000-000000000303', 'a2000000-0000-4000-8000-000000000301',
 'As duas semanas e a decisão', 'O desenho dos 15 dias.',
'## Semana 1 — Fundamentos e arranque

Imersão, produtos, técnico, CRM e ferramentas. E **até o Dia 3 a prática já arranca**: cadastro, viabilidade e treino de scripts.

> Teoria e prática andam juntas. Não se espera a semana 2 para pôr a mão na massa.

## Semana 2 — Execução e testes

Processo comercial completo, follow-up e os testes práticos. Os ~15 cadastros são fechados e aprovados aqui. A avaliação formal concentra nesta semana, quando já existe base para avaliar em simulação real.

## Transversal — todo dia, do 1 ao 15

- **Check-in diário** com o calouro: o que foi bem, o que ajustar amanhã
- **Observação comportamental**: fidelidade, disponibilidade, organização, comprometimento, proatividade

## Dia 15 — Decisão

Avaliação final nos 5 pilares. A liderança decide pela efetivação ou desligamento — considerando conhecimento, postura, aderência à cultura e potencial de crescimento.', 8, 3),

-- ── Marketing ───────────────────────────────────────────────────────
('a3000000-0000-4000-8000-000000000401', 'a2000000-0000-4000-8000-000000000401',
 'Semana 1 — treinamentos e acessos', 'Nesta ordem.',
'## Os três treinamentos, em ordem

1. **Gravação**
2. **Design**
3. **IA**

## E-mails e acessos — liberar e testar no primeiro dia

- E-mail corporativo MasterInfo
- Instagram e Meta Business Suite
- Canva da empresa
- Google Drive e as pastas de Marketing
- CapCut ou editor de vídeo
- WhatsApp Business, se for usar
- Acesso ao computador e à rede

> As senhas reais ficam na pasta **02 - Acessos e Logins**. Nunca em documento, nunca em conversa.

## Conhecer a operação antes de produzir

- Ler as Regras de Ouro
- Conhecer a estrutura de pastas
- Abrir o Guia de Planos 2026 — é a fonte oficial de preços
- Ver os últimos stories e vídeos publicados
- Alinhar a pauta da semana com o Philipe

## O tom da casa

> A gente não é a grande operadora, a gente é daqui. Cada story, vídeo e post mostra um provedor que resolve rápido, é pontual e está perto do cliente. Gente de verdade falando com gente de verdade.', 10, 1),

('a3000000-0000-4000-8000-000000000411', 'a2000000-0000-4000-8000-000000000402',
 'As 6 tarefas fixas', 'O que você entrega toda semana.',
'## 1 · Stories — todo dia, seg a sex

Manter o perfil vivo com sequências diárias. Rascunhos em *03 - Rascunhos e Produção*, publicação direto no Instagram.

## 2 · Vídeos orgânicos — foco quarta

Gravar e editar vídeos de feed e Reels. Salva em *07 - Vídeos › 03 - Orgânicos*.

## 3 · Vídeos do canal de indicação — foco quinta

Conteúdo para afiliados e indicação interna. Salva em *04 - Canais de Indicação*.

## 4 · Comunicação interna — foco segunda

Endomarketing, comunicados e posts para o time. Segue o Calendário de Endomarketing 2026.

## 5 · Captação com os CEOs — 1x semana, foco terça

Acompanhar Philipe e Tatiane para captar stories e gravar collabs. **Combine o horário antes e chegue com roteiro pronto** — capte material para a semana toda.

## 6 · Depoimento na instalação — 1x semana

Acompanhar a instalação de um cliente novo e gravar o depoimento na hora, com o cliente feliz pela internet nova. Combine a instalação com a equipe técnica, leve o roteiro de perguntas e grave antes, durante e depois.', 10, 1),

('a3000000-0000-4000-8000-000000000412', 'a2000000-0000-4000-8000-000000000402',
 'A grade da semana', 'Cada tarefa tem um dia-casa.',
'## O dia-casa de cada tarefa

- **Segunda** — planejar a semana e montar a comunicação interna. Alinhar pauta com o Philipe.
- **Terça** — captação com os CEOs. Editar a collab.
- **Quarta** — vídeos orgânicos. Roteiro do próximo vídeo.
- **Quinta** — vídeos do canal de indicação. Editar e agendar.
- **Sexta** — finalizar e agendar a próxima semana. Organizar arquivos e reportar.

Os **stories são diários** — base de todo dia, não têm dia-casa.

E mais 1x na semana, conforme a agenda técnica: acompanhar uma instalação para o depoimento.

## O ritmo do dia (8h)

- **08:00** — checar demandas e stories do dia
- **Manhã** — captação: gravar e produzir o foco do dia
- **12:00** — intervalo
- **Tarde** — edição: editar, publicar e agendar
- **17:00** — organizar arquivos e reportar

## Por que existe dia-casa

Para você poder adiantar produção sem perder o fio. O dia-casa é o piso, não o teto.', 8, 2),

('a3000000-0000-4000-8000-000000000413', 'a2000000-0000-4000-8000-000000000402',
 'Onde salvar cada coisa', 'Nada solto na área de trabalho.',
'## As pastas oficiais

| O quê | Onde |
|---|---|
| Vídeos orgânicos | 07 - Vídeos › 03 - Orgânicos |
| Vídeos do canal de indicação | 04 - Canais de Indicação |
| Comunicação interna | 03 - Marketing e Conteúdo › Endomarketing |
| Depoimentos gravados | 07 - Vídeos (bruto e edição final) |
| Rascunhos e produção | Estagiário - Marketing › 03 - Rascunhos e Produção |
| Certificados dos treinamentos | Estagiário - Marketing › 01 - Treinamentos |
| Logins e senhas | Estagiário - Marketing › 02 - Acessos e Logins |

## A regra

Arquivo que não está na pasta certa não existe para o resto do time. Se alguém precisa te perguntar onde está, o arquivo está no lugar errado.', 5, 3)

on conflict (id) do update set
  modulo_id = excluded.modulo_id, titulo = excluded.titulo,
  resumo = excluded.resumo, conteudo = excluded.conteudo,
  duracao_min = excluded.duracao_min, ordem = excluded.ordem;


-- =====================================================================
-- PROVAS
-- =====================================================================
insert into onb_provas (id, trilha_id, modulo_id, titulo, descricao, nota_corte, tentativas_max, ordem) values
  ('a4000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', null,
   'Prova de boas-vindas', 'Empresa, comportamentos e produtos. Vale para qualquer setor.', 70, 3, 1),

  ('a4000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002',
   'a2000000-0000-4000-8000-000000000202',
   'Prova dos fundamentos (Dias 1–4)', 'Produtos, CRM, cadastro, viabilidade e scripts.', 70, 3, 1),

  ('a4000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000002',
   'a2000000-0000-4000-8000-000000000203',
   'Prova da operação (Dias 5–10)', 'Cadência, qualificação e funil.', 70, 3, 2),

  ('a4000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000002', null,
   'Prova final do Calouro', 'A prova do Dia 15. Nota de corte mais alta que as outras.', 80, 2, 3),

  ('a4000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000003', null,
   'Prova da liderança', 'Papéis, preparação e critérios de decisão.', 70, 3, 1),

  ('a4000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000004', null,
   'Prova de Marketing', 'Rotina, grade e organização de arquivos.', 70, 3, 1)
on conflict (id) do update set
  trilha_id = excluded.trilha_id, modulo_id = excluded.modulo_id,
  titulo = excluded.titulo, descricao = excluded.descricao,
  nota_corte = excluded.nota_corte, tentativas_max = excluded.tentativas_max,
  ordem = excluded.ordem;

end $seed$;


-- =====================================================================
-- QUESTÕES
-- =====================================================================
-- Apagadas e reescritas a cada execução. Ver o aviso no topo do arquivo.

delete from onb_questoes where prova_id in (
  'a4000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000002',
  'a4000000-0000-4000-8000-000000000003','a4000000-0000-4000-8000-000000000004',
  'a4000000-0000-4000-8000-000000000005','a4000000-0000-4000-8000-000000000006');

-- Uma função só para o seed: cria a questão e as alternativas de uma
-- vez, com a certa marcada pelo índice. Sem isso este bloco vira 400
-- linhas de insert e ninguém revisa 400 linhas de insert.
create or replace function seed_questao(
  p_prova uuid, p_ordem int, p_enunciado text, p_alts text[], p_certa int,
  p_explicacao text default null, p_tipo text default 'multipla')
returns void language plpgsql as $$
declare v_q uuid; i int;
begin
  insert into onb_questoes (prova_id, enunciado, tipo, explicacao, ordem)
  values (p_prova, p_enunciado, p_tipo, p_explicacao, p_ordem)
  returning id into v_q;

  for i in 1 .. array_length(p_alts, 1) loop
    insert into onb_alternativas (questao_id, texto, correta, ordem)
    values (v_q, p_alts[i], i = p_certa, i);
  end loop;
end $$;


-- ── Prova de boas-vindas ────────────────────────────────────────────
select seed_questao('a4000000-0000-4000-8000-000000000001', 1,
  'Em que ano a MasterInfo passou a operar com fibra óptica (FTTH)?',
  array['2004', '2012', '2018', '2021'], 3,
  'A empresa nasceu em 2004/2005 como MasterInfo Computadores, passou pela internet via rádio e virou provedor de fibra em 2018.');

select seed_questao('a4000000-0000-4000-8000-000000000001', 2,
  'Qual é a missão da MasterInfo?',
  array['Ser o provedor mais barato de Joinville',
        'Atender e resolver rápido qualquer problema de internet',
        'Ter a maior cobertura de fibra de Santa Catarina',
        'Vender o maior número de planos por mês'], 2,
  'O verbo é resolver — não encaminhar, não abrir chamado.');

select seed_questao('a4000000-0000-4000-8000-000000000001', 3,
  'Qual é a visão da empresa para 2028?',
  array['10.000 assinantes e ser marca empregadora que forma lideranças',
        'Abrir filial em Curitiba',
        '5.000 assinantes e rede em 20 bairros',
        'Ser comprada por uma operadora nacional'], 1);

select seed_questao('a4000000-0000-4000-8000-000000000001', 4,
  'O lema dos comportamentos da casa é "o comportamento antecede o resultado".',
  array['Verdadeiro', 'Falso'], 1,
  'Duas pessoas com o mesmo resultado e comportamentos diferentes não têm o mesmo futuro aqui.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000001', 5,
  'Qual é a diferença central entre a linha LITE e a linha ULTRA?',
  array['A velocidade contratada',
        'O número de roteadores: Lite tem 1, Ultra tem 2 em Mesh Wi-Fi 6',
        'O prazo de fidelidade',
        'Só o preço'], 2,
  'Existe Lite de 1 Giga e Ultra de 1 Giga. O que muda é o roteador.');

select seed_questao('a4000000-0000-4000-8000-000000000001', 6,
  'Planos da linha LITE têm roteador Wi-Fi 6.',
  array['Verdadeiro', 'Falso'], 2,
  'Wi-Fi 6 é exclusivo da linha Ultra (Mesh Wi-Fi 6). Os Lite têm roteador Wi-Fi comum — é o erro mais comum de quem está aprendendo a tabela.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000001', 7,
  'No plano Lite Casa, como o SKY+ Light deve ser apresentado ao cliente?',
  array['Como um benefício extra, além do app do mês',
        'Ele É o app Standard do mês — não é um benefício separado',
        'Como um adicional pago à parte',
        'Ele não está incluso nesse plano'], 2,
  'A SKY é um app e ocupa a vaga da categoria. Listar "SKY+ Light" e "1 app" separados é contar o mesmo benefício duas vezes.');

select seed_questao('a4000000-0000-4000-8000-000000000001', 8,
  'O que o cliente do Ultra Família recebe de streaming?',
  array['Disney+, HBO Max e Globoplay, os três juntos',
        '1 app Premium por mês, escolhido por ele',
        '3 apps por mês de qualquer categoria',
        'Nenhum app'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000001', 9,
  'O preço "em dia" divulgado é R$ 10 menor que o valor cheio.',
  array['Verdadeiro', 'Falso'], 1,
  'É desconto por pagar em dia, não promoção por tempo limitado.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000001', 10,
  'Quem instala a internet na casa do cliente?',
  array['Equipe de Fibra', 'Equipe Técnica', 'Suporte Técnico', 'Agendamento'], 2,
  'A Equipe de Fibra constrói e mantém a rede; a Equipe Técnica faz a instalação; o Agendamento monta as rotas.');


-- ── Prova dos fundamentos (Dias 1–4) ────────────────────────────────
select seed_questao('a4000000-0000-4000-8000-000000000002', 1,
  'Segundo a trilha, quando o calouro começa a fazer cadastro?',
  array['Só na semana 2, depois de toda a teoria',
        'No Dia 2, já na primeira semana',
        'No Dia 10, quando entra na fila',
        'Depois de aprovado no Dia 15'], 2,
  'Teoria e prática andam juntas: até o Dia 3, no máximo, cadastro, viabilidade e scripts já entraram.');

select seed_questao('a4000000-0000-4000-8000-000000000002', 2,
  'Quantos follow-ups por dia a rotina comercial prevê, e em que horários?',
  array['2 — 10h e 16h', '3 — 11h, 15h e 18h', '4 — 9h, 12h, 15h e 18h', 'Não há horário fixo'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000002', 3,
  'Um toque de follow-up feito mas não registrado no CRM conta como feito.',
  array['Verdadeiro', 'Falso'], 2,
  'Toque sem registro não aconteceu — é assim que a liderança enxerga a cadência.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000002', 4,
  'O que se consulta na viabilidade?',
  array['O limite de crédito do cliente',
        'Se há atendimento no endereço e por qual rede — própria ou neutra',
        'A velocidade média do bairro',
        'Se o cliente já foi cliente antes'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000002', 5,
  'Qual é o plano mais procurado da linha Lite?',
  array['Lite Casa 600 Mega', 'Lite Premium 800 Mega', 'Lite Basic 1 Giga', 'Todos igualmente'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000002', 6,
  'No Dia 1 da trilha, o teste é escrito e feito sozinho.',
  array['Verdadeiro', 'Falso'], 2,
  'O teste do dia é apresentar: você conta a cultura, apresenta os planos, o CRM e as ferramentas para alguém.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000002', 7,
  'Você terminou a tarefa e ninguém te passou a próxima. O que a trilha manda fazer?',
  array['Esperar a liderança liberar a próxima atividade',
        'Puxar algo da lista de Tempo Ocioso — estudo, cadastro de treino ou shadowing',
        'Ajudar em outro setor',
        'Adiantar o horário de saída'], 2,
  'É a regra de ouro da trilha, e o item que mais pesa na avaliação de proatividade.');

select seed_questao('a4000000-0000-4000-8000-000000000002', 8,
  'Qual destas NÃO é uma atividade de Tempo Ocioso prevista na trilha?',
  array['Ouvir ligações e atendimentos gravados',
        'Fazer cadastros de treino supervisionados',
        'Fechar venda sozinho com lead quente da fila',
        'Decorar a tabela de planos'], 3,
  'Tudo no Tempo Ocioso é estudo, treino ou apoio supervisionado. Atender sozinho só depois do Dia 8, e assistido.');


-- ── Prova da operação (Dias 5–10) ───────────────────────────────────
select seed_questao('a4000000-0000-4000-8000-000000000003', 1,
  'O que acontece no Dia 5 da trilha?',
  array['Primeiro atendimento sozinho',
        'Dia inteiro de shadowing ao lado de um vendedor',
        'Prova teórica de produtos',
        'Entrada na fila do discador'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000003', 2,
  'Em que dia o calouro começa a atender os leads "Em Contato"?',
  array['Dia 5', 'Dia 8, assistido pelo Buddy', 'Dia 10', 'Dia 15'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000003', 3,
  'Qual é o teste-chave do Dia 9?',
  array['Fazer 15 cadastros no mesmo dia',
        'Qualificar um lead e entregá-lo qualificado para o comercial',
        'Apresentar a tabela de planos de cor',
        'Conduzir uma reunião com o gestor'], 2,
  'É o teste que mostra se a pessoa aprendeu ou só assistiu.');

select seed_questao('a4000000-0000-4000-8000-000000000003', 4,
  'O que muda no Dia 10?',
  array['O calouro entra na fila: operação real, supervisionada',
        'O calouro passa a trabalhar sem supervisão nenhuma',
        'Começa a semana de férias',
        'A avaliação final é antecipada'], 1);

select seed_questao('a4000000-0000-4000-8000-000000000003', 5,
  'Entre um lead e outro, na fila, o calouro pode ficar aguardando o próximo contato.',
  array['Verdadeiro', 'Falso'], 2,
  'A regra do Tempo Ocioso continua valendo depois do Dia 10.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000003', 6,
  'Qual é a sequência do fluxo da venda?',
  array['Lead → Cadastro → Atendimento → Negociação → Ativação',
        'Lead → Atendimento → Negociação → Cadastro → Assinatura → Instalação → Ativação',
        'Lead → Negociação → Instalação → Cadastro → Ativação',
        'Lead → Assinatura → Atendimento → Instalação'], 2);


-- ── Prova final do Calouro ──────────────────────────────────────────
select seed_questao('a4000000-0000-4000-8000-000000000004', 1,
  'Quantos dias dura o onboarding comercial e o que acontece no fim?',
  array['30 dias, com efetivação automática',
        '15 dias, e a liderança decide entre efetivação e desligamento',
        '15 dias, com efetivação automática',
        '10 dias, e o RH decide'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000004', 2,
  'Quais são os 5 pilares da avaliação?',
  array['Conhecimento técnico, execução, comportamento, cultura, disponibilidade e evolução',
        'Vendas, cadastros, pontualidade, aparência, comunicação',
        'Produtos, CRM, viabilidade, scripts, follow-up',
        'Metas, receita, ticket médio, conversão, churn'], 1);

select seed_questao('a4000000-0000-4000-8000-000000000004', 3,
  'Quem toma a decisão final de efetivação?',
  array['A líder comercial', 'O gestor comercial', 'O Buddy', 'O RH'], 2,
  'A líder consolida a avaliação com evidências; o gestor decide.');

select seed_questao('a4000000-0000-4000-8000-000000000004', 4,
  'Aproximadamente quantos cadastros supervisionados o calouro faz nos 15 dias?',
  array['5', '15', '30', 'Não há número definido'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000004', 5,
  'A decisão do Dia 15 leva em conta apenas o conhecimento técnico adquirido.',
  array['Verdadeiro', 'Falso'], 2,
  'Pesa também postura, aderência à cultura e potencial de crescimento.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000004', 6,
  'Qual é o papel do Buddy?',
  array['Decidir a efetivação',
        'Consultor experiente que apadrinha: mentoria, supervisão dos cadastros e role-plays',
        'Aplicar as provas teóricas',
        'Liberar os acessos aos sistemas'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000004', 7,
  'Como o Wi-Fi 6 aparece na tabela de planos?',
  array['Em todos os planos', 'Só na linha Ultra, em Mesh', 'Só no Lite Basic', 'É um adicional pago'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000004', 8,
  'O que fazer com um lead cuja origem você não reconhece?',
  array['Descartar', 'Tratar como qualquer outro, sem diferença',
        'Identificar a origem antes de abordar — a origem muda o tratamento',
        'Encaminhar para o Marketing'], 3);

select seed_questao('a4000000-0000-4000-8000-000000000004', 9,
  'Um cliente pergunta se o plano Ultra Home Office dá direito a quantos apps.',
  array['1 app Premium', '2 apps', '3 apps: Top, Advanced e Standard', 'Nenhum'], 3,
  'Ultra Home Office traz Kaspersky mais 3 apps por mês.');

select seed_questao('a4000000-0000-4000-8000-000000000004', 10,
  'O que a trilha considera o comportamento que mais destaca um calouro?',
  array['Chegar cedo', 'Antecipar e não esperar ordem para tudo',
        'Fazer mais cadastros que os outros', 'Nunca errar'], 2);


-- ── Prova da liderança ──────────────────────────────────────────────
select seed_questao('a4000000-0000-4000-8000-000000000005', 1,
  'Na matriz de responsabilidades, quem lidera a preparação e os acessos do Dia 0?',
  array['Gestor', 'Líder', 'Buddy', 'Calouro'], 1);

select seed_questao('a4000000-0000-4000-8000-000000000005', 2,
  'Quem consolida a avaliação dos 5 pilares e apresenta ao gestor?',
  array['O Buddy', 'A líder comercial', 'O próprio calouro', 'O RH'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000005', 3,
  'Os check-ins com o calouro acontecem:',
  array['Só no Dia 15', 'Uma vez por semana', 'Todo dia, do Dia 1 ao 15', 'Quando surge um problema'], 3);

select seed_questao('a4000000-0000-4000-8000-000000000005', 4,
  'Basta criar os acessos antes do Dia 1 — testar é responsabilidade do calouro.',
  array['Verdadeiro', 'Falso'], 2,
  'Os acessos são criados E testados antes. Acesso não testado vira meio dia perdido no Dia 1.', 'vf');

select seed_questao('a4000000-0000-4000-8000-000000000005', 5,
  'Em que semana se concentra a avaliação formal por testes práticos?',
  array['Semana 1', 'Semana 2', 'Nas duas igualmente', 'Só no Dia 15'], 2,
  'Na semana 2 já existe base para avaliar em simulação real. Pergunta rápida na semana 1 é bem-vinda, mas não é a avaliação formal.');

select seed_questao('a4000000-0000-4000-8000-000000000005', 6,
  'A regra de responsabilidade em uma linha é:',
  array['Gestor ensina · Líder decide · Time avalia · Calouro observa',
        'Gestor decide e garante recursos · Líder ensina e avalia · Time apadrinha e supervisiona · Calouro executa e evolui',
        'Todos ensinam e todos decidem',
        'O RH conduz e a liderança acompanha'], 2);


-- ── Prova de Marketing ──────────────────────────────────────────────
select seed_questao('a4000000-0000-4000-8000-000000000006', 1,
  'Qual é a ordem dos três treinamentos da primeira semana?',
  array['Design, IA, Gravação', 'Gravação, Design, IA', 'IA, Gravação, Design', 'Não há ordem definida'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000006', 2,
  'Qual tarefa é diária, de segunda a sexta?',
  array['Vídeos orgânicos', 'Stories', 'Captação com os CEOs', 'Comunicação interna'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000006', 3,
  'Qual é o dia-casa dos vídeos do canal de indicação?',
  array['Segunda', 'Terça', 'Quarta', 'Quinta'], 4);

select seed_questao('a4000000-0000-4000-8000-000000000006', 4,
  'Onde ficam as senhas dos acessos?',
  array['Neste documento de onboarding',
        'Na pasta 02 - Acessos e Logins',
        'No bloco de notas do computador',
        'No grupo do WhatsApp do time'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000006', 5,
  'Qual é a fonte oficial de preços para qualquer material?',
  array['O último post publicado', 'O Guia de Planos 2026',
        'O que o comercial informar no dia', 'O site, sempre'], 2);

select seed_questao('a4000000-0000-4000-8000-000000000006', 6,
  'Para a captação com os CEOs, o certo é aparecer na hora e improvisar o roteiro.',
  array['Verdadeiro', 'Falso'], 2,
  'Combine o horário antes e chegue com roteiro pronto — e capte material para a semana toda.', 'vf');


drop function if exists seed_questao(uuid, int, text, text[], int, text, text);


-- =====================================================================
-- AULAS QUE APONTAM PARA A BIBLIOTECA
-- =====================================================================
-- Rodam depois de `importar-treinamentos.py`, e por isso casam por
-- título em vez de id: o treinamento nasce no import, não aqui. Se o
-- HTML ainda não foi importado, o insert simplesmente não acontece —
-- é `insert ... select`, não `values`.
--
--   python importar-treinamentos.py "../02 - Comercial/01 - Onboarding" --setor Comercial

insert into onb_aulas (id, modulo_id, titulo, resumo, treinamento_id, duracao_min, obrigatoria, ordem)
select 'a3000000-0000-4000-8000-00000000020f', 'a2000000-0000-4000-8000-000000000201',
       'Documento completo da Trilha do Calouro',
       'O material original, com o cronograma dia a dia. Guarde: é sua referência depois do onboarding.',
       t.id, t.duracao_min, false, 3
  from onb_treinamentos t where t.titulo = 'Trilha do Calouro'
on conflict (id) do update set treinamento_id = excluded.treinamento_id,
  titulo = excluded.titulo, resumo = excluded.resumo, ordem = excluded.ordem;

insert into onb_aulas (id, modulo_id, titulo, resumo, treinamento_id, duracao_min, obrigatoria, ordem)
select 'a3000000-0000-4000-8000-00000000030f', 'a2000000-0000-4000-8000-000000000301',
       'Documento completo do Onboarding Comercial',
       'Checklist dos 15 dias com o responsável de cada tarefa e a matriz de responsabilidades.',
       t.id, t.duracao_min, false, 4
  from onb_treinamentos t where t.titulo like 'Onboarding Comercial%'
on conflict (id) do update set treinamento_id = excluded.treinamento_id,
  titulo = excluded.titulo, resumo = excluded.resumo, ordem = excluded.ordem;

insert into onb_aulas (id, modulo_id, titulo, resumo, treinamento_id, duracao_min, obrigatoria, ordem)
select 'a3000000-0000-4000-8000-00000000040f', 'a2000000-0000-4000-8000-000000000401',
       'Documento completo da rotina do estagiário',
       'A rotina original, com a grade da semana e as regras de ouro do conteúdo.',
       t.id, t.duracao_min, false, 2
  from onb_treinamentos t where t.titulo like 'Rotina e Onboarding%'
on conflict (id) do update set treinamento_id = excluded.treinamento_id,
  titulo = excluded.titulo, resumo = excluded.resumo, ordem = excluded.ordem;


-- =====================================================================
-- OS POPS COMO MÓDULO DE REFERÊNCIA DA TRILHA DO CALOURO
-- =====================================================================
-- Os doze POPs já estão citados aula por aula ("estude o POP-06"). Este
-- módulo os deixa abríveis de dentro do sistema, em vez de mandar a
-- pessoa caçar arquivo em pasta de rede.
--
-- Todas entram como OPCIONAIS: são referência, não etapa. A conta de
-- progresso ignora aula opcional (ver v_onb_matriculas), então ninguém
-- precisa marcar doze POPs para a trilha fechar — mas quem quiser
-- marcar tem onde.
--
-- Pareia por prefixo do título, que é o que o importador gera:
-- "POP-06 · Cadastro de Cliente Novo". A apresentação do mesmo POP fica
-- de fora — ela é material de quem apresenta, e vive na biblioteca.

insert into onb_modulos (id, trilha_id, titulo, resumo, ordem) values
  ('a2000000-0000-4000-8000-000000000205', 'a1000000-0000-4000-8000-000000000002',
   'Os POPs — sua referência',
   'Os doze procedimentos, abríveis aqui dentro. Opcionais na trilha, obrigatórios na vida.', 5)
on conflict (id) do update set
  trilha_id = excluded.trilha_id, titulo = excluded.titulo,
  resumo = excluded.resumo, ordem = excluded.ordem;

insert into onb_aulas (id, modulo_id, titulo, resumo, treinamento_id, duracao_min, obrigatoria, ordem)
select ('a3000000-0000-4000-8000-0000000009' || lpad(n::text, 2, '0'))::uuid,
       'a2000000-0000-4000-8000-000000000205',
       t.titulo,
       'Procedimento oficial. É a fonte — quando a memória e o POP discordarem, o POP ganha.',
       t.id, t.duracao_min, false, n
  from generate_series(1, 12) n
  join onb_treinamentos t
    on t.titulo like ('POP-' || lpad(n::text, 2, '0') || ' %')
   and t.titulo not like '%(apresenta%'
on conflict (id) do update set
  titulo = excluded.titulo, treinamento_id = excluded.treinamento_id,
  resumo = excluded.resumo, duracao_min = excluded.duracao_min, ordem = excluded.ordem;


-- =====================================================================
-- Conferência
-- =====================================================================
select t.nome as trilha, coalesce(t.setor, 'Toda a empresa') as setor,
       t.modulos, t.aulas, t.provas,
       (select count(*) from onb_questoes q
          join onb_provas p on p.id = q.prova_id
         where p.trilha_id = t.id) as questoes
  from v_onb_trilhas t
 order by t.setor_ordem nulls first, t.ordem;
