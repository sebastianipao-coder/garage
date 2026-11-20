# Garage – Moto e Ricambi

Web app per gestire le proprie moto e il magazzino ricambi, utilizzabile da qualsiasi dispositivo (telefono, tablet, computer).

## Funzioni

- **Moto**: scheda con numero, marca, modello, anno, targa, telaio e km; scadenze di assicurazione e revisione evidenziate a 30 giorni; storico manutenzione con costi; documenti allegati (libretto, fatture, manuali).
- **Calendario**: il pulsante "Aggiungi al calendario" scarica un file `.ics` con le scadenze e due promemoria (30 e 7 giorni prima), da aprire con il calendario di iPhone, Android o computer.
- **Ricambi**: codice, descrizione, quantità, prezzo e fornitore, con ricerca e valore totale del magazzino.
- **Report**: spese per moto, per tipo di intervento e per anno; valore del magazzino per fornitore.

## Come è fatta

- Pagina statica (`index.html`) pubblicata con GitHub Pages.
- Dati, accesso e file su [Supabase](https://supabase.com) (piano gratuito).
- Sul telefono si può aggiungere alla schermata Home (Safari → Condividi → Aggiungi alla schermata Home) e si apre come un'app.

## Accesso

Le registrazioni sono disattivate. Gli utenti si creano dal pannello Supabase:
**Authentication → Users → Add user → Create new user** (lasciare attivo "Auto confirm user").

## Rifare la configurazione da zero

1. Crea un progetto su Supabase.
2. In **SQL Editor** esegui il contenuto di `schema.sql`.
3. In **Authentication → Sign In / Providers** disattiva "Allow new users to sign up".
4. In `config.js` inserisci il Project URL e la chiave **anon public** (Settings → API Keys). Non usare mai la chiave `service_role`.
5. Pubblica il repository con GitHub Pages (Settings → Pages → branch `main`, cartella `/`).
