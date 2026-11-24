-- 1) Sede e stato delle moto (sede presa dalle note importate dall'Excel)
update public.moto
   set data = data || jsonb_build_object('sede', substring(data->>'note' from 'Sede: ([A-Z]+)'))
 where data->>'note' ~ 'Sede: [A-Z]+' and coalesce(data->>'sede', '') = '';

update public.moto
   set data = jsonb_set(data, '{note}', to_jsonb(regexp_replace(data->>'note', '( · )?Sede: [A-Z]+', '', 'g')))
 where data->>'note' like '%Sede:%';

update public.moto set data = data || '{"stato": "Demolita"}'::jsonb
 where upper(data->>'targa') = 'AJ71591' and coalesce(data->>'stato', '') = '';

update public.moto set data = data || '{"stato": "Attiva"}'::jsonb
 where coalesce(data->>'stato', '') = '';

-- 2) Calendario in abbonamento (si aggiorna da solo)
create table if not exists private.calendario (id int primary key default 1 check (id = 1), token text not null);
alter table private.calendario enable row level security;
insert into private.calendario (token) values (encode(extensions.gen_random_bytes(16), 'hex')) on conflict (id) do nothing;

create or replace function public.calendario_link() returns text
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_membro() then raise exception 'non autorizzato'; end if;
  return (select token from private.calendario where id = 1);
end $$;
revoke execute on function public.calendario_link() from public, anon;
grant execute on function public.calendario_link() to authenticated;

do $$ begin
  create domain "text/calendar" as text;
exception when duplicate_object then null;
end $$;

create or replace function public.calendario_ics(t text) returns "text/calendar"
language plpgsql stable security definer set search_path = '' as $$
declare righe text;
begin
  if t is null or t <> (select token from private.calendario where id = 1) then
    raise exception 'link non valido';
  end if;
  perform set_config('response.headers', '[{"Content-Type": "text/calendar; charset=utf-8"}, {"Cache-Control": "no-cache"}]', true);
  select string_agg(ev, E'\r\n') into righe from (
    select concat_ws(E'\r\n',
      'BEGIN:VEVENT',
      'UID:garage-' || m.id || '-' || s.k || '@garage',
      'DTSTAMP:' || to_char(now() at time zone 'utc', 'YYYYMMDD"T"HH24MISS"Z"'),
      'DTSTART;VALUE=DATE:' || to_char(x.d, 'YYYYMMDD'),
      'DTEND;VALUE=DATE:' || to_char(x.d + 1, 'YYYYMMDD'),
      'SUMMARY:' || replace(replace(s.l || ' – ' || coalesce('N. ' || (m.data->>'numero') || ' ', '')
                   || trim(coalesce(m.data->>'marca', '') || ' ' || coalesce(m.data->>'modello', ''))
                   || coalesce(' (' || nullif(m.data->>'targa', '') || ')', ''), ',', '\,'), ';', '\;'),
      'BEGIN:VALARM', 'ACTION:DISPLAY', 'DESCRIPTION:' || s.l || ' in scadenza tra 30 giorni', 'TRIGGER:-P30D', 'END:VALARM',
      'BEGIN:VALARM', 'ACTION:DISPLAY', 'DESCRIPTION:' || s.l || ' in scadenza tra 7 giorni', 'TRIGGER:-P7D', 'END:VALARM',
      'END:VEVENT') as ev
    from public.moto m
    cross join (values ('scadAssicurazione', 'Assicurazione'), ('scadBollo', 'Bollo'), ('scadRevisione', 'Revisione')) as s(k, l)
    cross join lateral (select case when coalesce(m.data->>s.k, '') ~ '^\d{4}-\d{2}-\d{2}$' then (m.data->>s.k)::date end as d) x
    where x.d is not null
      and coalesce(m.data->>'stato', 'Attiva') not in ('Venduta', 'Demolita')
  ) q;
  return concat_ws(E'\r\n', 'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Garage//IT', 'CALSCALE:GREGORIAN',
    'X-WR-CALNAME:Scadenze moto', 'REFRESH-INTERVAL;VALUE=DURATION:PT6H', 'X-PUBLISHED-TTL:PT6H',
    righe, 'END:VCALENDAR') || E'\r\n';
end $$;
revoke execute on function public.calendario_ics(text) from public;
grant execute on function public.calendario_ics(text) to anon, authenticated;

select data->>'numero' as numero, data->>'modello' as modello, data->>'sede' as sede, data->>'stato' as stato from public.moto order by (data->>'numero')::int nulls last;
