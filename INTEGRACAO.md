# Plano de integração — IXC, Bitrix, Meta Ads e Google Ads

Objetivo: a apresentação mensal da diretoria (8 slides) deixar de ser
montada na mão e passar a sair de views do banco, com número que ninguém
digita.

Este arquivo é o contrato. Quem for executar não precisa ler o
`index.html` inteiro (são 599 KB) nem redescobrir o schema: está tudo
aqui. Isso é o que segura o custo de token.

---

## 1. O que já existe (não refazer)

Levantado no código em 20/09/2026.

| Peça | Onde | Situação |
|---|---|---|
| Cliente REST do Bitrix (`bx`, `bxConta`, `bxNegocios`) | `index.html:3733-3777` | pronto, roda no navegador |
| Tela "Validação Bitrix" (`R.bitrix`) | `index.html:3779` | pronta, confere na mão |
| IDs dos campos do Bitrix (`BX`) | `index.html:3731-3736` | ME11 `UF_CRM_1765977342`, ME13 `UF_CRM_1766460217`, funil `0`, estágio `UC_VHZBMD` |
| Tabela `funil` já com `sistema_origem` + `id_externo` | `sql/TUDO.sql` | vazia, esperando a integração |
| `financeiro_mkt` (investimento, leads, vendas, receita por canal/mês) | `sql/TUDO.sql` | calcula CAC, CPL, ticket, ROI |
| Views `v_funil_conversao`, `v_financeiro_kpi`, `v_metas_progresso` | `sql/TUDO.sql` | prontas |
| Importador de CSV ("Mandar extrato") | `index.html:9171` | padrão a reaproveitar para anúncios |

Enums em uso: `etapa_funil` = lead, contato, agendamento, proposta,
fechado, perdido · `tipo_canal` = organico, trafego_pago, indicacao,
outbound, parceria, base_clientes · `indicador_meta` = vendas, leads,
ativos, receita.

---

## 2. As três decisões que definem tudo

**2.1 — A integração roda no servidor, não no navegador.**
O `index.html` está publicado no GitHub Pages. Token de IXC ou de Meta
dentro dele é token vazado para qualquer um que abrir a página. Por isso
cada fonte vira uma **Edge Function do Supabase**, com o segredo em
`supabase secrets`. O navegador só lê tabela já preenchida.

**2.2 — Grava o cru antes de interpretar.**
Cada sincronização joga a resposta da API em `int_eventos` (jsonb) e só
depois normaliza. Quando o número sair errado, dá para conferir o que a
API respondeu naquele dia sem chamar a API de novo. Sem isso, todo bug
vira uma nova rodada de investigação cara.

**2.3 — O IXC ganha do Bitrix quando divergir.**
Já é a regra escrita no código (`index.html:3952`). Ativação e base ativa
são do IXC. O Bitrix é dono do funil, do vendedor e do ciclo de venda.
Anúncio é dono do investimento. Nenhuma fonte opina sobre o território da
outra.

---

## 3. O furo que trava metade da apresentação

**O Bitrix não sabe de qual canal veio o negócio.** Está escrito no
próprio código: *"o número é do funil comercial inteiro"*
(`index.html:3942`).

Consequência direta: **CAC por origem, conversão por canal e ROI por
campanha não existem** enquanto isso não for resolvido — e não é código,
é configuração do CRM. Enquanto não tiver, o CAC só pode ser geral
(investimento total ÷ vendas totais), e isso precisa ser dito na
diretoria com essas palavras, não escondido.

**O que precisa ser feito antes (tarefa do gestor, não do dev):**

1. Criar no Bitrix, no funil 0, três campos de negócio:
   - `UF_CRM_ORIGEM` (lista: Meta, Google, Indicação, Orgânico, Outbound, Parceria, Base)
   - `UF_CRM_UTM_CAMPAIGN` (texto)
   - `UF_CRM_BAIRRO` (lista ou texto)
   - `UF_CRM_VIABILIDADE` (lista: viável, inviável-cobertura, inviável-análise)
