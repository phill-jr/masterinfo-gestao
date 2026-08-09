/* ═══════════════════════════════════════════════════════════════════
   CONFIGURAÇÃO DO PROJETO — preencha as duas linhas abaixo UMA VEZ.

   Onde achar: Supabase → seu projeto → Project Settings → API
     url = "Project URL"        (https://xxxxx.supabase.co)
     key = "anon public"        (texto gigante começando com eyJ)

   Depois de preencher, o sistema nunca mais pergunta o projeto,
   em nenhum navegador e em nenhuma máquina.

   A chave anon é pública por natureza — todo app Supabase publica a
   dele. Quem protege os dados é o RLS, que exige login. Por isso o
   cadastro público PRECISA ficar desligado no Supabase:
   Authentication → Sign In / Providers → desmarcar
   "Allow new users to sign up".
   ═══════════════════════════════════════════════════════════════════ */

window.MI_CONFIG = {
  url: "",
  key: ""
};
