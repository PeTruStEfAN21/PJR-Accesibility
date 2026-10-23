# Istoricul activității: fiecare își vede istoricul, adminul vede istoricul companiei

**Data:** 2026-10-23 · **Stare:** aprobat (Petru), cu cerința „respectăm GDPR în orice facem” (§11) · **Pornește de la:** `2026-10-22-organizatii-design.md`, `2026-10-22-alarma-manuala-design.md` (înlocuiește „jurnalul de răspundere e un fișier pe server”)

## 1. Intenție

Tot ce se întâmplă cu alarmele și meetingurile rămâne scris în baza de date. Fiecare utilizator își vede istoricul lui; adminul unei companii vede istoricul companiei, inclusiv meetingurile angajaților (cu transcrieri). Nimeni nu poate modifica sau șterge un rând din istoric, nici adminii.

## 2. Decizii

| Întrebare | Decizie | De ce |
|---|---|---|
| Unde stă jurnalul | **În baza de date** (tabelul `activity_log`), nu într-un fișier. Se adaugă doar rânduri: aplicația și serverul nu au drept de modificare sau ștergere | Decis de Petru; păstrează ce voia Denis (nimic nu se șterge, nimeni nu umblă la el) și îl face vizibil în aplicație |
| Ce vede adminul despre meetinguri | **Tot**: activitatea, titlul, rezumatul și transcrierea meetingurilor salvate cât angajatul e în companie | Decis de Petru |
| Garanții pentru angajat | (1) Angajatul e anunțat la acceptarea invitației, în „Compania mea” și printr-un banner în timpul meetingului: „Meetingul se salvează pentru {companie}; adminii îl pot citi”. (2) Meetingurile salvate înainte de a intra în companie sau fără companie rămân doar ale lui. (3) Fiecare deschidere a unui meeting de către un admin intră în istoricul angajatului („{admin} a citit meetingul {titlu}”) | Monitorizarea comunicărilor angajaților cere informare prealabilă (GDPR, Codul muncii); transcrierea conține și vorbele altor oameni |
| Plecarea din companie | Meetingurile angajatului se desprind de companie (adminii nu le mai văd); rândurile de istoric despre ele rămân în istoricul companiei | Compania păstrează dovada activității, nu și conținutul cuiva care a plecat |
| Ștergerea contului | Se șterg meetingurile omului și istoricul lor (pornit, terminat, șters, cine i le-a citit). Rămân 12 luni, cu emailul dar fără legătura cu contul: alarmele date de el, răspunsurile lui la alarme, alarmele închise de el și, dacă era admin, ce meetinguri ale angajaților a citit. Dialogul de ștergere spune exact asta | Decis de Petru: o alarmă dată în glumă nu se poate acoperi ștergând contul; angajatul păstrează dreptul să știe cine i-a citit meetingurile |
| Cât se păstrează | 12 luni de la eveniment. Ce e mai vechi nu se mai arată și se șterge la următoarea scriere în istoric (nu depinde de server); serverul mai curăță o dată pe zi | Minimizarea datelor; destul pentru orice anchetă despre o alarmă |
| Ștergerea companiei | Istoricul companiei pleacă odată cu ea; fiecare om își păstrează rândurile lui (alarmele lui rămân în istoricul lui) | Compania nu mai există; dovada rămâne la cel care a dat alarma |
| Alarma dată de un coleg (500 m) | Intră în istoricul autorului și al **fiecărei companii din care face parte** | Decis de Petru |
| Cine scrie rândurile | Baza de date singură, prin triggere, pentru ce se întâmplă în ea (meetinguri, alarme de companie). Serverul, pentru alarmele date de colegi (doar el știe IP-ul), cu un rol Postgres propriu, `echo_audit`, care poate doar să apeleze funcția de înregistrare | Un jurnal de răspundere nu trebuie să poată fi scris de cel acuzat; serverul tot nu folosește cheia `service_role` |
| Fără `AUDIT_DATABASE_URL` | Serverul scrie în logul lui, ca acum | Demo-ul și instalările fără bază de date merg neschimbate |

## 3. Ce intră în istoric

