# Anunțurile companiei (Dashboard pe telefon, landing page pe laptop)

Data: 2026-10-23 · Stare: **cerut de Ayan („vreau să-l implementăm și să văd ce iese”, mă mai ghidează după)**. Deciziile sunt alegerea noastră și se pot schimba.

## 1. Intenție

Adminul are nevoie să spună ceva întregii echipe, de exemplu: „Mâine plecăm toți cu 2 ore mai devreme, se face dezinsecție.” Anunțul ajunge la toți angajații, indiferent dacă citesc sau aud ce se spune, și e **scris, deci la fel de accesibil pentru toți**. Adminul vrea să știe că oamenii l-au văzut.

## 2. Ce construim

- **Telefon, Dashboard**: sub salut, secțiunea **Anunțuri**. Cele importante primele, apoi cele noi. Fiecare anunț: titlu, text, compania, data, eticheta **Important** (iconiță + text) și, cât nu l-ai văzut, eticheta **Nou** și butonul **Am văzut**.
- **Adminul**: butonul **Scrie un anunț** (titlu, mesaj, „Important”, cât timp se vede: o zi / o săptămână / o lună). La fiecare anunț al lui vede „Văzut de 2 din 3” și îl poate șterge (cu confirmare).
- **Laptop, după login**: pagina devine un landing page: salutul și acțiunea principală („Eu prezint”) sus, **anunțurile imediat sub**, apoi restul cardurilor. Fără cont sau fără companie, pagina rămâne cum e acum (regula 6).
- Fără companie: secțiunea nu apare. Companie fără anunțuri: un mesaj și, pentru admin, butonul de scris (nu un ecran gol).
- Anunțurile se reîncarcă la intrarea în Dashboard și la fiecare 30 de secunde cât e deschis, ca la demo să apară repede pe telefoane.

## 3. Baza de date (migrația `20261023160000_announcements.sql`)

- `org_announcements`: compania, autorul (`auth.uid()`), titlu (1–120), text (1–2000), `important`, `created_at`, `expires_at` (1–90 de zile). Angajații companiei îl citesc **doar cât nu a expirat**. Se scrie și se șterge doar prin funcții, de admin.
- `org_announcement_reads`: anunțul, omul, ora. Fiecare își marchează doar al lui și vede doar ale lui.
- `post_announcement(target_org, title, body, important, days)`, `delete_announcement(announcement)`: doar adminul companiei. Postarea șterge anunțurile expirate ale companiei.
- `announcement_seen(target_org)`: doar adminul; pentru fiecare anunț, câți l-au văzut din câți ar trebui (fără autor). **Doar numărul, nu cine.**
- `activity_log`: `announcement_posted`, `announcement_deleted` (cine, ce companie, titlul). Citirile nu intră în istoric.

## 4. Accesibilitate

Important și Nou: iconiță + text, niciodată doar culoare. „Am văzut” e buton de minim 48 px. Numărul de anunțuri noi e anunțat ca propoziție („2 anunțuri noi”), nu ca cifră. Textul crește cu setarea de mărime, fără înălțimi fixe. Nimic nu depinde de sunet.

## 5. GDPR

| Principiu | Cum |
|---|---|
| Temei | Interesul legitim al companiei de a-și informa angajații (art. 6(1)(f)); pentru anunțuri de siguranță, obligațiile de securitate în muncă |
| Informare | În formularul adminului: „Toți angajații companiei văd anunțul. Nu scrie date despre sănătatea sau viața cuiva.” |
| Minimizare | Conținutul e al companiei. Despre oameni păstrăm doar „a văzut anunțul X la ora Y”, iar adminul vede doar numărul |
| Păstrare | Anunțul se vede până la expirare (max. 90 de zile), apoi se șterge la următorul anunț al companiei; pleacă oricum cu compania. Citirile pleacă odată cu anunțul |
| Ștergerea contului | Citirile omului se șterg; anunțurile scrise de un admin rămân ale companiei, fără autor |
| Securitate | RLS pe ambele tabele, scriere doar prin funcții `security definer` care verifică adminul, nelogații nu văd nimic |
