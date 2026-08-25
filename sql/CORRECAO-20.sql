-- =====================================================================
-- CORREÇÃO 20 — Preparar o sistema para mais pessoas
-- ---------------------------------------------------------------------
-- Até aqui a trava de papel/módulos era só de interface (podeVer no
-- app); com uma pessoa só isso bastava. Antes de convidar o time, o
-- banco passa a garantir três coisas que a interface não garante:
--
--   1. usuarios  — membro não muda papel, módulos, líder, ativo nem
--                  vínculo de login (nem o próprio: sem autopromoção
--                  a admin pela API). Excluir pessoa é só admin.
--   2. convites  — criar/alterar/apagar convite é só admin.
--   3. gabarito  — a coluna onb_alternativas.correta some da API para
--                  membro (fecha a brecha anotada na CORRECAO-13);
--                  o editor de provas do admin lê pela view
--                  onb_alternativas_gabarito.
--
-- Pode rodar mais de uma vez sem duplicar nada.
-- =====================================================================

-- ── eh_admin(): espelho do tem_acesso(), com a mesma cláusula de
--    bootstrap — enquanto ninguém tem login vinculado, todo mundo é
--    "admin", senão uma instalação nova trancaria o instalador fora.
create or replace function eh_admin()
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select not exists (select 1 from usuarios where auth_user_id is not null)
      or exists (select 1 from usuarios
                  where auth_user_id = auth.uid() and ativo and papel = 'admin');
$$;

-- ── 1. usuarios: campos de acesso só mudam pela mão de um admin.
--    Trigger e não policy porque a regra é por COLUNA, e RLS não
--    enxerga coluna. A exceção "vinculando" é o aceitar_convite():
--    a pessoa convidada liga o próprio login (auth_user_id null →
--    auth.uid()) e reativa o cadastro, e só isso.
create or replace function usuarios_protege()
returns trigger
language plpgsql security definer
set search_path to 'public'
as $$
declare
  vinculando boolean;
begin
  /* Sem JWT (auth.uid() nulo) a chamada é do service role ou do SQL
     Editor — confiáveis, já passam por cima da RLS. O anon nunca
     chega aqui: a RLS barra antes. A trava é para MEMBRO logado. */
  if auth.uid() is null or eh_admin() then return coalesce(new, old); end if;

  if tg_op = 'DELETE' then
    raise exception 'Excluir pessoa é ação de admin.';
  end if;

  if tg_op = 'INSERT' then
    if new.papel = 'admin' then
      raise exception 'Só um admin cria outro admin.';
    end if;
    return new;
  end if;

  vinculando := old.auth_user_id is null and new.auth_user_id = auth.uid();

  if new.papel     is distinct from old.papel
     or new.modulos  is distinct from old.modulos
     or new.lider_id is distinct from old.lider_id then
    raise exception 'Papel, módulos e líder só mudam pela mão de um admin.';
  end if;
  if new.ativo is distinct from old.ativo and not vinculando then
    raise exception 'Ativar/desativar pessoa é ação de admin.';
  end if;
  if new.auth_user_id is distinct from old.auth_user_id and not vinculando then
    raise exception 'Vínculo de login só muda pela mão de um admin.';
  end if;
  return new;
end $$;

drop trigger if exists trg_usuarios_protege on usuarios;
create trigger trg_usuarios_protege
  before insert or update or delete on usuarios
  for each row execute function usuarios_protege();

-- ── 2. convites: só admin administra. O aceitar_convite() continua
--    funcionando para o convidado porque é SECURITY DEFINER do dono
--    do schema, que passa por cima da RLS.
drop policy if exists p_interno on convites;
drop policy if exists p_admin   on convites;
create policy p_admin on convites
  for all using (eh_admin()) with check (eh_admin());

-- ── 3. gabarito: membro lê alternativa sem a coluna correta.
--    Grants de coluna no SELECT; escrita vira admin-only por policy.
revoke select, insert, update, delete on onb_alternativas from authenticated;
grant select (id, questao_id, texto, ordem) on onb_alternativas to authenticated;
grant insert, update, delete on onb_alternativas to authenticated;  -- a policy abaixo é quem barra

drop policy if exists p_interno  on onb_alternativas;
drop policy if exists p_ler      on onb_alternativas;
drop policy if exists p_escrever on onb_alternativas;
drop policy if exists p_alterar  on onb_alternativas;
drop policy if exists p_apagar   on onb_alternativas;
create policy p_ler      on onb_alternativas for select using (tem_acesso());
create policy p_escrever on onb_alternativas for insert with check (eh_admin());
create policy p_alterar  on onb_alternativas for update using (eh_admin()) with check (eh_admin());
create policy p_apagar   on onb_alternativas for delete using (eh_admin());

-- View do editor de provas: roda como o dono (de propósito — é o que
-- deixa o admin ler a coluna que o grant esconde) e devolve zero
-- linhas para quem não é admin.
drop view if exists onb_alternativas_gabarito;
create view onb_alternativas_gabarito as
  select a.* from onb_alternativas a where eh_admin();
grant select on onb_alternativas_gabarito to authenticated;

comment on function eh_admin() is
  'Usuário vinculado, ativo e com papel admin (ou instalação ainda sem ninguém vinculado — bootstrap).';
comment on view onb_alternativas_gabarito is
  'Alternativas COM a coluna correta, só para admin. O editor de provas lê daqui; a prova do aluno lê a tabela, que não expõe correta.';
