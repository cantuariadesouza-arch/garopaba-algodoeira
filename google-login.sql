-- Garopaba Algodoeira · login com Google
-- Quem entra pelo Google ainda não escolheu o departamento: o app pede isso na primeira entrada.

alter table public.perfis add column if not exists depto_ok boolean not null default true;

create or replace function public.novo_usuario() returns trigger language plpgsql security definer set search_path = public as $$
declare primeiro boolean; dep text; ok boolean;
begin
  select not exists(select 1 from perfis) into primeiro;
  dep := new.raw_user_meta_data->>'departamento';
  ok := coalesce(dep in ('Comercial','Financeiro','Contábil','Faturamento','Logística','Jurídico'), false);
  insert into perfis(id, nome, email, departamento, status, papel, depto_ok)
  values (new.id,
          coalesce(nullif(trim(new.raw_user_meta_data->>'nome'),''),
                   nullif(trim(new.raw_user_meta_data->>'full_name'),''),
                   nullif(trim(new.raw_user_meta_data->>'name'),''),
                   split_part(new.email,'@',1)),
          new.email,
          case when ok then dep else 'Comercial' end,
          case when primeiro then 'ativo' else 'pendente' end,
          case when primeiro then 'admin' else 'usuario' end,
          ok);
  return new;
end $$;

-- o próprio usuário confirma nome e departamento uma única vez (só enquanto depto_ok = false)
create or replace function public.completar_cadastro(p_nome text, p_depto text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_depto not in ('Comercial','Financeiro','Contábil','Faturamento','Logística','Jurídico') then
    raise exception 'Departamento inválido';
  end if;
  update perfis
     set nome = coalesce(nullif(trim(p_nome),''), nome),
         departamento = p_depto,
         depto_ok = true
   where id = auth.uid() and depto_ok = false;
end $$;
revoke all on function public.completar_cadastro(text, text) from public, anon;
grant execute on function public.completar_cadastro(text, text) to authenticated;