2. Preencher automático nos formulários (Meta Lead Ads e site já mandam
   UTM; é mapear no conector).
3. Anotar os IDs reais que o Bitrix gerar e colocar na **Tabela de IDs**
   (seção 8). Sem esses IDs, a Etapa 3 não começa.

---

## 4. Dados que hoje não existem em lugar nenhum

Conferido: `bairro`, `viabilidade` e `casas passadas` não aparecem nem no
banco, nem no `index.html`. Então:

| Dado da apresentação | De onde viria | Existe hoje? |
|---|---|---|
| Faturamento | IXC `fn_areceber` | sim, na fonte |
| Base ativa / cancelamentos | IXC `cliente_contrato` | sim, na fonte |
| Ticket médio e mix de planos | IXC `vd_contratos` + plano | sim, na fonte |
| Tempo de ativação | IXC: data do contrato → data da O.S. concluída | sim, na fonte |
| Funil etapa a etapa | Bitrix `crm.stagehistory.list` | sim, na fonte |
| Ciclo de venda | Bitrix: `DATE_CREATE` → `CLOSEDATE` | sim, na fonte |
| Vendas por vendedor | Bitrix `ASSIGNED_BY_ID` | sim, na fonte |
| Investimento por canal | Meta / Google Ads | sim, na fonte |
| **Vendas por bairro** | campo novo no Bitrix + endereço no IXC | **não** |
| **Inviabilidade e o motivo** | campo novo no Bitrix | **não** |
| **Casas passadas por bairro** | **ninguém tem** — é a planilha da engenharia | **não** |
| **CAC por origem** | depende do item 3 acima | **não** |

**Penetração por bairro (casas passadas × conectadas) não sai de API
nenhuma.** É dado de projeto de rede. Ou a engenharia entrega uma
planilha com `bairro; casas_passadas; data_referencia`, ou o slide 3 fica
só com "vendas por bairro" e a diretoria precisa saber que a metade que
mostra *onde há demanda sem rede* está faltando — que é justamente a
parte que decide investimento de expansão.

---

## 5. Arquitetura

```
pg_cron (03:00)  ->  sinc-dia
                       |-- sinc-ixc      ---> IXC v1  (Basic auth)
                       |-- sinc-bitrix   ---> webhook REST
                       |-- sinc-meta     ---> Graph API /insights
                       +-- sinc-google   ---> Google Ads searchStream
                                |
                        int_eventos (jsonb cru)
                                |
                   assinantes | funil | ads_gastos | bairros
                                |
                    v_placar_mes | v_funil_etapas | v_territorio
                    v_velocidade | v_vendedores  -> tela Diretoria
```

Regras válidas para as quatro funções:

- **Idempotente.** Upsert por `(sistema_origem, id_externo)`. Rodar duas
  vezes no mesmo dia não duplica nada.
- **Janela curta.** Sincroniza os últimos 45 dias por padrão; carga
  histórica só sob parâmetro `?desde=AAAA-MM-DD`.
- **Falha barulhenta.** Grava em `int_execucoes` (fonte, início, fim,
  linhas, erro). A tela mostra vermelho. Integração que falha calada é
  pior que integração que não existe, porque a diretoria decide em cima
  de número velho achando que é novo.
- **Sem service_role no navegador.** Nunca.

---

## 6. Etapas de execução

Uma etapa por sessão. Cada uma tem prompt pronto, arquivo de saída e
critério de aceite. Não emende etapas: é o que faz o custo explodir.

### Etapa 0 — Credenciais (você, sem token)

Juntar e guardar em `supabase secrets set`:

```
IXC_HOST, IXC_TOKEN            (IXC: Sistema > Usuários > API)
BITRIX_WEBHOOK                 (Bitrix: webhook de entrada, permissão CRM)
META_TOKEN, META_ACCOUNT_ID    (token de usuário de sistema, act_...)
GOOGLE_ADS_*                   (ver 6.4 — pode ficar para depois)
```

