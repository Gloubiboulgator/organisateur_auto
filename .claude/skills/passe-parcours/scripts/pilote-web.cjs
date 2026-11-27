#!/usr/bin/env node
// pilote-web.cjs — la moitié web du pilote de la passe parcours.
//
// POURQUOI CE FICHIER EXISTE
// --------------------------
// `piloter.py` joue chaque geste dans un processus neuf. Un navigateur Playwright meurt avec le
// processus qui l'a lancé, et la page repartirait de zéro à chaque geste. Un serveur Node garde
// donc le navigateur et la page ouverts tout le test. Chaque geste s'y relie par une socket
// locale, sur le port de la configuration. La page, son historique et ses cookies survivent.
//
// Le pilote se rattachait avant à Chromium par CDP, le protocole de débogage de Chrome. La
// documentation de Playwright le dit réservé aux navigateurs de la famille Chromium. Le serveur
// sert les trois moteurs de Playwright, Chromium, Firefox et WebKit, par le même code. Demandé
// par l'admin le 2026-11-27.
//
// CE QU'IL N'EST PAS. Il ne parle jamais au testeur. `piloter.py` reçoit sa sortie JSON, et
// c'est lui qui écrit au testeur, sans chemin ni nom de projet.
//
// COMMENT ON S'EN SERT, depuis `lancer_testeurs.py` et `piloter.py`, jamais à la main :
//     node pilote-web.cjs demarrer
//     node pilote-web.cjs toucher
//     node pilote-web.cjs arreter
// `demarrer` lance le serveur à part, `serveur` est son nom interne. Un geste ouvre une
// connexion, et relaie tel quel son entrée et sa sortie. Le dialogue reste celui que
// `piloter.py` tenait déjà avec le pilote.
// La configuration se lit dans le fichier que nomme `F5_PILOTE`. Playwright se trouve par
// `NODE_PATH`, que le lanceur pose. Le moteur se lit dans sa clé `moteur`, Chromium sans elle.
// Sa clé `canal` désigne une version de marque, Chrome ou Edge. Sa clé `appareil` nomme un
// téléphone du registre de Playwright, comme « Pixel 5 », que la page imite alors.
'use strict';
const fs = require('fs');
const net = require('net');
const readline = require('readline');
const { spawn } = require('child_process');

const conf = JSON.parse(fs.readFileSync(process.env.F5_PILOTE, 'utf8'));
// L'erreur d'un geste passe par ce fichier. La socket porte des photos binaires, où une ligne
// d'erreur ne se distinguerait pas.
const FICHIER_ERREUR = `${process.env.F5_PILOTE}.erreur`;

function chargerMoteur() {
  let playwright;
  try {
    playwright = require('playwright');
  } catch (erreur) {
    process.stderr.write('Playwright est introuvable. Installer : npm install --prefix <dossier> playwright\n');
    process.exit(3);
  }
  const moteur = playwright[conf.moteur || 'chromium'];
  if (!moteur) {
    process.stderr.write(`moteur inconnu : ${conf.moteur}\n`);
    process.exit(3);
  }
  return moteur;
}

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

async function envoyerPhoto(page, sortie) {
  const png = await photographier(page);
  sortie.write(`${png.length}\n`);
  sortie.write(png);
}

// L'onglet passe derrière un autre, comme quand on quitte le navigateur pour un appel, puis
// revient. Ajouté le 2026-11-27 avec l'option d'interruption.
async function interrompre(page, secondes) {
  const autre = await page.context().newPage();
  await autre.bringToFront();
  await new Promise((fini) => setTimeout(fini, secondes * 1000));
  await autre.close();
  await page.bringToFront();
}

