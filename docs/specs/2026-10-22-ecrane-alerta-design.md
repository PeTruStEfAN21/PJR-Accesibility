# Ecrane de alertă pe tip de sunet și butonul „Sunete” din bara de sus

**Data:** 2026-10-22 · **Stare:** aprobat de echipă în conversație · **Pornește de la:** `2026-10-22-sunetul-vizibil-design.md`, `2026-10-22-ascultare-permanenta-design.md`

## Problema

- Alertele care nu sunt critice (claxon, geam spart, telefon, sonerie, sunete învățate) dau eroare: banner-ul are un buton cu tooltip, dar stă deasupra navigatorului, unde nu există `Overlay` („No Overlay widget found”). Doar alarma de incendiu mergea.
- Claxonul și celelalte alerte de atenție nu au un ecran al lor; un banner mic se pierde ușor.
- Ascultarea se pornește doar din ecranul „Sunetele din jur”.

## Ce facem

1. **Ecran întreg pentru fiecare alertă critică și de atenție**, cu: eticheta nivelului (iconiță + text „CRITIC” / „ATENȚIE”, nu doar culoarea), iconița sunetului, numele, un sfat pe tipul de sunet și butonul „Am înțeles”.
   - Critic: roșu, rămâne până confirmi, ieșirea de urgență dacă e setată (neschimbat).
   - Atenție: galben (#FFC233, text negru), se închide singur după 8 s sau la confirmare.
   - Sfaturi: incendiu („Ieși din clădire…”), sirenă, claxon („Oprește-te și uită-te în jur…”), geam spart, semnal de utilaj; sunetele învățate nu au sfat.
2. **Informativ** (telefon, sonerie) rămâne banner discret jos; butonul de închidere nu mai folosește tooltip (eticheta pentru VoiceOver vine din `semanticLabel`).
3. **Pastila „Sunete”** în bara ecranului principal, lângă setări (doar pe telefon; pe pagina prezentatorului nu apare):
   - oprit: contur, iconiță tăiată; pornit: umplută cu culoarea principală, iconiță de ureche; în pauză (subtitrare): contur, iconiță de pauză;
   - VoiceOver: buton, „Sunetul vizibil: pornit / oprit / în pauză”;
   - cu text foarte mare (scalare peste 1,3) rămâne doar iconița, ca să nu se taie textul în bară;
   - dacă recunoașterea nu merge pe dispozitiv, deschide ecranul „Sunetele din jur” (cu butoanele de test).

## Criterii de reușită

- Test: o alertă de claxon apare pe tot ecranul, cu sfatul ei, fără excepții, și se închide la „Am înțeles”.
- Test: o alertă de sonerie apare ca banner, fără excepții.
- Test: pastila pornește și oprește ascultarea și își schimbă eticheta.
- `flutter test` și `flutter analyze` trec.
