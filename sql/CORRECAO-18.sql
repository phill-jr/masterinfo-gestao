-- ═══════════════════════════════════════════════════════════════════
-- CORREÇÃO 18 — Regras e fluxograma do canal de venda
--
-- A ficha do canal virou um hub: o canal no centro e as seções em
-- volta — o que é, meta, engajamento, regras, fluxograma e plano de
-- abertura. Duas dessas seções precisam de casa no banco:
--
--   `regras`     — as regras do jogo daquele canal: comissão, quem
--                  pode indicar, condições, SLA de contato, o que
--                  desclassifica uma indicação.
--   `fluxograma` — o caminho da venda no canal, uma etapa por linha.
--                  A tela desenha as caixas e as setas.
--
-- Idempotente: pode rodar de novo sem quebrar nada.
-- ═══════════════════════════════════════════════════════════════════

alter table canais_venda
  add column if not exists regras     text,
  add column if not exists fluxograma text;

comment on column canais_venda.regras is
  'Regras do canal: comissão, condições, SLA, desclassificação. Texto livre.';
comment on column canais_venda.fluxograma is
  'Fluxo da venda no canal, uma etapa por linha. A tela desenha caixas e setas.';