// Dit « fait » une fois le geste joué, puis rend une photo PNG à chaque ligne « photo » de
// `piloter.py`, précédée de sa taille, jusqu'à la ligne « fin ». L'attente de la pose tourne
// là-bas, seule, pour les deux plateformes. Relevé par la revue de la 114, le 2026-11-19.
// « retoucher » rejoue le geste, pour le toucher impatient. « interrompre S » fait passer
// l'onglet derrière un autre S secondes. Les deux répondent « fait ».
async function servirLesPhotos(page, lignes, sortie, rejouer) {
  sortie.write('fait\n');
  for (;;) {
    const { value: ligne, done } = await lignes.next();
    if (done) break;
    if (ligne === 'photo') {
      await envoyerPhoto(page, sortie);
    } else if (ligne === 'retoucher') {
      await rejouer();
      sortie.write('fait\n');
    } else if (ligne.startsWith('interrompre ')) {
      await interrompre(page, Number(ligne.split(' ')[1]));
      sortie.write('fait\n');
    } else {
      break;
    }
  }
}

// Vrai quand la page imite un téléphone tactile. Posé une fois, au lancement du serveur.
let tactile = false;
// Les pixels de la page par pixel reçu. Il vaut 1, sauf sous WebKit tactile, où les gestes
// arrivent en pixels de l'écran. Posé par `jouer` à chaque geste. Revue de la 121.
let versPage = 1;

// Les gestes reçoivent des pixels CSS. `jouer` les a convertis depuis le repère de la capture.
const GESTES = {
  voir: async () => {},
  // Un téléphone imité reçoit un toucher du doigt, les autres un clic de souris.
  toucher: async (page, [x, y]) => (tactile
    ? page.touchscreen.tap(Number(x), Number(y))
    : page.mouse.click(Number(x), Number(y))),
  // Un glissement de doigt fait défiler la page. Un glisser de souris, lui, sélectionne le
  // texte : deux testeurs se sont crus bloqués sur un écran de résultat, le 2026-11-16. Le
  // geste devient donc un défilement à la molette, du même déplacement, sous le doigt.
  // Un téléphone imité n'a pas de molette, WebKit mobile la refuse : « Mouse wheel is not
  // supported in mobile WebKit », vu le 2026-11-27. La page défile alors elle-même, sous le
  // doigt, dans la première zone qui défile, ou la page entière.
  glisser: async (page, [x1, y1, x2, y2]) => {
    if (tactile) {
      await page.evaluate(([x, y, dx, dy]) => {
        let zone = document.elementFromPoint(x, y);
        while (zone && zone !== document.body) {
          const style = getComputedStyle(zone);
          const defile = /(auto|scroll)/.test(style.overflowY + style.overflowX)
            && (zone.scrollHeight > zone.clientHeight || zone.scrollWidth > zone.clientWidth);
          if (defile) break;
          zone = zone.parentElement;
        }
        (zone && zone !== document.body ? zone : window).scrollBy(dx, dy);
      }, [x1, y1, x1 - x2, y1 - y2].map((v) => Number(v) * versPage));
      return;
    }
    await page.mouse.move(Number(x1), Number(y1));
    await page.mouse.wheel(Number(x1) - Number(x2), Number(y1) - Number(y2));
  },
  taper: async (page, [texte]) => page.keyboard.type(texte, { delay: 40 }),
  // `retour` et `relancer` rendent la main dès que la page change, sans attendre son chargement.
  // L'attente de la pose le mesure alors, comme sur Android. Relevé par la revue de la 114.
  retour: async (page) => page.goBack({ waitUntil: 'commit' }).catch(() => null),
  relancer: async (page) => page.goto(conf.url, { waitUntil: 'commit' }),
};

