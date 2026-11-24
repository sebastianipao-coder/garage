-- Notifiche push 7 giorni prima delle scadenze.
-- (Le chiavi VAPID e il segreto del controllo giornaliero vanno inseriti a parte in private.push_config.)
create table if not exists private.push_config (id int primary key default 1 check (id = 1), cfg jsonb not null);
alter table private.push_config enable row level security;
create table if not exists private.push_iscrizioni (
  endpoint text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  sub jsonb not null,
  creato timestamptz not null default now()
);
alter table private.push_iscrizioni enable row level security;

-- Dall'app: salva o rimuove l'iscrizione del dispositivo
create or replace function public.salva_push(sub jsonb) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_membro() then raise exception 'non autorizzato'; end if;
  insert into private.push_iscrizioni (endpoint, user_id, sub) values (sub->>'endpoint', auth.uid(), sub)
  on conflict (endpoint) do update set user_id = excluded.user_id, sub = excluded.sub;
end $$;
create or replace function public.rimuovi_push(endpoint text) returns void
language sql security definer set search_path = '' as $$
  delete from private.push_iscrizioni p where p.endpoint = rimuovi_push.endpoint and p.user_id = auth.uid();
$$;
create or replace function public.push_vapid() returns text
language sql stable security definer set search_path = '' as $$
  select cfg->>'vapid_public' from private.push_config where id = 1;
$$;
revoke execute on function public.salva_push(jsonb), public.rimuovi_push(text), public.push_vapid() from public, anon;
grant execute on function public.salva_push(jsonb), public.rimuovi_push(text), public.push_vapid() to authenticated;

-- Solo per il servizio che invia le notifiche (service_role)
create or replace function public.push_config() returns jsonb
language sql stable security definer set search_path = '' as $$ select cfg from private.push_config where id = 1; $$;
create or replace function public.push_iscrizioni(uid uuid default null) returns table (endpoint text, sub jsonb)
language sql stable security definer set search_path = '' as $$
  select p.endpoint, p.sub from private.push_iscrizioni p
  join public.membri m on m.user_id = p.user_id
  where uid is null or p.user_id = uid;
$$;
create or replace function public.push_rimuovi_endpoint(e text) returns void
language sql security definer set search_path = '' as $$ delete from private.push_iscrizioni where endpoint = e; $$;
create or replace function public.push_scadenze(giorni int) returns table (tipo text, moto text, data date)
language sql stable security definer set search_path = '' as $$
  select s.l, trim(coalesce('N. ' || (m.data->>'numero') || ' ', '') || coalesce(m.data->>'marca', '') || ' ' || coalesce(m.data->>'modello', '')
               || coalesce(' (' || nullif(m.data->>'targa', '') || ')', '')), (m.data->>s.k)::date
  from public.moto m
  cross join (values ('scadAssicurazione', 'Assicurazione'), ('scadBollo', 'Bollo'), ('scadRevisione', 'Revisione')) as s(k, l)
  where coalesce(m.data->>s.k, '') ~ '^\d{4}-\d{2}-\d{2}$'
    and (m.data->>s.k)::date = (now() at time zone 'Europe/Rome')::date + giorni
    and coalesce(m.data->>'stato', 'Attiva') not in ('Venduta', 'Demolita')
    and not (s.k = 'scadBollo' and coalesce((m.data->>'bolloEsente')::boolean, false))
  order by (m.data->>'numero')::int nulls last;
$$;
revoke execute on function public.push_config(), public.push_iscrizioni(uuid), public.push_rimuovi_endpoint(text), public.push_scadenze(int) from public, anon, authenticated;
grant execute on function public.push_config(), public.push_iscrizioni(uuid), public.push_rimuovi_endpoint(text), public.push_scadenze(int) to service_role;
