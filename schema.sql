-- Garage Moto e Ricambi: tabelle, sicurezza e archivio documenti.
-- Da eseguire una sola volta nel SQL Editor di Supabase.

create table if not exists public.moto       (id uuid primary key default gen_random_uuid(), data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create table if not exists public.interventi (id uuid primary key default gen_random_uuid(), data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create table if not exists public.documenti  (id uuid primary key default gen_random_uuid(), data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create table if not exists public.ricambi    (id uuid primary key default gen_random_uuid(), data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());

-- Solo gli utenti che hanno fatto l'accesso possono leggere e scrivere.
do $$
declare t text;
begin
  foreach t in array array['moto','interventi','documenti','ricambi'] loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists garage_accesso on public.%I', t);
    execute format('create policy garage_accesso on public.%I for all to authenticated using (true) with check (true)', t);
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- Archivio privato per libretti, fatture e manuali.
insert into storage.buckets (id, name, public, file_size_limit)
values ('documenti', 'documenti', false, 20971520)
on conflict (id) do nothing;

drop policy if exists garage_file on storage.objects;
create policy garage_file on storage.objects for all to authenticated
  using (bucket_id = 'documenti') with check (bucket_id = 'documenti');
