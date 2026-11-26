-- Garopaba Algodoeira · banco do app (Supabase / Postgres)
-- Rodar uma vez no SQL Editor do projeto (ou via migração).

-- 1) Perfis (cadastro com departamento)
create table if not exists public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  email text,
  departamento text not null check (departamento in ('Comercial','Financeiro','Contábil','Faturamento','Logística','Jurídico')),
  status text not null default 'pendente' check (status in ('pendente','ativo','bloqueado')),
  papel text not null default 'usuario' check (papel in ('usuario','admin')),
  criado_em timestamptz not null default now()
);
alter table public.perfis enable row level security;

create or replace function public.is_ativo() returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from perfis where id = auth.uid() and status = 'ativo') $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from perfis where id = auth.uid() and status = 'ativo' and papel = 'admin') $$;
create or replace function public.meu_depto() returns text language sql stable security definer set search_path = public as
$$ select departamento from perfis where id = auth.uid() $$;

-- novo usuário → perfil pendente (o primeiro cadastro vira administrador liberado)
create or replace function public.novo_usuario() returns trigger language plpgsql security definer set search_path = public as $$
declare primeiro boolean;
begin
  select not exists(select 1 from perfis) into primeiro;
  insert into perfis(id, nome, email, departamento, status, papel)
  values (new.id,
          coalesce(nullif(trim(new.raw_user_meta_data->>'nome'),''), split_part(new.email,'@',1)),
          new.email,
          case when new.raw_user_meta_data->>'departamento' in ('Comercial','Financeiro','Contábil','Faturamento','Logística','Jurídico')
               then new.raw_user_meta_data->>'departamento' else 'Comercial' end,
          case when primeiro then 'ativo' else 'pendente' end,
          case when primeiro then 'admin' else 'usuario' end);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.novo_usuario();

drop policy if exists perfis_ver on public.perfis;
create policy perfis_ver on public.perfis for select to authenticated using (id = auth.uid() or public.is_ativo());
drop policy if exists perfis_admin on public.perfis;
create policy perfis_admin on public.perfis for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 2) Documentos compartilhados (cotações, notícias, notícias por dia)
create table if not exists public.docs (
  path text primary key,
  data jsonb not null,
  atualizado_em timestamptz not null default now()
);
alter table public.docs enable row level security;
drop policy if exists docs_ver on public.docs;
create policy docs_ver on public.docs for select to authenticated using (public.is_ativo());
drop policy if exists docs_ins on public.docs;
create policy docs_ins on public.docs for insert to authenticated with check (public.is_admin());
drop policy if exists docs_upd on public.docs;
create policy docs_upd on public.docs for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 3) Histórico das calculadoras, separado por departamento
create table if not exists public.historico (
  id uuid primary key default gen_random_uuid(),
  departamento text not null,
  criado_por uuid references public.perfis(id) on delete set null,
  criado_em timestamptz not null default now(),
  tipo text not null,
  ref date,
  titulo text, res text, sub text,
  inputs jsonb, fidc text, bruto numeric, nfs jsonb
);
create index if not exists historico_depto_em on public.historico(departamento, criado_em desc);
alter table public.historico enable row level security;

create or replace function public.historico_dono() returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.criado_por := auth.uid();
  new.departamento := (select departamento from perfis where id = auth.uid());
  new.criado_em := now();
  return new;
end $$;
drop trigger if exists historico_dono on public.historico;
create trigger historico_dono before insert on public.historico for each row execute function public.historico_dono();

drop policy if exists hist_ver on public.historico;
create policy hist_ver on public.historico for select to authenticated using (public.is_admin() or (public.is_ativo() and departamento = public.meu_depto()));
drop policy if exists hist_ins on public.historico;
create policy hist_ins on public.historico for insert to authenticated with check (public.is_ativo());
drop policy if exists hist_del on public.historico;
create policy hist_del on public.historico for delete to authenticated using (public.is_admin() or (public.is_ativo() and departamento = public.meu_depto()));

-- 4) Atualização ao vivo
do $$ begin
  begin alter publication supabase_realtime add table public.docs; exception when others then null; end;
  begin alter publication supabase_realtime add table public.historico; exception when others then null; end;
end $$;
