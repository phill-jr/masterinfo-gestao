# Instruções do projeto — Integração comercial MasterInfo

Cole este texto nas instruções do projeto. Toda sessão nova já começa
sabendo o contexto, e nenhuma precisa redescobrir nada.

---

## 1. Contexto fixo

Provedor de fibra regional, +7.000 assinantes. Quem toca é o gestor
comercial e de marketing; quem decide são os sócios.

O sistema de gestão é o repositório **`phill-jr/masterinfo-gestao`**:
um `index.html` único (~600 KB) publicado no GitHub Pages, falando com
o Supabase `ivkmsrypetpcmaatbvtx` pela chave publishable. Não há build,
não há backend próprio. Quem protege os dados é o RLS.

**Objetivo final do projeto:** a apresentação mensal da diretoria
(8 slides, 15 minutos, decisões no fim) sair pronta de views do banco,
alimentada por IXC, Bitrix, Meta Ads e Google Ads. Nenhum número
digitado à mão.

---

## 2. Como o assistente deve trabalhar neste projeto

Regras permanentes. Valem em toda sessão.

1. **Dado que falta se declara, não se estima.** Se um número não veio
   da fonte, escrever "faltando: X — por que importa". Nunca preencher
   com média, projeção ou chute.
2. **Uma etapa por sessão.** Executar a etapa pedida e parar. Não
   emendar a seguinte "já que estamos aqui".
3. **Nunca ler o `index.html` inteiro.** São ~150 mil tokens. Usar as
   âncoras da seção 4 com `sed -n 'INI,FIMp' index.html`.
4. **Segredo não entra no repositório.** O `index.html` é público. Token
   de API vive em `supabase secrets`, dentro de Edge Function.
5. **Contrato antes de código.** Se um nome de tabela ou coluna precisa
   mudar, editar este arquivo primeiro.
6. **Linguagem direta, sem jargão de marketing.** É o tom do código que
   já existe no repositório — manter.
7. **Explicar causa e consequência, não só o número.** "Caiu 12%" não é
   leitura; "caiu 12% porque X, e se seguir assim Y" é.

---

## 3. Dicionário — definições fechadas

Estas definições já estão no código. Não reabrir discussão.

| Termo | Definição |
|---|---|
| Venda do mês | estoque em Agendamento + ganho no mês (Bitrix, funil 0) |
| Venda da semana | passou pelo ME11 no período |
| Ativação | ME13 no Bitrix — **mas o número oficial é o do IXC** |
| Crescimento líquido | vendas − cancelamentos |
| Divergência IXC × Bitrix | ganha o IXC; a diferença é card não lançado |
| Dono do funil, vendedor e ciclo | Bitrix |
| Dono de base, faturamento e ativação | IXC |
| Dono do investimento | Meta / Google Ads |

---

## 4. Estado atual do repositório (20/09/2026)

**Já existe e não se refaz:**

| Peça | Âncora |
|---|---|
| Cliente REST do Bitrix (`bx`, `bxConta`, `bxNegocios`) | `index.html:3733-3777` |
| Tela "Validação Bitrix" (`R.bitrix`) | `index.html:3779` |
| Constantes `BX` | `index.html:3731-3736` |
| Importador de CSV, padrão a reaproveitar | `index.html:9171` |
| Tabela `funil`, já com `sistema_origem` e `id_externo` (vazia) | `sql/TUDO.sql` |
| `financeiro_mkt` + `v_financeiro_kpi` (CAC, CPL, ticket, ROI) | `sql/TUDO.sql` |
| `v_funil_conversao`, `v_metas_progresso` | `sql/TUDO.sql` |
| Plano detalhado da integração | `INTEGRACAO.md` |

Enums: `etapa_funil` = lead, contato, agendamento, proposta, fechado,
perdido · `tipo_canal` = organico, trafego_pago, indicacao, outbound,
parceria, base_clientes · `indicador_meta` = vendas, leads, ativos,
receita.

Padrão de tela (`R.nome`): `label`, `curto`, `icone`, `titulo`,
`filtro`, `async dados()`, `html()`. Padrão de SQL: arquivo
`sql/CORRECAO-NN.sql`, idempotente, `create ... if not exists`,
comentado em português explicando o porquê.

---

## 5. Os dois bloqueios que código nenhum resolve

**5.1 — O Bitrix não grava a origem do negócio.**
Está escrito no próprio código (`index.html:3942`): o número é do funil
inteiro. Enquanto não houver campo de origem no CRM, **CAC por canal,
conversão por canal e ROI por campanha não existem**. O CAC só pode ser
geral, e isso se diz na diretoria com todas as letras.

Resolver criando no funil 0: `UF_CRM_ORIGEM` (lista: Meta, Google,
Indicação, Orgânico, Outbound, Parceria, Base), `UF_CRM_UTM_CAMPAIGN`,
`UF_CRM_BAIRRO`, `UF_CRM_VIABILIDADE` (viável / inviável-cobertura /
inviável-análise). Depois anotar os IDs gerados na seção 7.

**5.2 — Casas passadas por bairro não existe em fonte nenhuma.**
Não está no banco, não está no app, não sai de API. É a planilha da
engenharia. Sem ela não há penetração por bairro — some justamente a
parte que mostra onde há demanda sem rede, que é o que decide
investimento de expansão.

---

