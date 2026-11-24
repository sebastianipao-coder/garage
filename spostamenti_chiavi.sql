-- Spostamenti tra sedi (storico)
create table if not exists public.spostamenti (id uuid primary key default gen_random_uuid(), data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
grant select, insert, update, delete on public.spostamenti to authenticated;
revoke all on public.spostamenti from anon;
alter table public.spostamenti enable row level security;
drop policy if exists garage_accesso on public.spostamenti;
create policy garage_accesso on public.spostamenti for all to authenticated using (public.is_membro()) with check (public.is_membro());
do $$ begin
  alter publication supabase_realtime add table public.spostamenti;
exception when duplicate_object then null;
end $$;

-- Chiavi: dalle note importate a campi propri
update public.moto
   set data = data || jsonb_build_object('chiaveScorta', case substring(data->>'note' from 'Chiavi scorta: ([A-Z]+)') when 'SI' then 'Sì' when 'NO' then 'No' end)
 where data->>'note' ~ 'Chiavi scorta: (SI|NO)';
update public.moto set data = data || '{"chiaveMaster": "No"}'::jsonb where data->>'note' ilike '%No chiave master%';
update public.moto set data = data || '{"chiaveMaster": "Non serve"}'::jsonb where data->>'note' ilike '%Non serve master%';
update public.moto
   set data = jsonb_set(data, '{note}', to_jsonb(trim(both ' ·' from
         regexp_replace(regexp_replace(data->>'note', '(No chiave master|Non serve master)( · )?', '', 'gi'), '( · )?Chiavi scorta: [A-Z]+', '', 'g'))))
 where data->>'note' ~* '(chiave master|serve master|Chiavi scorta)';

-- Bollo: i ciclomotori 50cc (targa X + 5 caratteri) sono esenti
update public.moto set data = data || '{"bolloEsente": true}'::jsonb
 where upper(data->>'targa') ~ '^X[A-Z0-9]{5}$' and coalesce(data->>'scadBollo', '') = '';

-- Calendario: niente bollo per le moto esenti
do $$
declare src text;
begin
  select pg_get_functiondef('public.calendario_ics(text)'::regprocedure) into src;
  if position('bolloEsente' in src) = 0 then
    src := replace(src, 'where x.d is not null',
      'where x.d is not null and not (s.k = ''scadBollo'' and coalesce((m.data->>''bolloEsente'')::boolean, false))');
    execute src;
  end if;
end $$;

select data->>'numero' as numero, data->>'targa' as targa, data->>'chiaveScorta' as scorta, data->>'chiaveMaster' as master,
       data->>'bolloEsente' as esente, data->>'note' as note
  from public.moto order by (data->>'numero')::int nulls last;