Também: confirmar no MCP/Supabase que o projeto ligado é o
`ivkmsrypetpcmaatbvtx` (o do `config.js`). Hoje está apontando para
outro projeto — enquanto não trocar, nenhuma migration aplicada por aqui
chega no sistema de verdade.

E fazer a configuração do Bitrix da seção 3.

### Etapa 1 — SQL base → `sql/CORRECAO-25.sql`

Cria, no padrão dos arquivos que já existem (idempotente, comentado,
`create ... if not exists`):

```sql
int_execucoes (id, fonte, inicio, fim, linhas, erro, created_at)
int_eventos   (id, fonte, tipo, id_externo, payload jsonb, colhido_em)

bairros       (id, nome, cidade, casas_passadas int, data_referencia date)

assinantes    (id, id_externo text, cliente_nome, plano, valor numeric,
               bairro_id, status, data_contrato date, data_ativacao date,
               data_cancelamento date, motivo_cancelamento,
               unique (id_externo))

ads_gastos    (id, fonte text check (fonte in ('meta','google')),
               dia date, campanha, conjunto, canal_id, campanha_id,
               investimento numeric, impressoes int, cliques int,
               leads int, unique (fonte, dia, campanha, conjunto))
```

Altera `funil`, que já existe: `+ bairro_id, vendedor_id, origem text,
utm_campaign text, viabilidade text, motivo_perda text, data_proposta
date, dias_ciclo int generated`.

E cria as views que alimentam cada slide, uma por slide:

- `v_placar_mes` — crescimento líquido, faturamento, CAC, ticket,
  conversão geral, **cada um com o mês anterior e a média dos 3 meses
  numa coluna do lado**. A comparação é da view, não do slide.
- `v_funil_etapas` — contagem por etapa, taxa de passagem e a maior queda
- `v_territorio` — vendas, ativos, casas passadas e inviabilidade por bairro
- `v_velocidade` — ciclo de venda e tempo de ativação, média e mediana
- `v_vendedores` — volume, conversão e ciclo por vendedor

*Aceite:* roda duas vezes no SQL Editor sem erro; todas as views
respondem (vazias) com `select`.

### Etapa 2 — `supabase/functions/sinc-ixc`

API IXC v1: `POST https://{host}/webservice/v1/{tabela}`, header
`ixcsoft: listar`, Basic auth com `base64(id:token)`, corpo
`{qtype, query, oper, page, rp: 1000, sortname, sortorder}`.

Tabelas a puxar: `cliente_contrato` (base, status, plano, datas),
`cliente` (endereço/bairro), `fn_areceber` (faturamento recebido no mês),
`su_oss_chamado` (O.S. de instalação → tempo de ativação).

*Aceite:* `assinantes` com contagem batendo com a tela do IXC (±1%) e
`v_placar_mes` devolvendo faturamento e base ativa do mês.

### Etapa 3 — `supabase/functions/sinc-bitrix`

Reaproveitar a lógica de `index.html:3733-3777` (já resolve paginação,
`FEATURE_NOT_AVAILABLE` e a armadilha do filtro que **só funciona em POST
com JSON** — em query string ele devolve a base inteira em silêncio).

Métodos: `crm.deal.list` (negócios + campos novos da seção 3),
`crm.stagehistory.list` com `entityTypeId: 2` (etapa a etapa e o ciclo),
`crm.dealcategory.stage.list` (nome dos estágios), `user.get` (vendedores).

*Aceite:* `v_funil_etapas` fecha com o funil 0 do Bitrix na tela; a
"Validação Bitrix" deixa de acusar diferença.

### Etapa 4 — Anúncios

**4.1 Meta** — `GET /act_{id}/insights` com
`level=campaign&fields=spend,impressions,clicks,actions&time_increment=1`.
Token de usuário de sistema (não expira). Direto.

**4.2 Google Ads** — exige developer token + OAuth refresh + conta MCC.
É a parte mais cara e a que menos muda de resultado.
**Recomendação: começar pelo CSV.** O sistema já tem importador de
arquivo (`index.html:9171`); um relatório programado do Google Ads caindo
num CSV `dia; campanha; custo; cliques; conversões` resolve o slide 1 e o
5 no mesmo dia. API do Google só depois que o resto estiver rodando.