// Un geste, dialogué sur la connexion : la taille de la page, les valeurs reçues, « fait », les
// photos, puis le JSON de fin.
async function jouer(page, geste, lignes, sortie) {
  const origine = new URL(conf.url).origin;
  // L'unité des gestes, en pixels de capture. Une page sans balise viewport s'affiche dézoomée
  // sur un téléphone imité. Chromium y vise alors en pixels de la page, WebKit en pixels de
  // l'écran, mesuré le 2026-11-27 par un toucher sur un bouton. Ailleurs, les deux se valent.
  const ecran = page.viewportSize();
  const [lw, lh] = await page.evaluate(() => [innerWidth, innerHeight]);
  const enEcran = tactile && conf.moteur === 'webkit';
  const echelle = enEcran ? conf.echelle : (conf.echelle * ecran.width) / lw;
  const [vw, vh] = enEcran ? [ecran.width, ecran.height] : [lw, lh];
  // Le défilement tactile vise par `elementFromPoint` et `scrollBy`, en pixels de la page.
  versPage = enEcran ? lw / ecran.width : 1;
  // `piloter.py` reçoit la taille de la page, y décale le doigt, puis rend les valeurs du geste.
  // Le décalage n'a ainsi qu'une copie, la sienne. Relevé par la revue de la 114. Le dernier
  // nombre, les pixels de capture par pixel d'écran, garde au doigt sa taille réelle.
  sortie.write(`taille ${echelle} ${vw} ${vh} ${conf.echelle}\n`);
  // Une photo peut se demander avant le geste : l'écran d'avant, pour le toucher impatient.
  let { value: reponse } = await lignes.next();
  while (reponse === 'photo') {
    await envoyerPhoto(page, sortie);
    ({ value: reponse } = await lignes.next());
  }
  const valeurs = JSON.parse(reponse);
  const css = geste === 'taper' ? valeurs : valeurs.map((v) => Number(v) / echelle);
  await GESTES[geste](page, css);
  await servirLesPhotos(page, lignes, sortie, () => GESTES[geste](page, css));
  // Le constat seul, sans la commande qui ramène : un humain n'a personne pour la lui souffler.
  const remarques = new URL(page.url()).origin === origine ? []
    : ['Tu as quitté le site de départ.'];
  // Aucune liste des éléments à toucher. Elle donnait le texte de chaque bouton et de chaque lien,
  // ce que le coup d'œil flou cache au testeur. Il vise sur l'image, comme un humain. 2026-11-18.
  sortie.write(JSON.stringify({ remarques }));
}

// Le serveur : un navigateur au profil vide, une page sur l'adresse de départ, et une connexion
// traitée à la fois. La page de travail est la plus récente, celle qu'un lien a pu ouvrir.
// Un téléphone imité prend du registre sa taille, son identité de navigateur mobile et l'écran
// tactile. Son échelle reste celle de la configuration, pour des captures de même poids
// qu'ailleurs. Ce sont les profils « Mobile Chrome » et « Mobile Safari » de la page
// https://playwright.dev/docs/browsers, lue le 2026-11-27.
function reglagesDuNavigateur() {
  const base = { headless: true, channel: conf.canal || undefined };
  if (!conf.appareil) {
    return { ...base, viewport: { width: conf.largeur_css, height: conf.hauteur_css },
      deviceScaleFactor: conf.echelle };
  }
  const { defaultBrowserType, ...appareil } = require('playwright').devices[conf.appareil];
  return { ...base, ...appareil, deviceScaleFactor: conf.echelle };
}

async function serveur() {
  const moteur = chargerMoteur();
  const reglages = reglagesDuNavigateur();
  const contexte = await moteur.launchPersistentContext(conf.profil, reglages);
  tactile = Boolean(reglages.hasTouch);
  const premiere = contexte.pages()[0] || await contexte.newPage();
  await premiere.goto(conf.url, { waitUntil: 'commit' }).catch(() => null);
  let file = Promise.resolve();
  // La connexion reste ouverte dans un sens quand le geste a fini d'écrire. Sans cela, une
  // entrée close tôt fermerait la connexion avant la réponse.
  const ecoute = net.createServer({ allowHalfOpen: true }, (socket) => {
    // La fin de la connexion se guette dès son arrivée. Elle peut se fermer en attendant son
    // tour, comme le simple essai du port que fait le lanceur.
    const fermee = new Promise((fini) => socket.once('close', fini));
    // Un relais tué en plein geste coupe la connexion. Sans écoute, l'erreur d'écriture tuerait
    // le serveur, et le navigateur avec lui. Revue de la 121.
    socket.on('error', () => {});
    file = file.then(() => traiter(contexte, socket, fermee)).catch(() => null);
  });
  // Un port déjà pris se dit, au lieu d'un serveur mort en silence. Revue de la 121.
  ecoute.on('error', (erreur) => {
    fs.writeFileSync(FICHIER_ERREUR, `port ${conf.port} : ${erreur.message.split('\n')[0]}`);
    process.exit(1);
  });
  ecoute.listen(conf.port, '127.0.0.1');
}

