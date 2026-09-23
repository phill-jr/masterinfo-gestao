# Prompt para gerar a apresentação do zero

Cole o bloco abaixo numa sessão nova. Ele é autossuficiente: não exige
explorar repositório, abrir o `index.html` (600 KB) nem fazer perguntas.

---

```
Crie UM arquivo HTML autônomo: placar-comercial.html. Sem build, sem framework,
sem servidor — abre com duplo clique. Não explore o repositório: tudo que você
precisa está neste prompt. Não faça perguntas; execute.

CONTEXTO
Provedor de fibra regional, +7.000 assinantes. Apresentação mensal do gestor
comercial para os sócios. 15 minutos, decisões no fim. O deck é projetado na
reunião e preenchido à mão até a integração existir.

JANELA — a regra que vale para tudo
Todo número é do DIA 1 AO DIA 20. Cada indicador aparece com: valor, variação
contra o mês anterior (mesma janela) e média dos 3 meses anteriores (mesma
janela). Mês de referência 2026-09; os outros três são derivados.
Indicador que já é taxa (%) varia em PONTO PERCENTUAL, nunca em % de %.

DADOS — regra inegociável
NÃO INVENTE NENHUM NÚMERO. O deck nasce vazio. Todo campo sem valor renderiza
"falta preencher" com uma frase dizendo POR QUE aquele número importa. Inclua
um botão "Ver exemplo" com números fictícios coerentes entre si, e enquanto ele
estiver ligado mostre uma tarja permanente: "Exemplo — não são os números da
MasterInfo".

OS 11 SLIDES (título · o que mostra · o que o slide precisa responder)
1 Faturamento e vendas · faturamento, vendas, ticket + série de 4 meses ·
  cresceu por volume ou por preço?
2 Cobertura e território · vendas por bairro, penetração (ativos÷casas
  passadas), inviabilidade separada em COBERTURA (não tem rede) e ANÁLISE
  (crédito) · onde há demanda sem rede?
3 Cancelamentos e crescimento líquido · total, perdidos antes de virar cliente
  (ME11 Perdido), churn de base, cascata vendas−cancelamentos=líquido ·
  a base cresceu de verdade?
4 Base ativa · base no fim da janela + série de 4 meses, escala cortada ·
  qual o tamanho real da operação?
5 Ticket médio e mix de planos · ticket + barra empilhada do mix ·
  o ticket subiu por reajuste ou por plano maior?
6 Custo de aquisição · CAC, investimento, payback (CAC÷ticket) + tabela por
  canal (investimento, leads, vendas, CPL, CAC, conversão) · onde investir?
7 Conversão do funil · LINHA DO TEMPO HORIZONTAL com 5 paradas — leads,
  atendidos, viáveis, propostas, vendas — cada parada com o número, e entre
  elas um selo com a % que passou. A maior queda fica em vermelho com
  "← maior queda" e uma causa provável específica daquela etapa. Abaixo,
  barras de volume. Some a simulação: +5 p.p. nessa etapa = quantas vendas a
  mais (propague pelas taxas seguintes) · onde a operação trava?
8 Velocidade da operação · ciclo de venda, tempo de ativação, soma dos dois,
  e "receita parada por dia de atraso" = ticket×vendas÷30 · quanto custa a
  demora?
9 Produtividade do time · tabela por vendedor (leads recebidos, vendas,
  conversão, ciclo, diferença contra a média em p.p.) + barras · quem puxa a
  média para cima e para baixo?
10 Comparativo dos três meses · tabela com vendas, faturamento, ticket e tempo
  de ativação nos 4 meses + média do trimestre + atual vs média · é tendência
  ou mês bom isolado?
11 Decisões · no máximo 3 cartões, cada um com o que fazer, quem, prazo e o
  indicador que precisa mover.

Cada slide leva: número/seção, título, subtítulo, os números, o gráfico,
3 bullets de leitura (causa e consequência, nunca só descrever o número) e uma
frase "O que isso significa". O roteiro de fala de 30–45 s NÃO fica no slide:
vai numa área de notas fora do palco, com botão para mostrar/esconder.

IDENTIDADE VISUAL MASTERINFO (use exatamente)
Fontes: Inter Tight 600/700 (títulos) + Inter 400–700 (corpo), via Google
Fonts; monoespaçada do sistema para rótulos e números tabulares.
Claro:   --bg#eceef3 --surf#ffffff --surf2#f5f6f9 --surf3#eceef3
         --line#e6e9ef --line2#d3d9e3 --ink#111318 --ink2#3d4351 --ink3#767d8d
         --marca#F47216
         séries: #F47216 #2a78d6 #1baf7a #4a3aa7 #e87ba4
         --good#059669 --warn#b45309 --bad#dc2626
Escuro:  --bg#0a0b0e --surf#101217 --surf2#161920 --surf3#1c2029
         --line#232833 --line2#2e3441 --ink#e9ecf2 --ink2#b3bac9 --ink3#7d8496
         --marca#dd6714
         séries: #dd6714 #3987e5 #199e70 #9085e9 #d55181
         --good#34d399 --warn#fbbf24 --bad#f87171
(O laranja da marca é claro demais para o fundo escuro; por isso o passo
#dd6714 no tema escuro. Essa paleta já foi validada para daltonismo.)

Defina TODOS os tokens no :root claro; redefina os escuros em
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){...}} E de
novo em :root[data-theme="dark"]{...}. body com background de token explícito.

Símbolo da marca — dois leques de ondas que se encaixam, laranja abrindo para
baixo e tinta para cima. Use como SVG inline no número de cada slide, e repita
o encaixe como régua de duas cores no rodapé do slide (56% laranja, o resto
tinta):
<svg viewBox="0 0 480 264"><g fill="none" stroke-width="30" stroke-linecap="round">
<g stroke="var(--marca)"><path d="M 4 168 A 144 144 0 0 1 292 168"/>
<path d="M 56 168 A 92 92 0 0 1 240 168"/><path d="M 108 168 A 40 40 0 0 1 188 168"/></g>
<g stroke="currentColor"><path d="M 188 96 A 144 144 0 0 0 476 96"/>
<path d="M 240 96 A 92 92 0 0 0 424 96"/><path d="M 292 96 A 40 40 0 0 0 372 96"/></g></g></svg>
Se existirem logo.png e logo-branca.png na pasta, embuta as duas como data URI
no canto superior direito do slide, trocando conforme o tema.

COMPORTAMENTO
- Slides 16:9 de verdade: palco fixo de 1280×720 com transform:scale ajustado
  ao contêiner, um slide por vez, sem rolagem de página.
- Abaixo de 720px de largura, abandone o 16:9 e empilhe para leitura.
- Botão Apresentar (fullscreen), setas ← →, tecla F, espaço avança.
- Âncora #slide-N na URL, com hashchange funcionando.
- Painel lateral "Editar dados": seletor de mês, campos do período, funil, e
  textareas para bairros, planos, canais, vendedores e decisões (uma linha por
  item, separador ";" ou tabulação, decimal com vírgula).
- Campo "Colar tudo" que lê este bloco de uma vez (a linha MES escolhe o mês):
  MES: / FATURAMENTO: / VENDAS: / CANCELAMENTOS: / PERDIDOS: / BASE: /
  TICKET: / INVESTIMENTO: / CICLO: / ATIVACAO: /
  FUNIL: leads; atendidos; viaveis; propostas; vendas /
  BAIRROS: nome; casas; ativos; vendas; invCobertura; invAnalise /
  PLANOS: nome; vendas; valor / CANAIS: nome; investimento; leads; vendas /
  VENDEDORES: nome; leads; vendas; ciclo / DECISOES: o que; quem; prazo; indicador
  Ignore a linha-modelo que começa com "nome" ou "o que fazer".
- Persistência em localStorage, dentro de try/catch, funcionando sem ela.

DUAS LACUNAS QUE O DECK DEVE DECLARAR, NÃO CONTORNAR
1. Casas passadas por bairro não existe em fonte nenhuma (é planilha da
   engenharia). Sem isso não há penetração.
2. O Bitrix não grava a origem do negócio, então não existe CAC por canal —
   só CAC geral. O slide 6 precisa dizer isso na tela.

ARMADILHAS JÁ CONHECIDAS — evite, custaram rodadas de correção
- <span> é inline: width/height são ignorados. Barra de gráfico precisa de
  display:block no trilho E na barra.
- Não reutilize nome de classe. Uma ".barra" usada na barra de controles e na
  barra do gráfico faz o margin:0 auto de uma centralizar a outra.
- <li> com display:flex transforma cada <b> do texto em item de flex e quebra
  a frase. Use marcador com ::before absoluto.
- Série de 4 meses com valores próximos precisa de escala cortada (mínimo da
  série como zero) + nota dizendo que a barra não começa no zero.
- Tabela com 6+ colunas não cabe em meia largura de slide; em slide não existe
  rolagem, então a coluna some. Use a largura inteira.
- Grade de tiles com auto-fit deixa célula órfã vazia. Fixe 2 colunas.
- Conteúdo curto grudado no topo deixa meio slide morto: centralize o corpo.
- Cor que significa ESTADO (cancelamento, acima/abaixo da média) usa as cores
  semânticas, sempre com legenda e valor ao lado, nunca cor sozinha.

VERIFICAÇÃO ANTES DE ENTREGAR (uma passada só)
Renderize e confirme por script, não a olho: nenhum dos 11 slides ultrapassa
722px de altura nem 1282px de largura, com dados E vazio; zero erro de
JavaScript; as barras começam no offset 0 do trilho. Um screenshot, no máximo.

ECONOMIA DE TOKEN
Escreva o arquivo inteiro de uma vez, não incremental. Não leia index.html.
Não peça aprovação no meio. Não resuma o que fez em mais de 10 linhas.
```
