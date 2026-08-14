-- =====================================================================
-- CORREÇÃO 14 — APOSENTA O ONBOARDING DO MÓDULO VENDEDORES
-- =====================================================================
-- Em 14/08/2026 o banco passou a ter dois onboardings ao mesmo tempo:
--
--   vd_trilhas / vd_trilha_etapas / vd_pops / vd_fluxos
--       do módulo Vendedores. Trilha como lista de dias, POP e fluxo
--       como cadastro próprio. Sem prova, sem material anexado.
--
--   onb_*  (CORRECAO-13.sql)
--       trilha → módulo → aula, com prova corrigida no banco e o HTML
--       do treinamento anexado à aula.
--
-- Duas telas com a Trilha do Calouro divergindo em silêncio é pior que
-- qualquer uma das duas sozinha. Ficou a estrutura nova, que é
-- superconjunto da antiga.
--
-- O CONTEÚDO QUE SÓ EXISTIA AQUI JÁ FOI MIGRADO, em ONBOARDING-SEED.sql:
--   · quem conduz cada dia (Gestor · Líder · Time) → nas aulas dos dias
--   · os Dias 11 a 14                              → aula própria
--   · os 3 fluxos (funil, venda etapa a etapa,     → módulo "Os fluxos
--     cadência)                                       do Comercial"
--   · os 12 POPs                                   → biblioteca de
--                                                     treinamentos, em HTML
--   · vd_trilha_progresso                          → estava vazia
--
-- O Dicionário da Casa NÃO é afetado: vd_termos e vd_buscas_sem_resultado
-- continuam de pé, e a tela continua no menu Vendedores.
--
-- Confira a migração antes de rodar. Isto apaga as tabelas.
--
--   python aplicar-sql.py sql/CORRECAO-14.sql
-- =====================================================================

-- Última chance de olhar o que vai embora: rode este select sozinho
-- antes, se quiser conferir.
--   select dia, titulo, conduz from vd_trilha_etapas order by dia;
--   select nome, etapas from vd_fluxos;

drop table if exists vd_trilha_progresso cascade;
drop table if exists vd_trilha_etapas    cascade;
drop table if exists vd_trilhas          cascade;
drop table if exists vd_pops             cascade;
drop table if exists vd_fluxos           cascade;

-- =====================================================================
-- Conferência
-- =====================================================================
select table_name
  from information_schema.tables
 where table_schema = 'public' and table_name like 'vd_%'
 order by table_name;
