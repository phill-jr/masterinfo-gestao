# Manual: de onde sai cada número do Placar Comercial

Enquanto a integração não roda, os números são colhidos à mão. Este manual
existe para isso custar 20 minutos por mês e **zero token** — você segue a
lista, monta um bloco de texto e cola no painel do deck.

---

## 0. A regra que vale para tudo: dia 1 ao dia 20

Todo número é do **dia 1 até o dia 20** do mês. Nenhuma exceção.

O motivo: a reunião acontece antes do mês fechar. Comparar 20 dias deste mês
com 31 do mês passado faz a operação parecer pior do que é; comparar com
fevereiro faz parecer melhor. Janela fixa mata os dois erros.

Isso significa que você precisa preencher **quatro meses**: o de referência e
os três anteriores, todos de 1 a 20. Na primeira vez dá trabalho. Depois só
entra um mês novo por reunião.

---

## 1. Como usar (o caminho curto)

1. Abre o deck → botão **Editar dados** → campo **Colar tudo**.
2. Cola o bloco preenchido (modelo na seção 2).
3. **Aplicar** → **Salvar**.
4. Repete para cada um dos quatro meses.

Os campos individuais continuam lá para corrigir um número solto. O bloco é
para a carga do mês inteiro de uma vez.

---

## 2. Bloco para copiar

Copie daqui, preencha e cole. Linha sem valor pode ficar em branco — o slide
mostra "falta preencher" e explica por que aquele número importa, o que é
melhor do que um número chutado.

```
MES: 2026-09
FATURAMENTO:
VENDAS:
CANCELAMENTOS:
PERDIDOS:
BASE:
TICKET:
INVESTIMENTO:
CICLO:
ATIVACAO:
FUNIL: leads; atendidos; viaveis; propostas; vendas

BAIRROS:
nome; casas passadas; ativos; vendas; inviaveis cobertura; inviaveis analise

PLANOS:
nome; vendas; valor mensal

CANAIS:
nome; investimento; leads; vendas

VENDEDORES:
nome; leads recebidos; vendas; ciclo em dias

DECISOES:
o que fazer; quem; prazo; indicador que precisa mexer
```

Decimal com vírgula. Pode usar `;` ou tabulação — colar da planilha funciona.

---

## 3. IXC — base, receita e instalação

O IXC é dono de tudo que é cliente de verdade. **Quando IXC e Bitrix
divergirem, vale o IXC.** Isso já é regra escrita no código do sistema.

| Campo do bloco | O que pedir ao IXC |
|---|---|
| `FATURAMENTO` | Soma dos títulos **recebidos** com data de baixa entre dia 1 e 20. Receita recebida, não faturada — é o dinheiro que entrou. |
| `BASE` | Contratos com status **ativo** na data de fechamento da janela (dia 20). É uma fotografia, não um acumulado. |
| `CANCELAMENTOS` | Contratos com data de cancelamento entre 1 e 20. **Total**, incluindo quem nunca chegou a ser instalado. |
| `TICKET` | Faturamento ÷ vendas do período. Se preferir, tire do próprio mix: soma de (vendas × valor) ÷ total de vendas. |
| `PLANOS` | Contratos assinados no período, agrupados por plano, com o valor mensal de cada um. |
| `ATIVACAO` | Média de dias entre a **data do contrato** e a **conclusão da O.S. de instalação**. É o número que mais dói e o menos olhado. |
| `BAIRROS` (colunas `ativos`) | Contratos ativos agrupados pelo bairro do endereço de instalação. |

**Onde**: os nomes de menu mudam conforme a versão do IXC, então vá pelo
conteúdo: precisa de um relatório de contratos com data de contrato, data de
cancelamento, plano, valor e endereço; e de um relatório financeiro de títulos
recebidos por data de baixa. Exporte para planilha e agrupe lá.

**Para quem quiser automatizar** (apêndice, seção 8): a API v1 do IXC entrega
as mesmas tabelas.

---

## 4. Bitrix — funil, tempo e vendedores

O Bitrix é dono do que ainda não virou cliente. Funil comercial é o
`CATEGORY_ID: 0` — já está fixado no código do sistema.

### 4.1 Antes da primeira vez: o mapa de etapas (faça uma vez só)

O deck trabalha com cinco etapas. O seu Bitrix tem as dele. Rode uma vez:

```
https://SEU_WEBHOOK/crm.dealcategory.stage.list?id=0
```

Anote o resultado aqui e nunca mais precise perguntar:

| Etapa do deck | O que significa | STAGE_ID no nosso Bitrix |
|---|---|---|
| Leads | negócio criado, contato chegou | |
| Atendidos | alguém respondeu, saiu do primeiro contato | |
| Viáveis | tem rede e passou na análise | |
| Propostas | recebeu preço | |
| Vendas | ganho no período | |

Já conhecidos, tirados do código: **Agendamento = `UC_VHZBMD`**,
**ME11 (entrada em agendamento) = `UF_CRM_1765977342`**,
**ME13 (ativação) = `UF_CRM_1766460217`**.

### 4.2 Números do mês

