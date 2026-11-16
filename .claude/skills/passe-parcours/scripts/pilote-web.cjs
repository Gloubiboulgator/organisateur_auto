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
//     node pilote-web.cjs toucher 215 640 <capture.jpg>
//     node pilote-web.cjs arreter
// La configuration se lit dans le fichier que nomme `F5_PILOTE`. Playwright se trouve par
// `NODE_PATH`, que le lanceur pose.
'use strict';
const fs = require('fs');
const { spawn } = require('child_process');

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch (erreur) {
  process.stderr.write('Playwright est introuvable. Installer : npm install --prefix <dossier> playwright\n');
  process.exit(3);
}

const conf = JSON.parse(fs.readFileSync(process.env.F5_PILOTE, 'utf8'));
// Le temps laissé à la page pour réagir avant la photo, comme côté Android.
const REPOS_APRES_GESTE = 1500;
// Au-delà, la liste noie l'écran sous les liens de pied de page.
const ELEMENTS_MAX = 40;

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
  retour: async (page) => page.goBack().catch(() => null),
  relancer: async (page) => page.goto(conf.url),
};

function elementsVisibles() {
  // Évaluée dans la page : ce qu'un humain voit et peut toucher, sans aucun identifiant.
  // Le curseur « main » rattrape les boutons faits de simples blocs, que les balises manquent.
  // Un bloc dont le parent montre déjà la main est un morceau du même bouton, il ne compte pas.
  const cibles = 'a, button, input, select, textarea, summary, label, [role=button], [role=link]';
  const main = (noeud) => noeud && getComputedStyle(noeud).cursor === 'pointer';
  const noeuds = [...document.querySelectorAll('body *')].filter((noeud) => noeud.matches(cibles)
    || (main(noeud) && !main(noeud.parentElement)));
  return noeuds.map((noeud) => {
    const boite = noeud.getBoundingClientRect();
    const texte = (noeud.innerText || noeud.getAttribute('aria-label') || noeud.placeholder
      || noeud.value || '').trim().replace(/\s+/g, ' ').slice(0, 60);
    return { texte, x: boite.x + boite.width / 2, y: boite.y + boite.height / 2,
      visible: boite.width > 0 && boite.height > 0 && boite.bottom > 0
        && boite.top < innerHeight && getComputedStyle(noeud).visibility !== 'hidden' };
  }).filter((e) => e.visible && e.texte);
}

async function jouer(geste, valeurs, destination) {
  const { navigateur, page } = await rattacher();
  const origine = new URL(conf.url).origin;
  // L'échelle se mesure à chaque geste. Chromium sans fenêtre impose sa largeur minimale, et
  // une échelle tirée de la configuration visait à côté : mesuré, 751 pixels au lieu de 618.
  const echelle = await page.evaluate(() => devicePixelRatio);
  await GESTES[geste](page, geste === 'taper' ? valeurs : valeurs.map((v) => Number(v) / echelle));
  await page.waitForTimeout(geste === 'voir' ? 0 : REPOS_APRES_GESTE);
  await page.screenshot({ path: destination, type: 'jpeg', quality: 75 });
  const bruts = await page.evaluate(elementsVisibles);
  const elements = bruts.slice(0, ELEMENTS_MAX).map((e) => ({ texte: e.texte,
    x: Math.round(e.x * echelle), y: Math.round(e.y * echelle) }));
  const largeur = Math.round((await page.evaluate(() => innerWidth)) * echelle);
  const remarques = new URL(page.url()).origin === origine ? []
    : ["Tu as quitté le site de départ. « relancer » t'y ramène."];
  // Se détacher sans fermer : la page doit survivre jusqu'au geste suivant.
  await navigateur.close();
  return { elements, remarques, largeur };
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
  const [geste, ...reste] = process.argv.slice(2);
  if (geste === 'demarrer') return demarrer();
  if (geste === 'arreter') return arreter();
  if (!GESTES[geste]) throw new Error(`geste inconnu : ${geste}`);
  const destination = reste.pop();
  process.stdout.write(JSON.stringify(await jouer(geste, reste, destination)));
}

principal().catch((erreur) => {
  process.stderr.write(`${erreur.message.split('\n')[0]}\n`);
  process.exit(1);
});
