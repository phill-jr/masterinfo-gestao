-- =====================================================================
-- CORREÇÃO 19 — Documento HTML anexado ao canal
-- ---------------------------------------------------------------------
-- O canal ganha um documento HTML próprio (playbook, plano, regras…),
-- guardado inteiro no banco e exibido em iframe sandbox — mesmo modelo
-- do onb_treinamentos. Se o arquivo trouxer um bloco
-- <script type="application/json" id="canal-config">, o app usa esse
-- JSON para preencher os campos estruturados do canal ao anexar.
-- Pode rodar mais de uma vez sem duplicar nada.
-- =====================================================================

alter table canais_venda add column if not exists doc_html text;

comment on column canais_venda.doc_html is
  'Documento HTML do canal, arquivo inteiro. Exibido em iframe sandbox; opcionalmente carrega um bloco canal-config (JSON) que preenche os campos do canal.';
