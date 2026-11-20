-- Una moto non può essere registrata due volte:
-- numero moto, targa e numero di telaio devono essere unici (i campi vuoti sono ignorati).
create unique index if not exists moto_numero_unico on public.moto ((data->>'numero'))
  where coalesce(data->>'numero', '') <> '';
create unique index if not exists moto_targa_unica on public.moto (upper(regexp_replace(data->>'targa', '[\s.\-]', '', 'g')))
  where coalesce(data->>'targa', '') <> '';
create unique index if not exists moto_telaio_unico on public.moto (upper(regexp_replace(data->>'telaio', '[\s.\-]', '', 'g')))
  where coalesce(data->>'telaio', '') <> '';