*Aceite:* `ads_gastos` com o investimento do mês batendo com o painel do
Meta e do Google, e o CAC geral saindo de `v_placar_mes`.

### Etapa 5 — Agendamento e tela

`pg_cron` às 03:00 chamando `sinc-dia` via `pg_net`. Tela nova
`R.integracoes` no padrão das outras (`label`, `curto`, `icone`,
`dados()`, `html()`): última sincronização por fonte, linhas trazidas,
erro, e botão "sincronizar agora".

### Etapa 6 — Tela "Diretoria"

Os 8 slides lendo as cinco views. Cada bloco com número, variação contra
o mês anterior, variação contra a média de 3 meses e um campo de leitura.
Onde o dado não existe (penetração, CAC por origem antes da seção 3), o
slide **mostra "faltando: <o quê> — <por que importa>"**, não esconde e
não estima.

---

## 7. Como isso não vira uma fatura de token

O que encarece não é o código, é redescobrir o contexto toda sessão.

1. **Uma etapa, uma sessão.** Começar dizendo: *"Leia `INTEGRACAO.md`,
   execute só a Etapa N, pare."*
2. **Nunca mandar ler o `index.html` inteiro.** São ~600 KB (~150 mil
   tokens, uma sessão só nisso). Usar as âncoras de linha da seção 1:
   `sed -n '3733,3780p' index.html`.
3. **Contrato fechado antes de codar.** Nomes de tabela, coluna e função
   já estão aqui. Mudou algo? Edita este arquivo *antes*, não discute no
   meio da implementação.
4. **Preencher a Tabela de IDs (seção 8) uma vez.** Todo ID que hoje
   seria "pergunta ao usuário no meio da sessão" vira consulta a este
   arquivo.
5. **Edge Function é arquivo novo e curto.** Não pede leitura do app.
   É por isso que as etapas 2-4 são as mais baratas apesar de parecerem
   as maiores.
6. **Testar com `curl` antes de escrever o parser.** Uma resposta real
   colada no prompt custa menos que três rodadas adivinhando o formato.
7. **Etapa 6 por último.** Tela sobre view vazia é retrabalho garantido.

Estimativa grosseira: Etapa 1 ~40k · Etapas 2/3 ~50k cada · Etapa 4 ~40k ·
Etapa 5 ~35k · Etapa 6 ~60k. Fazendo tudo numa sessão só, passa fácil de
400k pelo retrabalho — o dobro.

---

## 8. Tabela de IDs (preencher na Etapa 0)

| Chave | Valor | Onde achar |
|---|---|---|
| IXC host | | URL do painel |
| IXC id do token | | Sistema > Usuários > API |
| Bitrix funil comercial | `0` | já no código |
| Bitrix estágio Agendamento | `UC_VHZBMD` | já no código |
| Bitrix ME11 (entrou em agendamento) | `UF_CRM_1765977342` | já no código |
| Bitrix ME13 (ativação) | `UF_CRM_1766460217` | já no código |
| Bitrix campo Origem | | criar (seção 3) |
| Bitrix campo UTM campaign | | criar (seção 3) |
| Bitrix campo Bairro | | criar (seção 3) |
| Bitrix campo Viabilidade | | criar (seção 3) |
| Meta account id (`act_…`) | | Gerenciador de Anúncios |
| Google Ads customer id | | canto superior da conta |
| Projeto Supabase | `ivkmsrypetpcmaatbvtx` | `config.js` |

---

## 9. Ordem sugerida

Etapa 0 e a configuração do Bitrix primeiro — elas não custam token e
destravam tudo. Depois 1, 3, 2, 4.1, 5, 6. O Bitrix antes do IXC porque
o funil é o que está mais quebrado hoje na reunião; o IXC pelo menos tem
tela para consultar na mão enquanto isso.
