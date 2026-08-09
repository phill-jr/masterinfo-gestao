/* ═══════════════════════════════════════════════════════════════════
   CONFIGURAÇÃO DO PROJETO SUPABASE

   Já preenchido. O sistema não pergunta mais o projeto — vale em
   qualquer navegador e em qualquer máquina.

   Onde achar, caso precise trocar:
   Supabase → Project Settings → API Keys
     url = "Project URL"
     key = "Publishable key" (sb_publishable_…) ou "anon public"

   A chave publishable é pública por natureza — todo app Supabase
   publica a dele. Quem protege os dados é o RLS, que exige login.
   Por isso o cadastro público PRECISA ficar desligado:
   Authentication → Sign In / Providers → desmarcar
   "Allow new users to sign up".
   ═══════════════════════════════════════════════════════════════════ */

window.MI_CONFIG = {
  url: "https://ivkmsrypetpcmaatbvtx.supabase.co",
  key: "sb_publishable_qMGtHperzU7aXq5Tnf2XFA_TdQGnM4M"
};
