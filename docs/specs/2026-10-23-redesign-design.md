# Redesign complet: aplicația Echo (telefon + laptop, un singur build)

**Data:** 2026-10-23 · **Demo:** azi, ~16:00 · **Unelte:** UI UX Pro Max (stil „Accessible & Ethical”), Taste, regulile proiectului (au prioritate).

## De ce

Aplicația arată în două feluri: jumătate din ecrane (acasă, conectare, sunete, antrenorul, alarma) folosesc paleta Echo, cealaltă jumătate (subtitrarea din meeting, prezentatorul, setările, contul, istoricul, compania, conversația) tema implicită Flutter, pornită de la un albastru. Redesignul le aduce pe toate la același limbaj, centrat pe telefon (inclusiv în browser, în modul telefon din DevTools), cu o bară de navigare plutitoare.

## Ce a decis echipa

- **Logo-ul rămâne exact cum e** (`EchoLogo`, cyan `#18B5D1`).
- **Aspect calm, construit în jurul logo-ului:** fundal deschis, accente cyan din logo, text aproape negru, contrast 7:1, text și butoane mai mari, carduri curate.
- **Bara plutitoare pe telefon:** Acasă · Meeting · Sunete · Alarmă · Setări.
- **Toate ecranele, înainte de demo.**

## Cum (deciziile builderului, marcate)

1. **O singură sursă pentru culori și forme.** `EchoPalette` (paleta Echo) și `buildTheme` (tema Material) folosesc aceleași valori, ca ecranele vechi să primească noul aspect fără să fie rescrise. *(decizia builderului)*
   - Cyan logo `#18B5D1`: doar logo și elemente decorative (nu text: contrast 2,4:1 pe alb).
   - Accent pentru butoane, linkuri, selecție: cyan închis din aceeași familie, ≥ 7:1 pe alb.
   - Text: aproape negru, ≥ 7:1; text secundar ≥ 7:1 (nu gri pe gri).
   - Fundal alb; panouri cu o nuanță foarte deschisă de cyan; margini fine.
   - Culorile rolurilor (Speaker / Din sală, `RolePalette`) nu se schimbă (regula 2); modurile contrast ridicat și dislexie rămân.
2. **Text:** fontul rămâne Roboto (inclus în aplicație, fără descărcări); textul de bază 16–17 px, înălțime de rând 1,5; titluri mai mari și mai aerisite. *(decizia builderului)*
3. **Forme:** carduri cu colțuri 20–24 px, fără umbre grele; butoane în formă de pastilă, minim 48 px; câmpuri cu etichetă vizibilă deasupra; focus vizibil (3 px). *(decizia builderului)*
4. **Bara plutitoare (doar pe ecran de telefon, ≤ 600 px):** *(decizii ale builderului, în afară de cele 5 intrări)*
   - Pastilă care plutește la ~12 px de margini, deasupra zonei sigure; înălțime ≥ 64 px; fiecare intrare ≥ 48 px.
   - Iconiță + etichetă mereu vizibile; intrarea curentă are fundal accentuat, iconiță plină și etichetă îngroșată (nu doar culoare); etichete pentru VoiceOver și „selectat”.
   - Conținutul are spațiu jos cât bara, ca nimic să nu rămână ascuns sub ea.
   - Intrări: **Acasă** (pagina principală de telefon) · **Meeting** (conectarea la speaker) · **Sunete** · **Alarmă** (alarma de urgență; fără cont, explică de ce și duce la conectare) · **Setări**.
   - Bara apare doar pe aceste 5 ecrane principale; în ecranele deschise din ele (subtitrarea din meeting, prezentatorul, antrenorul etc.) dispare, ca ecranul să rămână al conținutului; „înapoi” revine la intrarea din bară.
   - Alerta critică acoperă și bara (regula 3).
5. **Laptop (> 600 px):** fără bară; aceeași temă nouă; pagina principală de acum (prezentator + tot ce are telefonul).
6. **Mișcare:** discretă, 150–250 ms, oprită când sistemul cere mișcare redusă.

## Ecrane (toate primesc tema; cele principale și o trecere de aranjare)

Acasă, conectare, subtitrarea din meeting (inclusiv întrebări și „Ți s-a răspuns”), prezentator, antrenorul de claritate, sunete (+ învățare sunet, vibrații), conversație, alarmă, setări, cont și conectare, istoric și meeting salvat, companie și meetingurile companiei, activitate.

## Criterii de reușită

- Toate testele trec; `flutter analyze` curat.
- Fiecare ecran principal verificat în browser la 390 × 844 (modul telefon din DevTools) și la lățime de laptop: nimic tăiat, nimic sub bară, text mărit la 200% fără tăieri.
- Contrastul textului ≥ 7:1 pentru textul normal, verificat în teste pentru culorile din temă.
- Comportamentul nu se schimbă: doar aspectul și navigarea.

## În afara redesignului

Funcțiile din backend neintegrate (Simplifică, locațiile companiei, ștergerea companiei, profilul sincronizat) rămân pentru după demo.