## 6. Etapas — prompt pronto para cada sessão

Arquitetura: uma Edge Function do Supabase por fonte, orquestradas por
`pg_cron` às 03:00. Cada função grava o cru em `int_eventos` (jsonb),
normaliza depois, faz upsert idempotente por `(sistema_origem,
id_externo)`, sincroniza 45 dias por padrão e registra sucesso ou erro
em `int_execucoes`.

**Etapa 0 — credenciais e CRM (você, sem token)**
Juntar `IXC_HOST`, `IXC_TOKEN`, `BITRIX_WEBHOOK`, `META_TOKEN`,
`META_ACCOUNT_ID` em `supabase secrets set`. Criar os campos do
item 5.1 no Bitrix. Conferir que o MCP do Supabase aponta para
`ivkmsrypetpcmaatbvtx` e não para outro projeto.

**Etapa 1 — SQL base**
> Leia `INTEGRACAO.md`. Execute só a Etapa 1: crie `sql/CORRECAO-25.sql`
> com as tabelas `int_execucoes`, `int_eventos`, `bairros`,
> `assinantes`, `ads_gastos`, as colunas novas em `funil` e as views
> `v_placar_mes`, `v_funil_etapas`, `v_territorio`, `v_velocidade`,
> `v_vendedores`. Idempotente, no padrão dos CORRECAO existentes. Pare.

**Etapa 2 — IXC**
> Leia `INTEGRACAO.md`. Execute só a Etapa 2: Edge Function `sinc-ixc`.
> API v1, POST em `/webservice/v1/{tabela}`, header `ixcsoft: listar`,
> Basic auth. Tabelas `cliente_contrato`, `cliente`, `fn_areceber`,
> `su_oss_chamado`. Pare.

**Etapa 3 — Bitrix**
> Leia `INTEGRACAO.md`. Execute só a Etapa 3: Edge Function
> `sinc-bitrix`, reaproveitando a lógica de `index.html:3733-3777`
> (leia só essas linhas). Métodos `crm.deal.list`,
> `crm.stagehistory.list` com `entityTypeId: 2`,
> `crm.dealcategory.stage.list`, `user.get`. Pare.

**Etapa 4 — anúncios**
> Leia `INTEGRACAO.md`. Execute só a Etapa 4.1: Edge Function
> `sinc-meta`, Graph API `/act_{id}/insights`, `level=campaign`,
> `time_increment=1`. Google Ads fica por CSV nesta etapa. Pare.

**Etapa 5 — agendamento e tela**
> Leia `INTEGRACAO.md`. Execute só a Etapa 5: `pg_cron` às 03:00 via
> `pg_net` e a tela `R.integracoes` no padrão das outras. Pare.

**Etapa 6 — tela Diretoria**
> Leia `INTEGRACAO.md`. Execute só a Etapa 6: a tela dos 8 slides lendo
> as cinco views, cada número com variação contra o mês anterior e
> contra a média de 3 meses. Onde faltar dado, mostrar
> "faltando: X — por que importa". Pare.

Ordem recomendada: 0, 1, 3, 2, 4, 5, 6. O Bitrix antes do IXC porque o
funil é o que mais dói na reunião hoje; o IXC ainda tem tela para
consultar na mão enquanto isso.

Custo estimado: ~40k na 1, ~50k nas 2 e 3, ~40k na 4, ~35k na 5, ~60k na
6. Tudo numa sessão só passa de 400k por retrabalho.

---

## 7. Tabela de IDs — preencher uma vez

| Chave | Valor |
|---|---|
| IXC host | |
| IXC id do token | |
| Bitrix funil comercial | `0` |
| Bitrix estágio Agendamento | `UC_VHZBMD` |
| Bitrix ME11 (entrada em agendamento) | `UF_CRM_1765977342` |
| Bitrix ME13 (ativação) | `UF_CRM_1766460217` |
| Bitrix campo Origem | *criar* |
| Bitrix campo UTM campaign | *criar* |
| Bitrix campo Bairro | *criar* |
| Bitrix campo Viabilidade | *criar* |
| Meta account id (`act_…`) | |
| Google Ads customer id | |
| Projeto Supabase | `ivkmsrypetpcmaatbvtx` |

---

## 8. A apresentação que isto serve

Oito slides, nesta ordem. Cada um com título, números em destaque, três
bullets de leitura, uma frase de "o que isso significa" e roteiro de
fala de 30 a 45 segundos.

1. **Placar do mês** — cinco números só: crescimento líquido,
   faturamento, CAC, ticket médio, conversão geral. Cada um com variação
   em % e em absoluto contra o mês anterior. → `v_placar_mes`
2. **Funil completo** — etapa por etapa, apontando a maior queda e a
   causa provável. → `v_funil_etapas`
3. **Cobertura e território** — vendas e penetração por bairro cruzadas
   com inviabilidade; onde há demanda sem rede. → `v_territorio`
4. **Velocidade** — ciclo de venda e tempo de ativação, com o custo de
   cada dia a mais. → `v_velocidade`
5. **Time** — produtividade por vendedor, quem puxa a média para cima e
   para baixo. → `v_vendedores`
6. **Decisões** — no máximo 3, cada uma com responsável, prazo e o
   indicador que deve mover.

Todo indicador comparado com o mês anterior **e** com a média dos
últimos 3 meses. O que não couber em 8 slides vira anexo.
