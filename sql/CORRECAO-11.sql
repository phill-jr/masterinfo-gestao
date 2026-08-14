-- ================================================================
-- CORREÇÃO 11 — Imagens nas anotações
--
-- As imagens vão para o Storage, não para uma coluna de texto.
-- Print de conversa tem centenas de KB; guardado como texto no
-- banco, cada abertura da lista baixaria todas as imagens de todas
-- as notas.
--
-- O bucket é PRIVADO. O sistema gera um link temporário na hora de
-- exibir. Bucket público significaria que qualquer um com a URL vê
-- a imagem, e nota interna às vezes tem print de conversa.
--
-- Aplicado por: python aplicar-sql.py sql/CORRECAO-11.sql
-- ================================================================

alter table anotacoes add column if not exists anexos jsonb not null default '[]'::jsonb;

comment on column anotacoes.anexos is
  'Lista de imagens: [{path, nome, tipo, tamanho}]. O arquivo vive no bucket "anexos".';


-- ----------------------------------------------------------------
-- Bucket privado
-- ----------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('anexos', 'anexos', false, 8388608,
        array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update
  set public = false,
      file_size_limit = 8388608,
      allowed_mime_types = array['image/png','image/jpeg','image/webp','image/gif'];


-- ----------------------------------------------------------------
-- Permissões — mesma regra do resto: só quem tem acesso ao sistema
-- ----------------------------------------------------------------

drop policy if exists anexos_ler     on storage.objects;
drop policy if exists anexos_gravar  on storage.objects;
drop policy if exists anexos_apagar  on storage.objects;

create policy anexos_ler on storage.objects for select to authenticated
  using (bucket_id = 'anexos' and tem_acesso());

create policy anexos_gravar on storage.objects for insert to authenticated
  with check (bucket_id = 'anexos' and tem_acesso());

create policy anexos_apagar on storage.objects for delete to authenticated
  using (bucket_id = 'anexos' and tem_acesso());


select id, public, file_size_limit from storage.buckets where id = 'anexos';
