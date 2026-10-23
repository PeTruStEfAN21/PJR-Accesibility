# Ce vede fiecare: angajatul care citește, angajatul care aude, adminul

Data: 2026-10-23 · Stare: **implementat, cerut de Ayan pas cu pas în conversație**. Pornește de la `2026-10-23-trei-interfete-design.md` (Stefan) și îl înlocuiește acolo unde diferă.

## Telefon (bara de jos)

| Cine | Bara |
|---|---|
| Angajat care citește ce se spune (`experience = visual`) | Dashboard · Meeting · Vibrații · Setări |
| Angajat care aude (`experience = standard`) | Dashboard · Meeting · Urgență · Setări |
| Admin (orice tip) | Dashboard · Meeting · Urgență · Setări |
| Cont fără companie | toate cinci, ca înainte |

- Dashboard-ul pe telefon începe cu anunțurile (fără salut).
- Un om în mai multe companii: dacă citește ce se spune în oricare, primește bara „citește”.

## Desktop (după login)

- Desktopul pornește și el pe login. Fără cont rămân linkul „Prezinți un meeting? Intră fără cont” (regula 6) și linkul din QR al participantului.
- **Angajat**: anunțurile primele, apoi „Conectează-te la speaker” mare, apoi „Eu prezint” + „Vibrații” (citește) sau „Eu prezint” + „Urgență” (aude); „Meetingurile mele” rămâne la amândoi.
- **Admin**: pagina prezentatorului, fără „Vibrații” și fără „Vorbesc cu cineva”; anunțurile cu „Anunț nou”.
- Nimeni nu mai are „Bună! Cu ce începem?”; „Vorbesc cu cineva” rămâne doar la conturile fără companie.
- Login, Contul meu, Meetingurile mele, Istoricul meu și Compania mea: o coloană centrată, îngustă, pe desktop.

## Urgențele de la colegi

- **Le trimit** cei care aud și adminul (au tab-ul sau cardul Urgență).
- **Le primesc** doar cei care citesc ce se spune (și conturile fără companie, ca înainte): telefonul unui angajat care aude nici nu se abonează la ele. Alerta critică acoperă orice ecran (regula 3), indiferent de tab-uri.
- **De discutat** (propus, neimplementat): dacă telefonul celui care citește a alertat deja singur (modelul de sunete), o urgență de același tip de la un coleg nu mai vibrează, iar colegul vede „Urgența a fost deja semnalată colegilor tăi”.

## Date

Nimic nou în baza de date: tipul (`org_members.experience`) și rolul existau. Tipul se citește cu companiile (`myOrganizations`), iar aplicația așteaptă companiile (max. 5 s) după login, ca pagina să nu se schimbe sub ochii omului.
