# Garage – Moto e Ricambi

Web app per gestire le proprie moto e il magazzino ricambi, utilizzabile da qualsiasi dispositivo (telefono, tablet, computer).

## Funzioni

- **Moto**: scheda con numero, sede, stato (attiva, in officina, ferma, venduta, demolita), marca, modello, anno, targa, telaio e km; ricerca e filtri per sede e stato; scadenze di assicurazione, bollo e revisione evidenziate a 30 giorni; storico manutenzione con costi; documenti allegati (libretto, fatture, manuali).
- **Calendario**: il pulsante "Calendario" offre un abbonamento che si aggiorna da solo (iPhone, Google Calendar); "Aggiungi al calendario" scarica invece un file `.ics` con le scadenze e due promemoria (30 e 7 giorni prima), da aprire con il calendario di iPhone, Android o computer.
- **Ricambi**: codice, descrizione, quantità, prezzo e fornitore, con ricerca e valore totale del magazzino.
- **Report**: spese per moto, per tipo di intervento e per anno; valore del magazzino per fornitore.

## Come è fatta

- Pagina statica (`index.html`) pubblicata con GitHub Pages.
- Dati, accesso e file su [Supabase](https://supabase.com) (piano gratuito).
- Sul telefono si può aggiungere alla schermata Home (Safari → Condividi → Aggiungi alla schermata Home) e si apre come un'app.

## Accesso e collaboratori

- Nell'app, il pulsante **Invita** mostra il link di invito da mandare ai collaboratori: aprendolo creano il proprio account e vedono subito i dati.
- **Disattiva e crea nuovo link** rende inutilizzabile il link precedente (gli account già creati restano attivi).
- Chi si registra senza un link valido non vede nessun dato.
- Si possono anche creare utenti dal pannello Supabase (Authentication → Users → Add user) e abilitarli con:
  `insert into public.membri (user_id) select id from auth.users where email = 'email@esempio.it';`
- Per togliere l'accesso a qualcuno: `delete from public.membri where user_id = (select id from auth.users where email = 'email@esempio.it');`

## Rifare la configurazione da zero

1. Crea un progetto su Supabase.
2. In **SQL Editor** esegui il contenuto di `schema.sql`.
3. Esegui anche `invito.sql`. In **Authentication → Sign In / Providers** lascia attivo "Allow new users to sign up" e disattiva "Confirm email".
4. In `config.js` inserisci il Project URL e la chiave **anon public** (Settings → API Keys). Non usare mai la chiave `service_role`.
5. Pubblica il repository con GitHub Pages (Settings → Pages → branch `main`, cartella `/`).
