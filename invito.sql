-- Link di invito per i collaboratori.
-- Solo i "membri" vedono e modificano i dati. Si diventa membri registrandosi
-- dal link di invito (che contiene il codice) oppure se creati dal pannello Supabase
-- e aggiunti a questa tabella.

create table if not exists public.membri (
  user_id uuid primary key references auth.users(id) on delete cascade,
  creato timestamptz not null default now()
);
alter table public.membri enable row level security;
revoke all on public.membri from anon, authenticated;

create schema if not exists private;
create table if not exists private.invito (id int primary key default 1 check (id = 1), codice text not null);
insert into private.invito (codice) values (encode(extensions.gen_random_bytes(12), 'hex')) on conflict (id) do nothing;

-- Gli utenti già esistenti (creati dal pannello) diventano membri.
insert into public.membri (user_id) select id from auth.users on conflict do nothing;

create or replace function public.is_membro() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.membri where user_id = auth.uid());
$$;

-- Alla registrazione: se il codice è quello giusto, il nuovo utente diventa membro.
create or replace function private.nuovo_utente() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.raw_user_meta_data->>'invito', '') = (select codice from private.invito where id = 1) then
    insert into public.membri (user_id) values (new.id) on conflict do nothing;
  end if;
  return new;
end $$;
drop trigger if exists garage_nuovo_utente on auth.users;
create trigger garage_nuovo_utente after insert on auth.users
  for each row execute function private.nuovo_utente();

-- Codice attuale e rigenerazione (solo per i membri).
create or replace function public.codice_invito() returns text
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_membro() then raise exception 'non autorizzato'; end if;
  return (select codice from private.invito where id = 1);
end $$;

create or replace function public.rigenera_invito() returns text
language plpgsql security definer set search_path = '' as $$
declare c text := encode(extensions.gen_random_bytes(12), 'hex');
begin
  if not public.is_membro() then raise exception 'non autorizzato'; end if;
  update private.invito set codice = c where id = 1;
  return c;
end $$;

revoke execute on function public.is_membro(), public.codice_invito(), public.rigenera_invito() from public, anon;
grant execute on function public.is_membro(), public.codice_invito(), public.rigenera_invito() to authenticated;

-- I dati sono accessibili solo ai membri.
do $$
declare t text;
begin
  foreach t in array array['moto','interventi','documenti','ricambi'] loop
    execute format('drop policy if exists garage_accesso on public.%I', t);
    execute format('create policy garage_accesso on public.%I for all to authenticated using (public.is_membro()) with check (public.is_membro())', t);
  end loop;
end $$;

drop policy if exists garage_file on storage.objects;
create policy garage_file on storage.objects for all to authenticated
  using (bucket_id = 'documenti' and public.is_membro())
  with check (bucket_id = 'documenti' and public.is_membro());
