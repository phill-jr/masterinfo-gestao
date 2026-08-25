-- =====================================================================
-- CORREÇÃO 21 — Anotações viram pessoais
-- ---------------------------------------------------------------------
-- Pedido do Philipe (25/08): "as minhas coisas ninguém pode ver".
-- Anotação passa a ser do AUTOR: cada pessoa lê, edita e apaga só o
-- que ela mesma escreveu — inclusive o admin não lê as dos outros
-- (mesmo espírito do financeiro pessoal, fin_*). O campo usuario_id
-- continua sendo "sobre quem" e não muda nada aqui.
-- Pode rodar mais de uma vez sem duplicar nada.
-- =====================================================================

-- Notas antigas sem autor ficam com o admin (hoje, o Philipe) — sem
-- isso elas sumiriam para todo mundo.
update anotacoes
   set autor_id = (select id from usuarios
                    where papel = 'admin' and auth_user_id is not null
                    order by created_at limit 1)
 where autor_id is null;

drop policy if exists p_interno on anotacoes;
drop policy if exists p_autor   on anotacoes;
create policy p_autor on anotacoes
  for all
  using (exists (select 1 from usuarios u
                  where u.id = anotacoes.autor_id
                    and u.auth_user_id = auth.uid()))
  with check (exists (select 1 from usuarios u
                       where u.id = anotacoes.autor_id
                         and u.auth_user_id = auth.uid()));

comment on table anotacoes is
  'Anotações PESSOAIS: cada linha pertence ao autor_id e só ele a vê (RLS p_autor, correção 21). usuario_id = sobre quem é a nota.';
