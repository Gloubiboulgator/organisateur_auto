# Les réglages du run, plateformes et comportements ajoutés

Ce fichier décrit les plateformes qu'on coche, et les quatre comportements que la fenêtre de
réglages peut allumer. Le skill y renvoie. Les autres réglages sont décrits dans le skill, à leur
place.

## Neuf plateformes, cochées une à une

Toutes demandées en option par l'admin le 2026-11-27. Chacune reçoit son lot de testeurs.

- **Android (app).** L'APK installé dans un téléphone virtuel, l'émulateur.
- **Chrome Android.** Le vrai Chrome du téléphone virtuel, ouvert sur le site. Il se pilote
  comme l'app, Chrome tenant son rôle. Chrome doit y être installé, sinon le lanceur le dit.
- **Sur ordinateur.** Chromium, Firefox, Safari, Chrome ou Edge, à la taille d'un téléphone.
  Safari est son moteur, WebKit, pas un vrai Safari.
- **Imités.** Chrome mobile et Safari mobile, d'après les profils `Pixel 5` et `iPhone 12` de
  Playwright. Le site voit un téléphone tactile, avec son identité mobile.

L'adresse du site doit être joignable depuis le téléphone virtuel. Un serveur du PC s'y nomme
d'ordinaire `10.0.2.2`, à vérifier au premier run.

Une page sans balise `viewport` s'affiche dézoomée sur un téléphone imité. Chromium y vise en
pixels de la page, WebKit en pixels de l'écran, mesuré le 2026-11-27. Le pilote convertit pour
chacun, et le doigt garde sa taille réelle.

## Quatre comportements de plus, éteints par défaut

Retenus par l'admin le 2026-11-27, parmi des pistes proposées en session. Chacun s'allume dans
la fenêtre. Les conditions du téléphone, réseau lent, grande police ou mode sombre, ont été
écartées le même jour.

**Il retouche s'il ne se passe rien.** Une vraie personne retouche un bouton qui tarde. On voit
ainsi les doubles envois.

- Le pilote photographie l'écran avant le toucher. Si l'écran n'a pas bougé au bout du délai,
  une seconde par défaut, le même point se touche une fois de plus.
- La mesure de la pose court depuis le premier toucher. Sans elle, une photo au bout du délai
  dit si l'écran a réagi.
- Le journal porte `double`. Le testeur n'en est pas averti, comme pour le doigt.

**Il fait des fautes de frappe.** Une lettre sur vingt par défaut est fautive. C'est la lettre
voisine sur un clavier AZERTY, une lettre oubliée, ou une lettre doublée.

Seules les lettres sans accent fautent, celles qu'Android sait taper. Le journal porte `voulu`
et `tape`. Le testeur le voit sur son coup d'œil, ou ne le voit pas.

**Il a la mémoire courte.** Une personne ne revoit pas un écran d'il y a cinq gestes.

- Seules les trois dernières captures restent dans le dossier du testeur. Les autres partent
  hors de sa portée, et le lanceur les remet en place au rapatriement.
- La consigne lui dit qu'il ne se souvient que vaguement de ce qu'il a vu plus tôt.
- Limite assumée. Le modèle garde en tête ce qu'il a déjà ouvert. Seule la consigne lui demande
  de faire comme s'il l'avait oublié.

**Il est interrompu une fois.** L'app passe en arrière-plan dix secondes par défaut, comme pour
un appel, puis revient.

- Le geste se tire au lancement, entre le quart et la moitié du plafond de gestes. Une lecture
  le repousse au geste suivant, puisque lire ne touche pas l'app.
- Sur Android, le bouton d'accueil, puis l'icône de l'app. Sur le web, un autre onglet passe
  devant, puis se ferme.
- Le pilote le dit au testeur, qui sait qu'il a été interrompu. Le journal porte
  `interruption`.
- Un testeur qui s'arrête avant le geste tiré n'est jamais interrompu.