| Campo do bloco | Como contar |
|---|---|
| `FUNIL` | Quantos negócios **passaram** por cada etapa entre 1 e 20. Passou, não "está parado nela" — quem já avançou continua contando na etapa anterior. |
| `VENDAS` | Negócios ganhos no funil 0 entre 1 e 20. Confira contra o IXC; se divergir, vale o IXC e a diferença é card não lançado. |
| `PERDIDOS` | Negócios marcados como perdidos que **nunca chegaram a virar cliente** (ME11 Perdido). É a desistência antes da ativação — problema diferente de churn de base. |
| `CICLO` | Média de dias entre `DATE_CREATE` e `CLOSEDATE` dos ganhos no período. |
| `VENDEDORES` | Por `ASSIGNED_BY_ID`: quantos negócios recebeu, quantos ganhou, ciclo médio. **Leads recebidos importa tanto quanto vendas** — conversão sem denominador não diz nada. |
| `BAIRROS` (colunas de inviabilidade) | Negócios perdidos por motivo, separando **cobertura** (não tem rede) de **análise** (crédito ou cadastro). |

**Atenção, armadilha real**: o filtro do Bitrix só funciona em **POST com
JSON**. Em query string ele é ignorado em silêncio e devolve a base inteira —
parece que funcionou e o número vem dez vezes maior. Isso já está documentado
dentro do código do sistema.

**Pelo painel**: CRM → Negócios → funil Comercial → visão Funil, com filtro de
período. Dá os números de etapa sem escrever uma linha de código.

---

## 5. Meta Ads e Google Ads — investimento

| Campo do bloco | Meta | Google Ads |
|---|---|---|
| `INVESTIMENTO` (total) | Soma do valor gasto nas duas plataformas no período | |
| `CANAIS` → investimento | Gerenciador de Anúncios → período personalizado dia 1 a 20 → coluna **Valor gasto**, por campanha | Campanhas → mesmo período → coluna **Custo** |
| `CANAIS` → leads | Coluna de **resultados** do objetivo de cadastro | Coluna **Conversões**, contando só a conversão de lead |

Some as campanhas por canal (tudo do Meta numa linha, tudo do Google em
outra), a menos que você queira decidir verba campanha a campanha.

**Atalho que economiza tempo todo mês**: no Google Ads dá para agendar um
relatório recorrente com as colunas `dia; campanha; custo; cliques;
conversões`. Ele chega por e-mail e você só cola.

---

## 6. O que hoje não sai de lugar nenhum

Estes dois não são preguiça de procurar — não existem na fonte. O deck mostra
"faltando" e explica; não invente.

**Casas passadas por bairro.** Não está no IXC, não está no sistema, não sai de
API. É a planilha de projeto da engenharia. Sem ela existe "onde vendemos", mas
não existe "onde ainda há casa para vender" — some exatamente a conta que
decide expansão de rede. Peça uma vez, no formato `bairro; casas passadas; data
de referência`; esse número muda devagar, serve por vários meses.

**Vendas por origem (CAC por canal).** O Bitrix não grava de qual canal veio o
negócio. Enquanto não houver campo de origem no CRM, a coluna `vendas` de
`CANAIS` fica vazia e o CAC só pode ser geral. Resolver isso é criar quatro
campos no funil 0 — `UF_CRM_ORIGEM`, `UF_CRM_UTM_CAMPAIGN`, `UF_CRM_BAIRRO`,
`UF_CRM_VIABILIDADE` — e travar o preenchimento no formulário. É a tarefa mais
barata com o maior efeito nesta apresentação inteira.

---

## 7. Checklist de 20 minutos

Na ordem, porque um número depende do outro:

- [ ] **IXC** (8 min) — faturamento recebido · base ativa no dia 20 ·
      cancelamentos · contratos por plano · tempo médio de instalação ·
      ativos por bairro
- [ ] **Bitrix** (7 min) — cinco etapas do funil · ganhos · perdidos antes de
      virar cliente · ciclo médio · por vendedor · inviabilidade por motivo
- [ ] **Meta + Google** (3 min) — valor gasto e leads, por plataforma
- [ ] **Montar o bloco** (2 min) — colar no deck, salvar
- [ ] **Escrever as três decisões** — cada uma com responsável, prazo e o
      indicador que ela precisa mover

Conferência antes de apresentar: as vendas somam igual em três lugares — mix de
planos, canais e vendedores. Se não somam, algum lançamento está faltando.

---

## 8. Apêndice: API do IXC, para quem for automatizar

```
POST https://SEU_HOST/webservice/v1/<tabela>
Headers:
  Authorization: Basic <base64 de "ID_DO_TOKEN:TOKEN">
  ixcsoft: listar
  Content-Type: application/json
Body:
  {"qtype":"<tabela>.id","query":"0","oper":">",
   "page":"1","rp":"1000","sortname":"<tabela>.id","sortorder":"desc"}
```

Tabelas que interessam: `cliente_contrato` (base, status, plano, datas),
`cliente` (endereço e bairro), `fn_areceber` (títulos recebidos),
`su_oss_chamado` (O.S. de instalação, para o tempo de ativação).

Para filtrar por período, o parâmetro de múltiplas condições é o
`grid_param`; confira o formato aceito na sua versão antes de confiar no
resultado. Na dúvida, puxe o período inteiro e filtre na planilha — erra
menos que um filtro que falha em silêncio.

O plano completo da integração, que dispensa este manual, está em
`INTEGRACAO.md`.
