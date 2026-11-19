#!/usr/bin/env node
// pilote-web.cjs — la moitié web du pilote de la passe parcours.
//
// POURQUOI CE FICHIER EXISTE
// --------------------------
// `piloter.py` joue chaque geste dans un processus neuf. Un navigateur Playwright meurt avec le
// processus qui l'a lancé, et la page repartirait de zéro à chaque geste. On lance donc un
// Chromium à part, avec son port de débogage, et chaque geste s'y rattache par CDP, le
// protocole de débogage de Chrome. La page, son historique et ses cookies survivent entre deux.
//
// CE QU'IL N'EST PAS. Il ne parle jamais au testeur. `piloter.py` reçoit sa sortie JSON, et
// c'est lui qui écrit au testeur, sans chemin ni nom de projet.
//
// COMMENT ON S'EN SERT, depuis `lancer_testeurs.py` et `piloter.py`, jamais à la main :
//     node pilote-web.cjs demarrer
//     node pilote-web.cjs toucher
//     node pilote-web.cjs arreter
// La configuration se lit dans le fichier que nomme `F5_PILOTE`. Playwright se trouve par
// `NODE_PATH`, que le lanceur pose.
'use strict';
const fs = require('fs');
const readline = require('readline');
const { spawn } = require('child_process');

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch (erreur) {
  process.stderr.write('Playwright est introuvable. Installer : npm install --prefix <dossier> playwright\n');
  process.exit(3);
}

const conf = JSON.parse(fs.readFileSync(process.env.F5_PILOTE, 'utf8'));

// Une photo PNG de la page. Prise en pleine navigation, elle peut échouer : elle se retente
// alors, cinq fois au plus. Relevé par la revue de la 114, le 2026-11-19.
async function photographier(page) {
  for (let essai = 1; ; essai += 1) {
    try {
      return await page.screenshot({ type: 'png' });
    } catch (erreur) {
      if (essai >= 5) throw erreur;
      await new Promise((fini) => setTimeout(fini, 100));
    }
  }
}

// Dit « fait » une fois le geste joué, puis rend une photo PNG à chaque ligne « photo » de
// `piloter.py`, précédée de sa taille, jusqu'à la ligne « fin ». L'attente de la pose tourne
// là-bas, seule, pour les deux plateformes. Relevé par la revue de la 114, le 2026-11-19.
async function servirLesPhotos(page, lignes) {
  process.stdout.write('fait\n');
  for (;;) {
    const { value: ligne, done } = await lignes.next();
    if (done || ligne !== 'photo') break;
    const png = await photographier(page);
    process.stdout.write(`${png.length}\n`);
    process.stdout.write(png);
  }
}

async function rattacher() {
  const navigateur = await chromium.connectOverCDP(`http://127.0.0.1:${conf.port}`);
  const contexte = navigateur.contexts()[0];
  const pages = contexte.pages();
  return { navigateur, page: pages[pages.length - 1] };
}

// Les gestes reçoivent des pixels CSS. `jouer` les a convertis depuis le repère de la capture.
const GESTES = {
  voir: async () => {},
  toucher: async (page, [x, y]) => page.mouse.click(Number(x), Number(y)),
  // Un glissement de doigt fait défiler la page. Un glisser de souris, lui, sélectionne le
  // texte : deux testeurs se sont crus bloqués sur un écran de résultat, le 2026-11-16. Le
  // geste devient donc un défilement à la molette, du même déplacement, sous le doigt.
  glisser: async (page, [x1, y1, x2, y2]) => {
    await page.mouse.move(Number(x1), Number(y1));
    await page.mouse.wheel(Number(x1) - Number(x2), Number(y1) - Number(y2));
  },
  taper: async (page, [texte]) => page.keyboard.type(texte, { delay: 40 }),
  // `retour` et `relancer` rendent la main dès que la page change, sans attendre son chargement.
  // L'attente de la pose le mesure alors, comme sur Android. Relevé par la revue de la 114.
  retour: async (page) => page.goBack({ waitUntil: 'commit' }).catch(() => null),
  relancer: async (page) => page.goto(conf.url, { waitUntil: 'commit' }),
};

async function jouer(geste) {
  const lignes = readline.createInterface({ input: process.stdin })[Symbol.asyncIterator]();
  const { navigateur, page } = await rattacher();
  const origine = new URL(conf.url).origin;
  // L'échelle se mesure à chaque geste. Chromium sans fenêtre impose sa largeur minimale, et
  // une échelle tirée de la configuration visait à côté : mesuré, 751 pixels au lieu de 618.
  const echelle = await page.evaluate(() => devicePixelRatio);
  const [vw, vh] = await page.evaluate(() => [innerWidth, innerHeight]);
  // `piloter.py` reçoit la taille de la page, y décale le doigt, puis rend les valeurs du geste.
  // Le décalage n'a ainsi qu'une copie, la sienne. Relevé par la revue de la 114.
  process.stdout.write(`taille ${echelle} ${vw} ${vh}\n`);
  const { value: reponse } = await lignes.next();
  const valeurs = JSON.parse(reponse);
  const css = geste === 'taper' ? valeurs : valeurs.map((v) => Number(v) / echelle);
  await GESTES[geste](page, css);
  await servirLesPhotos(page, lignes);
  // Le constat seul, sans la commande qui ramène : un humain n'a personne pour la lui souffler.
  const remarques = new URL(page.url()).origin === origine ? []
    : ['Tu as quitté le site de départ.'];
  // Se détacher sans fermer : la page doit survivre jusqu'au geste suivant.
  await navigateur.close();
  // Aucune liste des éléments à toucher. Elle donnait le texte de chaque bouton et de chaque lien,
  // ce que le coup d'œil flou cache au testeur. Il vise sur l'image, comme un humain. 2026-11-18.
  return { remarques };
}

function demarrer() {
  const enfant = spawn(chromium.executablePath(), [
    '--headless=new', `--remote-debugging-port=${conf.port}`, `--user-data-dir=${conf.profil}`,
    `--window-size=${conf.largeur_css},${conf.hauteur_css}`,
    `--force-device-scale-factor=${conf.echelle}`, '--no-first-run', conf.url,
  ], { detached: true, stdio: 'ignore' });
  enfant.unref();
  process.stdout.write(`${enfant.pid}\n`);
}

async function arreter() {
  const { navigateur } = await rattacher();
  const session = await navigateur.newBrowserCDPSession();
  await session.send('Browser.close').catch(() => null);
}

async function principal() {
  const [geste] = process.argv.slice(2);
  if (geste === 'demarrer') return demarrer();
  if (geste === 'arreter') return arreter();
  if (!GESTES[geste]) throw new Error(`geste inconnu : ${geste}`);
  process.stdout.write(JSON.stringify(await jouer(geste)));
}

principal().catch((erreur) => {
  process.stderr.write(`${erreur.message.split('\n')[0]}\n`);
  process.exit(1);
});
