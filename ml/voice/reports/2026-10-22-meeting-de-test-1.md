# Primul meeting de test (2026-10-22, 21:25)

Arhiva `echo-test-meeting-20261022-2125`: 35 de replici, speakerul și 2–3 colegi la ~2 m de laptop, model `vp-ro-1`, prag de asemănare 0,51.

| | Replici | Asemănare cu vocea învățată |
|---|---|---|
| Speaker (judecate de pagină) | 10 | 0,69–0,79, o excepție: „Liniște Liniște” 0,29 |
| Din sală (judecate de pagină) | 8 | 0,20–0,35 |

- Unde pagina a judecat replica, scorul din Chrome e identic cu cel calculat în Python.
- Dacă toate replicile de peste 1 s ar fi fost judecate: 31 din 33 corecte (94%). Pagina a avut 26 din 35 (74%): toate greșelile vin din replici nejudecate, care au moștenit eticheta replicii de dinainte.
- Unele erau scurte (sub 1 s de voce); altele (#1–#4, #8, cu 1,4–2 s de voce) au fost sărite dintr-un motiv pe care arhiva nu îl păstra (voce neînvățată în acel moment, „Vorbesc eu” sau o eroare a modelului).
- Adaptarea nu a schimbat nimic: scorurile speakerului au rămas 0,69–0,79 tot meetingul.

Schimbări după acest meeting: replicile se judecă de la 0,5 s de voce (nu 1 s); fiecare decizie își păstrează motivul în arhivă (`reason`) și îl arată pe pagina laptopului.