| Eveniment | Scris de | Cine îl vede | Ce conține |
|---|---|---|---|
| `colleague_alarm_raised` / `colleague_alarm_cancelled` | server | autorul + adminii companiilor lui | tipul, poziția, precizia, IP-ul, id-ul alarmei |
| `org_alarm_reported` | `report_alarm()` | cel care a raportat + adminii companiei | tipul, evenimentul |
| `org_alarm_answered` | trigger pe `alarm_acks` | cel care a răspuns + adminii | `safe` / `need_help` |
| `org_alarm_closed` | trigger pe `alarm_events` | adminul + adminii | evenimentul |
| `meeting_started` / `meeting_ended` / `meeting_deleted` | triggere pe `meetings` | proprietarul + adminii companiei meetingului | id-ul și titlul meetingului |
| `meeting_read_by_admin` | `company_meeting()` | angajatul al cărui meeting a fost citit + adminii | cine a citit, ce meeting |

Fiecare rând are: ora (serverului), evenimentul, cine a făcut (cont + email), despre cine e (pentru `meeting_read_by_admin`), companiile care îl văd, plus coloanele fixe de mai sus. Fără câmp de text liber.

## 4. Schema (migrație nouă)

- `activity_log`: `id`, `at`, `event` (enum), `actor_id`, `actor_email`, `subject_user_id`, `ref` (id-ul alarmei / meetingului / evenimentului), `title`, `alarm_kind`, `status`, `lat`, `lon`, `accuracy_m`, `ip` (`inet`). `activity_log_orgs (entry_id, org_id)`: ce companii văd rândul (se șterg cu compania).
- RLS: utilizatorul vede rândurile unde e `actor_id` sau `subject_user_id`; adminul vede rândurile legate de companiile lui. Aplicația nu are niciun drept direct pe tabele: citește doar prin `my_activity()` și `company_activity()`, care nu întorc IP-ul (îl citește doar operatorul, direct în baza de date); nimeni nu are `insert` / `update` / `delete`.
- `meetings.org_id` (opțional): compania pentru care se salvează meetingul, verificată (proprietarul trebuie să fie membru). Cheie compusă spre `org_members`: la plecarea din companie devine `null`.
- `company_meeting(meeting_id)` și `company_meetings(org_id)`: singurele căi prin care un admin citește meetingurile companiei; prima scrie `meeting_read_by_admin` înainte să întoarcă transcrierea și rezumatul. Adminul nu primește drept direct pe `meeting_lines`, ca nicio citire să nu ocolească jurnalul.
- `record_colleague_alarm(...)`: `security definer`, executabilă doar de rolul `echo_audit`; leagă rândul de companiile autorului.
- La ștergerea contului: un trigger pe `auth.users` șterge rândurile de meeting ale omului și le lasă pe cele de alarmă (cu `actor_id` gol, emailul rămâne).
- Păstrarea: fiecare scriere în istoric șterge ce e mai vechi de 12 luni, iar citirile nu arată niciodată ce a trecut de termen; `purge_activity_log()` face același lucru și o apelează serverul o dată pe zi.
- Ștergerea la scriere e limitată: cel mult 200 de rânduri vechi pe scriere, alese cu `for update skip locked`, deci o scriere nu așteaptă niciodată după tranzacția altcuiva și nu plătește pentru o restanță mare; restul pleacă la scrierile următoare sau cu `purge_activity_log()`.
- Rolul `echo_audit` se creează fără parolă în migrație; la instalare i se pune parola (`alter role echo_audit with login password '…'`) și se trece în `AUDIT_DATABASE_URL` în `.env`.

## 5. Server

- `DatabaseRecorder` (implementează `AlarmRecorder`): apelează `record_colleague_alarm` prin `AUDIT_DATABASE_URL` (psycopg, asincron). Dacă baza de date nu răspunde, rândul ajunge în logul serverului (ca acum), iar alarma oricum a plecat.
- O dată pe zi: `purge_activity_log()`.

## 6. Aplicație

- **Cont → Istoricul meu**: evenimentele mele, cele mai noi primele, în cuvinte („Ai dat o alarmă: Incendiu”, „Ana (admin) a citit meetingul «Ședința de vineri»”). Fiecare cu iconiță + text, niciodată doar culoare.
- **Compania mea (admin) → Istoricul companiei**: aceleași evenimente pentru toată compania, cu cine. **Meetingurile companiei**: lista; deschiderea arată transcrierea și rezumatul (prin `company_meeting`).
- **Meetingul**: dacă participantul e într-o companie, meetingul se salvează cu `org_id` și apare bannerul. Cu mai multe companii, alege din banner (implicit prima).
- **Invitația și „Compania mea”**: textul că adminii pot citi meetingurile salvate cât ești în companie.
- Toate textele în `app_ro.arb` / `app_en.arb`; `Semantics`, ținte de 48 px, mărimea textului respectată.

