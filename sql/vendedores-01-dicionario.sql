-- ═══════════════════════════════════════════════════════════════════
--  MÓDULO VENDEDORES — bloco 1: Dicionário da Casa
--
--  Rode este arquivo inteiro no SQL Editor do Supabase deste projeto
--  (o mesmo que está em config.js). Pode rodar mais de uma vez: tudo
--  é "if not exists" / "create or replace".
--
--  O que ele cria:
--    vd_termos               — os verbetes
--    vd_buscas_sem_resultado — o que procuraram e não acharam
--
--  Segurança: mesmo padrão das outras tabelas de empresa deste
--  sistema — quem está logado lê e escreve; quem não está, não vê
--  nada. O campo `status` é fluxo de trabalho (rascunho → publicado),
--  não é controle de acesso.
-- ═══════════════════════════════════════════════════════════════════

create extension if not exists pg_trgm;

-- ── Verbetes ──────────────────────────────────────────────────────
create table if not exists vd_termos (
  id            uuid primary key default gen_random_uuid(),
  termo         text not null,
  sinonimos     text,           -- separados por vírgula; é o que faz achar com escrita errada
  categoria     text not null default 'tecnico',   -- tecnico | produto | processo | comercial | cultura
  nivel         text not null default 'basico',    -- basico | avancado
  explicacao    text not null,
  cliente_chama text,           -- como o CLIENTE chama isso
  explicar_ao_cliente text,     -- a frase pronta, do jeito que pode ser dita numa ligação
  cuidado       text,           -- o erro comum do vendedor novo, e o que acontece quando erra
  status        text not null default 'rascunho',  -- rascunho | publicado | arquivado
  autor_id      uuid references usuarios(id) on delete set null,
  revisado_em   date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create unique index if not exists vd_termos_unico   on vd_termos (lower(termo));
create index        if not exists vd_termos_trgm    on vd_termos using gin (termo gin_trgm_ops);
create index        if not exists vd_termos_sin_trgm on vd_termos using gin (coalesce(sinonimos,'') gin_trgm_ops);
create index        if not exists vd_termos_status  on vd_termos (status);

-- updated_at sem depender do frontend
create or replace function vd_touch() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists vd_termos_touch on vd_termos;
create trigger vd_termos_touch before update on vd_termos
  for each row execute function vd_touch();

-- ── Buscas sem resultado ──────────────────────────────────────────
-- A lista mais honesta do que falta escrever: veio de dúvida real.
create table if not exists vd_buscas_sem_resultado (
  id         uuid primary key default gen_random_uuid(),
  texto      text not null,
  usuario_id uuid references usuarios(id) on delete set null,
  resolvido  boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists vd_buscas_data on vd_buscas_sem_resultado (created_at desc);

-- ── RLS ───────────────────────────────────────────────────────────
alter table vd_termos               enable row level security;
alter table vd_buscas_sem_resultado enable row level security;

drop policy if exists vd_termos_rw on vd_termos;
create policy vd_termos_rw on vd_termos
  for all to authenticated using (true) with check (true);

drop policy if exists vd_buscas_rw on vd_buscas_sem_resultado;
create policy vd_buscas_rw on vd_buscas_sem_resultado
  for all to authenticated using (true) with check (true);

-- ── Conteúdo inicial ──────────────────────────────────────────────
-- Cinco verbetes em RASCUNHO, como modelo de formato. Ninguém vê como
-- material oficial até alguém revisar e publicar.
insert into vd_termos (termo, sinonimos, categoria, nivel, explicacao,
                       cliente_chama, explicar_ao_cliente, cuidado, status)
values
('Viabilidade', 'viabilidade técnica, tem viabilidade, viabilidade de instalação', 'processo', 'basico',
 'Consulta que diz se o endereço do cliente pode ser atendido pela nossa rede: se existe caixa (CTO) por perto e se ela tem porta livre.',
 'O cliente pergunta "vocês atendem aqui na minha rua?".',
 'Vou confirmar se a nossa fibra já chega no seu endereço. É rápido, só preciso do endereço completo com número.',
 'Vender sem consultar viabilidade. O contrato entra, o técnico vai até o local, não instala, e a visita perdida sai do bolso da operação — além do cliente começar a relação com uma frustração.',
 'rascunho'),

('FTTH', 'fibra até a casa, fiber to the home, fibra pura, 100% fibra', 'tecnico', 'basico',
 'Fibra óptica que entra dentro da casa do cliente, sem trecho de cabo metálico no caminho. É o que sustenta a promessa de sinal estável.',
 'O cliente chama de "fibra" ou "internet a laser".',
 'A fibra entra dentro da sua casa, não para no poste. Por isso o sinal não oscila quando chove nem cai no horário de pico.',
 'Falar "FTTH" com o cliente. A sigla não significa nada para ele — o que significa é "não cai quando chove".',
 'rascunho'),

('ONU', 'onu, modem da fibra, caixinha da fibra, ont', 'tecnico', 'basico',
 'O aparelho instalado na casa do cliente que recebe a fibra e entrega a internet. Em muitos casos é ele também que faz o Wi-Fi.',
 'O cliente chama de "modem", "roteador" ou "a caixinha de vocês".',
 'É o aparelho que fica na sua casa recebendo a fibra. Ele é nosso e fica com você enquanto o plano estiver ativo.',
 'Prometer troca de aparelho por conta própria. Troca tem regra — confirme antes de falar qualquer coisa para o cliente.',
 'rascunho'),

('Wi-Fi mesh', 'mesh, repetidor, wifi na casa toda, roteador secundário', 'produto', 'basico',
 'Segundo roteador que trabalha junto com o principal e espalha o mesmo Wi-Fi pela casa, sem o cliente precisar trocar de rede ao andar de um cômodo para outro.',
 'O cliente diz "não pega no quarto" ou "quero internet no fundo da casa".',
 'A gente coloca um segundo ponto de Wi-Fi na parte da casa onde o sinal não chega. É a mesma rede, o celular não precisa trocar.',
 'Vender mais velocidade para quem tem problema de alcance. O cliente paga mais caro, o Wi-Fi continua fraco no fundo da casa, e ele cancela achando que foi enganado.',
 'rascunho'),

('Upload x download', 'upload, download, subida e descida, banda simétrica', 'tecnico', 'basico',
 'Download é o que chega até o cliente (assistir, baixar). Upload é o que sai dele (chamada de vídeo, enviar arquivo, câmera de segurança). Quem trabalha em casa sente mais o upload.',
 'O cliente diz "minha reunião trava" ou "a câmera fica falhando".',
 'Reunião travando quase nunca é a velocidade de descida — é a de subida. É nela que a gente precisa olhar no seu caso.',
 'Ouvir "reunião travando" e oferecer o plano mais caro. Antes de subir o plano, entenda se o problema é upload, Wi-Fi ou o aparelho do cliente.',
 'rascunho')
on conflict do nothing;
