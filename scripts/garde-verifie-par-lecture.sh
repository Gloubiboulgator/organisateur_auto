#!/usr/bin/env bash
# garde-verifie-par-lecture.sh — DEMANDE confirmation quand un plan étiquette « vérifié » une
# affirmation dont la provenance annoncée juste après est une LECTURE de code.
#
# POURQUOI CE GARDE EXISTE
# --------------------------------------------------------
# Un plan de correctif a porté « **Vérifié** (lecture du code) — le rechargement lui-même
# fonctionne ». C'était faux : une autre fonction effaçait l'état juste après. Le plan a été
# approuvé sur cette base, et il a fallu trois passes de `/code-review` pour revenir dessus.
# `CLAUDE.md` § Les quatre règles du DIALOGUE couvrait le cas par sa règle 2 — « une source ne
# prouve que ce qu'elle couvre », « un commit prouve du code, pas un comportement » — et n'a pas
# tenu, parce que sa règle 1 range « lu » AVEC « exécuté » dans la même provenance « vérifié ».
# Cette définition est resserrée dans le même lot. Ce garde mécanise la part mécanisable :
# l'étiquette de certitude collée à une lecture.
#
# PÉRIMÈTRE, VOLONTAIREMENT ÉTROIT
# ---------------------------------
# `ExitPlanMode` seulement. C'est là qu'un diagnostic engage l'admin. Le régime est `ask`, PAS
# `deny`  : quatre passes de revue ont montré qu'un détecteur de
# français en expressions régulières ne peut pas être assez sûr pour BLOQUER. Un faux refus
# empêchait de soumettre son plan ; une fausse alerte coûte un clic. Ce choix inverse le
# compromis, et permet une liste de formes LARGE plutôt qu'étroite.
#
# LE DÉCLENCHEMENT EST VÉRIFIÉ, PAR EXÉCUTION
# --------------------------------------------
# Aucun hook du dépôt n'avait jamais visé `ExitPlanMode` : ses voisins se posent sur
# `Edit|Write`, `Bash|WebFetch` ou `Stop`. La question « un `PreToolUse` se déclenche-t-il sur cet
# outil » n'avait donc aucune réponse ici. Elle a été tranchée en le POSANT et en soumettant un
# plan d'appât : l'appel a été intercepté, et un témoin a capté la charge, qui
# porte `"hook_event_name":"PreToolUse"` et `"tool_name":"ExitPlanMode"`. Le témoin a été retiré
# ensuite. C'était la seule preuve valable — et, ironie utile, exactement ce que ce garde exige.
#
# INSTALLATION — aucune. Déclaré dans le `.claude/settings.json` versionné, qui suit le
# clone. La règle vit dans `docs/garde-fous.md`, section « Les gardes d'agent ».
#
# CE QU'IL NE COUVRE PAS (limites connues)
# -----------------------------------------
# - Un plan qui ne dit RIEN de sa provenance. C'est pourtant la faute la plus coûteuse de la série
#   fondatrice : le premier plan n'affirmait pas « vérifié », il se taisait. Un silence ne se
#   détecte pas en grep, et ce garde ne prétend pas le voir.
# - Un message de conversation qui affirme la même chose sans passer par un plan.
# - L'orthographe exacte des marqueurs, comme tout garde fondé sur une liste fermée.
# - « verifie » SANS accent et sans sujet devant, ni pronom ni groupe nominal. La forme est alors
#   ambiguë en français — participe ou verbe conjugué — et ce garde tranche pour l'étiquette, donc
#   alerte. Écrire l'accent lève l'ambiguïté dans les deux sens. Avec un sujet, en revanche, le
#   garde se tait même sans accent : « Le garde verifie la lecture du code » ne déclenche rien.
# - Une provenance annoncée AVANT l'étiquette, ou à plus de 45 caractères après elle. La fenêtre
#   ne regarde que vers l'avant, et court : « à la lecture du code, vérifié que… » n'est pas vu.
#   C'est le prix de juger chaque étiquette sur SA provenance, sans dépendre de la structure du
#   document — trois découpages successifs s'y sont cassé les dents.
# - Une exécution réelle annoncée dans le propos SUIVANT ne désarme pas. « Vérifié (lecture du
#   code) — ok. Test exécuté. » alerte, alors que l'exécution est peut-être la bonne preuve. Le
#   choix est assumé : l'inverse laissait n'importe quelle exécution voisine acheter le silence.
#   Citer l'exécution dans le MÊME propos que l'étiquette lève l'alerte.
# - Les deux fenêtres ne sont pas symétriques, et c'est voulu. L'accusation ne s'arrête qu'à une
#   fin de phrase ou de ligne, pour retrouver une provenance logée dans la cellule voisine d'un
#   tableau. L'exculpation, elle, s'arrête aussi au point-virgule et à la barre verticale : une
#   preuve doit appartenir à la MÊME proposition. Un doute accuse donc plus facilement qu'il
#   n'innocente, ce qui est le bon sens pour un garde qui demande confirmation.
# - Une étiquette CITÉE dans un bout de code entre accents graves parle du mot au lieu d'affirmer,
#   et ne déclenche rien. En revanche un plan qui PARLE de ce garde-ci en prose s'alerte lui-même :
#   la porte « guillemets » qui l'évitait a été retirée en 6e revue. Motif : dans ce dépôt, « … »
#   sert autant à mettre en valeur qu'à citer, donc elle ouvrait un passe-droit à la façon la plus
#   naturelle d'écrire l'étiquette. Sous un régime qui DEMANDE au lieu de refuser, une alerte de
#   trop coûte un clic, un passe-droit coûte le garde entier. L'arbitrage est assumé.
# - Lire un DOCUMENT (CHANGELOG, spec, fiche) ne déclenche rien : la source couvre alors le
#   domaine du fait. Seules les affirmations sur ce que le CODE fait sont visées.
set -uo pipefail