## 7. Regula nouă pentru proiect (în CLAUDE.md)

Orice funcționalitate nouă care produce date își salvează datele în baza de date (migrație nouă + RLS + test în `test_database.py`), iar acțiunile importante ale oamenilor intră în `activity_log`. Ce rămâne doar pe telefon (amprenta vocii, modelele) se spune explicit în design, cu motivul.

## 8. Teste

- Baza de date: fiecare eveniment din tabelul de la §3 apare o dată, cu cine îl vede și cine nu (alt utilizator, altă companie, `anon`); nimeni nu modifică sau șterge un rând; `echo_audit` nu poate face altceva decât să apeleze funcția; ștergerea contului păstrează alarmele și șterge meetingurile; plecarea din companie desprinde meetingurile; citirea unui meeting de către admin e scrisă înainte să primească textul; un admin al altei companii nu citește nimic; `purge` șterge doar ce e mai vechi de 12 luni.
- Server: `DatabaseRecorder` cu o bază de date falsă și cu una căzută (rândul ajunge în log).
- Aplicație: widget teste cu store-uri false pentru Istoricul meu, Istoricul companiei, deschiderea unui meeting de către admin, bannerul.

## 9. Ce nu intră acum

- Sincronizarea setărilor (`profiles.settings`) și a sunetelor învățate personal: altă etapă, cu designul ei.
- Exportul istoricului (CSV / PDF) pentru anchete.

## 11. GDPR

| Principiu | Cum îl respectăm |
|---|---|
| Temei legal (art. 6) | Alarmele: interesul legitim al companiei și al colegilor (siguranța, prevenirea alarmelor false), art. 6(1)(f). Meetingurile citite de admin: compania e operatorul și își alege temeiul (contract / interes legitim) și își informează angajații; noi suntem persoana împuternicită (DPA) când găzduim |
| Transparență (art. 13) | Angajatul e anunțat înainte: la invitație, în „Compania mea”, în bannerul meetingului. Ecranul alarmei spune că alarma se salvează cu contul, ora și locul. Dialogul de ștergere a contului spune că alarmele rămân 12 luni |
| Minimizare (art. 5(1)(c)) | Coloane fixe, fără text liber. **IP-ul nu îl vede nimeni din aplicație** (nici autorul, nici adminul): stă în baza de date doar pentru anchete, citit doar de operator, cum voia Denis. Adminul vede tipul, ora și locul alarmei |
| Limitarea stocării (art. 5(1)(e)) | Istoricul se șterge automat după 12 luni |
| Dreptul de acces (art. 15) | „Istoricul meu” arată tot ce e scris despre om, inclusiv cine i-a citit meetingurile. Exportul vine într-o etapă următoare |
| Dreptul la ștergere (art. 17) | Ștergerea contului șterge meetingurile și istoricul lor. Rândurile despre alarme (date, răspunsuri, închise) și, pentru un admin, ce meetinguri a citit rămân 12 luni cu emailul, fără legătura cu contul: excepția art. 17(3)(e) (constatarea, exercitarea sau apărarea unui drept în instanță), spusă clar în dialog |
| Securitate (art. 32) | RLS pe fiecare tabel, nimeni nu modifică istoricul, serverul are un rol care doar adaugă, citirile adminului trec prin funcții care le înregistrează |
| Categorii speciale (art. 9) | Nu salvăm diagnostic; „nevoile” rămân bife fixe. Transcrierile pot conține orice: de aceea doar meetingurile salvate pentru companie, cu banner |
| Terți (cei din sală) | Compania trebuie să-i informeze; recomandăm DPIA (art. 35) înainte de folosirea reală |

## 10. Riscuri

- **Legal**: compania e operatorul datelor; trebuie să-și informeze angajații (și pe cei care vorbesc în meetinguri) că meetingurile salvate pot fi citite. Recomandăm o evaluare de impact (DPIA) înainte de folosirea reală. Interfața spune clar ce se întâmplă, dar nu înlocuiește informarea făcută de companie.
- Regula din CLAUDE.md „fiecare utilizator vede doar rândurile lui” se schimbă: adminii văd meetingurile companiei și istoricul ei.
- Demo-ul de azi: nimic nu se schimbă fără conturi activate; serverul fără `AUDIT_DATABASE_URL` merge ca acum.