async function traiter(contexte, socket, fermee) {
  const lignes = readline.createInterface({ input: socket })[Symbol.asyncIterator]();
  const { value: geste, done } = await lignes.next();
  if (done) return;
  if (geste === 'arreter') {
    await contexte.close().catch(() => null);
    socket.end();
    process.exit(0);
  }
  try {
    if (!GESTES[geste]) throw new Error(`geste inconnu : ${geste}`);
    const pages = contexte.pages();
    await jouer(pages[pages.length - 1], geste, lignes, socket);
    socket.end();
  } catch (erreur) {
    // Une connexion déjà coupée n'a plus de relais pour lire l'erreur. L'écrire la ferait dire
    // au geste suivant, qui attend son tour. Revue de la 121.
    if (!socket.destroyed) fs.writeFileSync(FICHIER_ERREUR, erreur.message.split('\n')[0]);
    // `end` et non `destroy` : des lignes encore en route provoqueraient sinon une remise à
    // zéro, et le relais dirait « ne répond pas » au lieu de l'erreur. Revue de la 121.
    socket.end();
  }
  await fermee;
}

// Un geste vu de `piloter.py` : relayer l'entrée vers le serveur, et sa réponse vers la sortie.
// Une erreur du serveur se dit sur la sortie d'erreur, avant que la sortie ne se ferme.
function relayer(geste) {
  fs.rmSync(FICHIER_ERREUR, { force: true });
  const socket = net.connect(conf.port, '127.0.0.1', () => {
    socket.write(`${geste}\n`);
    process.stdin.pipe(socket);
  });
  socket.on('data', (morceau) => process.stdout.write(morceau));
  socket.on('error', () => {
    const cause = fs.existsSync(FICHIER_ERREUR) ? fs.readFileSync(FICHIER_ERREUR, 'utf8')
      : 'le navigateur ne répond pas';
    process.stderr.write(`${cause}\n`);
    process.exit(1);
  });
  socket.on('close', () => {
    if (fs.existsSync(FICHIER_ERREUR)) {
      process.stderr.write(`${fs.readFileSync(FICHIER_ERREUR, 'utf8')}\n`);
      process.exitCode = 1;
    }
    process.stdout.end(() => process.exit());
  });
}

function demarrer() {
  const enfant = spawn(process.execPath, [__filename, 'serveur'], {
    detached: true, stdio: 'ignore', env: process.env,
  });
  enfant.unref();
  process.stdout.write(`${enfant.pid}\n`);
}

function arreter() {
  const socket = net.connect(conf.port, '127.0.0.1', () => socket.write('arreter\n'));
  socket.on('error', () => process.exit(0));
  socket.on('close', () => process.exit(0));
}

const [commande] = process.argv.slice(2);
if (commande === 'demarrer') demarrer();
else if (commande === 'serveur') serveur().catch((erreur) => {
  // Playwright met la cause d'un lancement raté sur les lignes suivantes, pas sur la première.
  const lignes = erreur.message.split('\n').map((l) => l.trim()).filter(Boolean);
  fs.writeFileSync(FICHIER_ERREUR, lignes.slice(0, 3).join(' '));
  process.exit(1);
});
else if (commande === 'arreter') arreter();
else relayer(commande);