charge=$(cat 2>/dev/null) || exit 0

[ -n "$charge" ] || exit 0

# TOUT se fait en Python, extraction ET détection. Le fenêtrage en `grep -o` de la première
# version (repris d'un garde antérieur, hors de ce dépôt) rendait le garde AVEUGLE dès deux étiquettes
# proches : `grep -o` consomme ses correspondances sans recouvrement, donc la fenêtre de la
# première avalait la seconde, qui n'obtenait jamais la sienne. Et quand les deux tenaient dans
# une fenêtre, l'exécution citée pour l'une désarmait l'autre. Un plan aligne naturellement
# plusieurs « Vérifié : … » à quelques dizaines de caractères — la limite que le voisin se
# contente de documenter mordait ici tout le temps. Trouvé par `/code-review`, reproduit.
verdict=$(printf '%s' "$charge" | python3 -c '
import json, re, sys

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(d, dict) or d.get("tool_name") != "ExitPlanMode":
    sys.exit(1)
ti = d.get("tool_input")
if not isinstance(ti, dict):
    sys.exit(1)
plan = ti.get("plan")
if not isinstance(plan, str) or not plan:
    sys.exit(1)

# `re.I` sur TOUTES, y compris l étiquette. Sans lui, « VÉRIFIÉ » en majuscules d insistance —
# fréquent dans le style du dépôt — passait alors que « Vérifié » était refusé.
ETIQUETTE = re.compile(r"\bv[eé]rifi[eé](?:e|es|s)?\b", re.I)
# Ce qui, placé JUSTE devant, ôte à l étiquette sa valeur de certitude.
#   - un pronom sujet : « On vérifie le comportement » est un verbe, pas une étiquette ;
#   - une négation : « Non vérifié : lecture du code seulement » est la formulation HONNÊTE que
#     ce garde réclame, et il la refusait. Un garde antérieur, hors de ce dépôt, neutralisait la
#     négation avant de matcher ; il manquait ici.
# « encore » a été retiré de la liste : seul, il veut dire « de nouveau », pas « pas encore ». Il
# effaçait « encore exécuté ce matin », donc une preuve d exécution réelle. Trouvé par
# `/code-review`. La paire « pas encore » n est PAS rattrapée par « pas » toute seule, contrairement
# à ce qui était écrit ici : c est le pont à mots outils de `DESARME_DEVANT` qui la couvre.
NEGATION = (r"\b(non|pas|jamais|aucun(?:e)?|rien|sans)\b"
            r"|\bn[’\x27]\s*(?:a|est|ont|avait|ai)?\s*(?:pas|jamais)?\s*(?:[eé]t[eé])?\b"
            r"|\breste\s+[aà]\b|\bfaut\s+encore\b")
# Le pont entre la négation et l étiquette n accepte QUE de l espace, plus quelques mots outils.
# Il admettait la ponctuation, et une négation portant sur AUTRE CHOSE désarmait alors le garde :
# « Le correctif ne coûte rien : vérifié (lecture du code) — le rechargement fonctionne » passait
# en silence. C est la seule classe de défaut qui coûte plus qu un clic, puisque le garde manque
# la faute même qu il surveille. Les mots outils, eux, rattrapent « pas encore vérifié » et
# « n a pas encore été vérifié », que le pont ponctuation-seule laissait alerter alors que ce sont
# des aveux. Les deux trouvés par `/code-review`.
DESARME_DEVANT = re.compile(
    r"(\b(on|je|nous|il|elle|ils|elles|qui|tu)\s+"
    r"|(?:" + NEGATION + r")(?:\s+(?:encore|jamais|plus|[eé]t[eé])){0,2}\s*)$", re.I)
# Un sujet NOMINAL désarme aussi, mais UNIQUEMENT devant le présent « vérifie ». Devant le
# participe, « Le rechargement vérifié (lecture du code) » reste une affirmation. Sans cette
# porte, « Le garde vérifie la lecture du code » alertait — la phrase la plus banale d un dépôt
# qui décrit ses propres gardes. Trouvé par `/code-review`.
SUJET_NOMINAL = re.compile(
    r"\b(?:le|la|les|ce|cet|cette|ces|un|une|mon|ma|mes|notre|nos|leur|leurs|chaque)"
    r"\s+[\w’\x27-]+\s+$", re.I)
PRESENT = re.compile(r"v[eé]rifie", re.I)
# Liste LARGE, et c est un choix. Le garde DEMANDE, il ne refuse pas : un déclenchement de trop
# coûte un clic, un manque laisse passer la faute. La forme la plus probable est d ailleurs celle
# que la règle 1 encourage — nommer le fichier lu — et une liste étroite la ratait justement.
LECTURE = re.compile(
    r"\b(?:re)?lecture (?:du|de|des)\b|\ben (?:le |re)?lisant\b|\bd[’\x27]apr[eè]s le code\b"
    r"|\blu(?:e|s|es)? dans\b|\ben relisant\b|\bau vu du code\b"
    r"|\bdans le code\b|\bc[oô]t[eé] code\b", re.I)
# Ce qui nomme un ACTE d exécution DÉJÀ FAIT. « run », « sortie » et « grep » en avaient été
# retirés — vocabulaire courant, et un grep LIT du texte. Même raison ici pour « l exécuteur » et
# pour tout futur : « exécution prévue plus tard » est un aveu, pas une preuve, et il désarmait.
# PARTICIPES PASSÉS seulement, et l accent compte. Le français ne distingue pas « j ai exécuté »
# de « le code s exécute » autrement que par la terminaison, et la forme au PRÉSENT décrit ce que
# le code fait — c est justement l affirmation visée. « le service tourne bien », « le bouton
# lance la publication » désarmaient donc le garde avec les mots mêmes de la faute. Reproduit.
EXECUTION = re.compile(
    r"\bex[eé]cut(?:é|ée|és|ées)\b|\ben ex[eé]cutant\b"
    r"|\blanc(?:é|ée|és|ées)\b|\ben lan[çc]ant\b"
    r"|\btourn(?:é|ée|és|ées)\b|(?<!se )\breproduit\b", re.I)
# Un futur annule la preuve d exécution qui le précède ou le suit de peu. « ensuite » en a été
# retiré : après un participe passé, il marque un ordre dans le passé, pas un report. Il effaçait
# donc « exécuté ensuite le test », c est-à-dire la formulation honnête que ce garde récompense.
# « reste » nu en a été retiré aussi : il consommait une exécution réelle dès qu un reliquat la
# suivait, comme dans « exécuté, il reste deux cas ». La forme qui nie vraiment, « reste à », est
# déjà dans les négations. Trouvé par `/code-review`.
FUTUR = r"\bpr[eé]vu(?:e|s|es)?\b|\bplus tard\b|\b[aà] venir\b|\bsuivra\b"
# Lire un DOCUMENT est une vraie vérification : la source couvre alors le domaine du fait. La
# règle ne vise que les affirmations sur ce que le CODE fait. Sans cette porte, l élargissement
# ci-dessus alertait sur « vérifié en lisant le CHANGELOG », qui est légitime.
# « document » manquait, faute d un groupe mal découpé : `doc(?:s|umentation)?` ne couvrait pas
# `document`. Lire « le document » alertait donc, sur la formulation la plus littérale qui soit.
DOCUMENT_MOT = (r"CHANGELOG|README|SPECS?|docs?|documents?|documentation|specs?"
                r"|roadmap|registre|fiches?|CLAUDE")

def est_un_document(objet):
    """Vrai si l objet lu est un DOCUMENT, donc une source qui couvre le domaine du fait.

    Le test porte sur l objet ENTIER, jamais sur un morceau. Chercher le mot n importe où
    dedans blanchissait tout chemin de code qui en contient un — `/`, `-` et `.` n étant pas des
    lettres, la frontière de mot tombait au milieu. `scripts/doc-lint.sh`, `src/fiche.py`,
    `scripts/doc-mesure.py` se taisaient donc tous, alors que ce sont des fichiers de CODE.
    C est la classe de défaut qui coûte plus qu un clic. Trouvé par `/code-review`.

    Une extension de document tranche aussi : `docs/x.md` est un document, `docs/outils/x.sh`
    reste du code même s il vit sous `docs/`.
    """
    if not objet:
        return False
    if re.search(r"\.(?:md|txt|rst)$", objet, re.I):
        return True
    return bool(re.fullmatch(DOCUMENT_MOT, objet, re.I))
# Une exécution NIÉE ne prouve rien : « pas encore exécuté », « sans exécution réelle »,
# « reste à lancer » sont l aveu même que ce garde cherche. Elles désarmaient pourtant le refus,
# parce que la négation n était neutralisée que devant l étiquette. Reproduit par `/code-review`.
# Elle CONSOMME le mot d exécution, elle ne fait pas que le précéder. Une simple anticipation
# retirait la négation en laissant « exécuté » derrière, qui désarmait quand même.
# Le pont entre la négation et le verbe accepte la PONCTUATION. Limité aux lettres, il cassait sur
# « pas (encore) exécuté », « non, exécuté nulle part », « jamais — exécuté ici » : la négation
# n était alors pas consommée, et le participe survivant désarmait l alerte. L aveu le plus net
# que ce garde cherche devenait ainsi un passe-droit, et c est la NÉGATION qui l achetait.
# Trouvé par `/code-review`. Le pont ne franchit pas une fin de phrase.
# Le pont laisse passer la ponctuation et AU PLUS UN mot. Ouvert à dix-huit caractères libres, il
# avalait une négation bénigne portant sur autre chose : « sans souci, script exécuté » perdait sa
# preuve d exécution. C est le miroir exact du trou bouché à la 9e passe devant l étiquette, resté
# ouvert ici. Trouvé par `/code-review`.
PONT = r"[\s(),:;—\-]*(?:[\w’\x27]+[\s(),:;—\-]*)?"
EXECUTION_NIEE = re.compile(
    r"(?:(?:" + NEGATION + r"|" + FUTUR + r")" + PONT + r"(?:" + EXECUTION.pattern + r")"
    r"|(?:" + EXECUTION.pattern + r")" + PONT + r"(?:" + FUTUR + r"))", re.I)
# Un participe accroché à un nom QUALIFIE ce nom, il ne raconte pas un acte accompli. « le job
# lancé par le cron », « le test tourné hier », « le defaut reproduit ce comportement » désarmaient
# le garde sans qu aucune exécution ait eu lieu. C est le piège que l en-tête ci-dessus décrit pour
# le PRÉSENT, à un cran de là. Trouvé par `/code-review`.
EXECUTION_ADJECTIVALE = re.compile(
    r"\b(?:le|la|les|un|une|ce|cet|cette|ces|mon|ma|mes|notre|nos|leur|leurs)"
    r"\s+[\w’\x27-]+\s+(?:" + EXECUTION.pattern + r")", re.I)
# Une étiquette CITÉE n affirme rien : elle parle du mot. Deux portes ont existé pour ça, les
# guillemets et le bout de code. Celle des guillemets a été RETIRÉE (revue) : elle
# se trompait déjà de sens — tester « l un des guillemets » prenait un `»` FERMANT pour une
# ouverture, et le cas fondateur s échappait par accident. Mais la vraie raison est ailleurs.
# Dans ce dépôt, « … » sert autant
# à mettre en valeur que pour citer. Elle offrait donc un passe-droit à la façon la plus naturelle
# d écrire l étiquette. Le régime `ask` change l arbitrage — demander sur une vraie citation
# coûte un clic, laisser filer une vraie affirmation coûte la faute que ce garde existe pour
# voir. Seul le bout de code reste une citation, parce qu il ne s écrit pas par hasard.

# Les morceaux de code sont DÉLIMITÉS pour de vrai, une fois, sur tout le texte. Trois écritures
# ont échoué avant celle-ci, toutes reproduites : la parité sur tout le texte qui précède rendait
# aveugles toutes les étiquettes suivantes dès qu un accent grave orphelin traînait plus haut ;
# « un accent de chaque côté » prenait deux morceaux SANS RAPPORT pour un seul ; la parité sur une
# fenêtre de 40 caractères ne voyait que l accent FERMANT d un morceau ouvert plus tôt, et
# concluait l inverse. Ce dernier cas visait la forme que la règle 1 encourage — nommer le fichier
# lu — donc il mordait sur le style de plan le plus courant du dépôt. Trouvé par `/code-review`.
# Apparier les délimiteurs supprime la question : on sait où chaque morceau commence et finit.
MORCEAU_DE_CODE = re.compile(r"(\x60+)(?:(?!\1)[\s\S])*?\1")

def zones_de_code(texte):
    return [(m.start(), m.end()) for m in MORCEAU_DE_CODE.finditer(texte)]

def dans_un_code(zones, debut, fin):
    """Vrai si l étiquette est DANS un morceau de code, donc citée et non affirmée."""
    return any(a < debut and fin < b for a, b in zones)

# Fenêtre COURTE autour de l étiquette, au lieu d un découpage en unités markdown. Ce découpage
# ne voyait ni les lignes en **gras** sans puce — le style de plan du dépôt — ni les tableaux, et
# recollait alors deux étiquettes voisines : la première rendait la seconde aveugle. Une fenêtre
# étroite juge CHAQUE étiquette sur SA propre provenance, sans dépendre de la structure du
# document. Trouvé par `/code-review`, reproduit.
# La fenêtre regarde VERS L AVANT seulement. Une étiquette annonce sa provenance après elle
# (« Vérifié (lecture du code) »). Regarder en arrière ramassait la provenance de l étiquette
# PRÉCÉDENTE, et son exécution désarmait celle-ci — le défaut « aveugle dès deux étiquettes
# proches », qui a survécu à deux corrections. Limite assumée : « à la lecture du code, vérifié
# que… » n est pas vu.
APRES = 45
PORTEE_PREUVE = 140
# Les retours à la ligne deviennent des espaces, pour qu une provenance repoussée à la ligne
# suivante reste lisible. Mais leur POSITION est gardée : c est une frontière de propos, et la
# perdre est ce qui laissait l exécution d une AUTRE ligne désarmer celle-ci.
segments = re.split(r"[ \t]*\n[ \t]*", plan)
texte = ""
frontieres = set()
for rang, segment in enumerate(segments):
    if rang:
        frontieres.add(len(texte))
        texte += " "
    texte += segment
ZONES = zones_de_code(texte)

def fin_du_propos(depart, plafond, durs_seulement=False):
    """Où s arrête le propos ouvert à `depart`, sans dépasser `plafond`.

    Le désarmement par exécution ne vaut que DANS le propos qui porte l étiquette. Sans cette
    borne, « Vérifié (lecture du code) — ok. Test exécuté. » se taisait : une exécution portant
    sur autre chose achetait le silence. C est le défaut « aveugle dès deux étiquettes proches »,
    corrigé en arrière lors de la 3e passe, et resté intact en AVANT. Trouvé par `/code-review`.

    Ni « : » ni le tiret cadratin ne coupent : ils INTRODUISENT la provenance dans ce dépôt.

    `durs_seulement` ne retient que la fin de phrase et le retour à la ligne. C est ce qu il faut
    pour chercher la PROVENANCE, qu une cellule de tableau sépare légitimement de son étiquette.
    """
    for i in range(depart, min(plafond, len(texte))):
        if i in frontieres:
            return i
        if not durs_seulement and texte[i] in ";|":
            return i
        if texte[i] in ".!?" and (i + 1 >= len(texte) or texte[i + 1].isspace()):
            return i
    return plafond

for m in ETIQUETTE.finditer(texte):
    gauche = texte[:m.start()]
    # La mise en forme est retirée AVANT de chercher le désarmement. Sans ça, « Non **vérifié** »
    # — le gras étant le style de plan du dépôt — alertait, c est-à-dire exactement sur la
    # formulation honnête que le message de ce garde recommande. Reproduit.
    # L ESPACE, elle, est gardée : la branche du pronom exige une espace après lui, et la retirer
    # avec les astérisques faisait alerter « On vérifie … ». Trouvé en rejouant le corpus.
    # Les guillemets sont retirés avec le gras : la 6e passe leur a ôté le droit de CITER, ce qui
    # a eu l effet de bord d empêcher la négation d ATTEINDRE l étiquette. « Non « vérifié » »
    # alertait alors, alors que « Non **vérifié** » se taisait. Trouvé par `/code-review`.
    contexte = re.sub(r"[*_~«»“”\x22]", "", gauche)[-28:]
    if DESARME_DEVANT.search(contexte):
        continue                      # verbe conjugué, ou aveu honnête (« non vérifié »)
    if PRESENT.fullmatch(m.group(0)) and SUJET_NOMINAL.search(contexte):
        continue                      # « Le garde vérifie … » : un verbe, pas une étiquette
    if dans_un_code(ZONES, m.start(), m.end()):
        continue                      # l étiquette est un bout de code cité, pas une affirmation
    # La provenance est cherchée dans le PROPOS de l étiquette, pas dans 45 caractères aveugles.
    # La 8e passe avait posé cette borne pour le désarmement seul, et l accusation, elle, sautait
    # encore la frontière : une lecture citée à la puce SUIVANTE accusait une étiquette adossée à
    # un test. Même défaut, même correctif, un cran plus loin. Trouvé par `/code-review`.
    fenetre = texte[m.start():fin_du_propos(m.end(), m.end() + APRES, durs_seulement=True)]
    lu = LECTURE.search(fenetre)
    if not lu:
        continue
    # Une provenance CITÉE entre accents graves parle du mot, comme l étiquette citée plus haut.
    # L exemption ne valait que pour l étiquette : les deux sont maintenant symétriques.
    if dans_un_code(ZONES, m.start() + lu.start(), m.start() + lu.end()):
        continue
    # Le document doit être l OBJET de la lecture, donc le PREMIER NOM qui la suit. Deux
    # corrections successives ici. Chercher le document dans toute la fenêtre laissait « lecture
    # du code : conforme à la spec » passer pour une lecture de document, alors que c est une
    # affirmation sur le CODE. Déplacer l origine de la tranche n a pas suffi : sa LONGUEUR, elle,
    # dépassait encore l objet, et « lecture du code de la spec de publication » se blanchissait
    # avec un mot situé bien plus loin dans la phrase. Reproduit par `/code-review`.
    # Un seul mot est donc lu, l article retiré, et « code » tranche pour lui-même. « fichier »,
    # lui, ne dit RIEN de ce qu on a lu : le mot suivant tranche, sinon l inscrire au dictionnaire
    # blanchissait la lecture d un fichier source, c est-à-dire le cas même que ce garde vise.
    # Les deux mots sont pris SANS tranche fixe. Coupée à 40 caractères, elle tronquait les
    # chemins longs. `.claude/skills/auto-learn-skill/references/preuve.md` perdait son extension et
    # redevenait du code. Une longueur arbitraire s est trompée à chaque tour de ce garde.
    depart = m.start() + lu.end()
    suivant = re.match(r"\s*(?:(?:la|le|les|l[’\x27])\s*)?([\w’\x27./\-]+)(?:\s+([\w’\x27./\-]+))?",
                       texte[depart:])
    mots = [g for g in (suivant.groups() if suivant else ()) if g]
    objet = mots[0] if mots else ""
    if re.fullmatch(r"fichiers?", objet, re.I):
        objet = mots[1] if len(mots) > 1 else ""
    if re.fullmatch(r"code|sources?", objet, re.I):
        objet = ""                    # lire du CODE reste du code, quoi qu on en dise après
    if est_un_document(objet):
        continue                      # lire un document PROUVE ce qu il dit : rien à signaler
    # La PREUVE porte plus loin que l ACCUSATION. Bornée aux mêmes 45 caractères, l exculpation
    # ratait « — sans souci, script exécuté » : le garde accusait alors avec du texte qu il
    # refusait de lire pour disculper. La frontière de propos, elle, reste la vraie borne.
    propos = texte[m.start():fin_du_propos(m.end(), m.end() + PORTEE_PREUVE)]
    reste = EXECUTION_ADJECTIVALE.sub(" ", EXECUTION_NIEE.sub(" ", propos))
    if EXECUTION.search(reste):
        continue                      # une exécution RÉELLE et PASSÉE est citée dans CE propos
    print("REFUS")
    sys.exit(0)
' 2>/dev/null) || exit 0

if [ "$verdict" = "REFUS" ]; then
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Ce plan semble etiqueter « verifie » une affirmation dont la provenance annoncee est une LECTURE de code. Une lecture prouve ce que le code DIT, pas ce qu il FAIT (CLAUDE.md, regle 2 du DIALOGUE). As-tu execute, ou faut-il ecrire « lu, non execute » ? Valide si l alerte tombe a cote."}}
JSON
fi
exit 0
