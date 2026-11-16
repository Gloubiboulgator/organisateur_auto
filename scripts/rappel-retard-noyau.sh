#!/usr/bin/env bash
# rappel-retard-noyau.sh — DIT au démarrage d'une session qu'un projet a pris du retard sur le
# noyau. Une ligne au plus, et jamais de blocage.
#
# POURQUOI. Un projet équipé a passé dix jours sans recevoir une règle qui devait réduire le coût
# de ses revues de moitié. L'avertissement de verifier-noyau.sh ne tourne qu'au commit, et il ne
# sait pas comparer depuis un worktree, où le dépôt du noyau n'est plus à côté du projet.
#
# LE SEUIL est de sept jours, décidé par l'admin le 2026-10-30. RAPPEL_RETARD_JOURS le change.
# LE RETARD se compte depuis l'arrivée, sur la ligne principale du noyau, du premier changement
# que le projet n'a pas reçu. La date d'écriture sur une branche dirait un retard qui n'existe pas.
# SANS LE DÉPÔT DU NOYAU, en session cloud par exemple, il ne se calcule pas. Le script dit alors
# l'âge de la dernière pose, et rien de plus. Même chose quand la ligne principale ne contient
# pas le commit posé : branche jamais fusionnée, ou fusionnée sans garder ses commits.
# ÉCHOUE OUVERT : tout cas inattendu sort en zéro, sans rien dire.
set -uo pipefail
cible=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
# LE DOSSIER PRINCIPAL, pas le worktree. Le dépôt du noyau se cherche à côté de lui.
commun=$(git -C "$cible" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || commun=""
principal=$(dirname "${commun:-$cible/.git}")
# UN FICHIER IGNORÉ PAR GIT n'est pas dans un worktree. Il se lit alors dans le dossier principal.
empreintes="$cible/.noyau-empreintes"
[ -f "$empreintes" ] || empreintes="$principal/.noyau-empreintes"
[ -f "$empreintes" ] || exit 0
seuil=${RAPPEL_RETARD_JOURS:-7}
maintenant=$(date +%s)
pose=$(sed -n 's/^# version-noyau: //p' "$empreintes" | head -n 1)
# Le chemin noté à la pose, dont le tilde se redéveloppe ici, comme dans verifier-noyau.sh.
enregistre=$(sed -n 's/^# source-noyau: //p' "$empreintes" | head -n 1)
case "$enregistre" in "~/"*) enregistre="${HOME:-}${enregistre#\~}" ;; esac

source_depot=""
raison="son dépôt n'est pas joignable d'ici"
for piste in "${NOYAU_METHODE:-}" "$enregistre" "$principal/../structure_projet" "$principal/../methodo"; do
    [ -n "$piste" ] && [ -d "$piste/noyau" ] || continue
    # Un dossier sans dépôt n'est pas un dépôt qui ignore la version : il ne change pas la raison.
    git -C "$piste" rev-parse --git-dir >/dev/null 2>&1 || continue
    if git -C "$piste" cat-file -e "${pose}^{commit}" 2>/dev/null; then
        source_depot="$piste"
        break
    fi
    raison="le dépôt du noyau trouvé ici ne connaît pas cette version"
done

if [ -n "$source_depot" ]; then
    # LA LIGNE PRINCIPALE CONNUE, pas la branche que ce dossier porte. Elle ne se rafraîchit pas
    # ici : le démarrage ne touche pas au réseau, et elle vaut ce que le dernier fetch a rapporté.
    reference=HEAD
    for ref in origin/HEAD origin/main; do
        git -C "$source_depot" rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1 || continue
        reference=$ref
        break
    done
    # ON COMPARE L'ARBRE noyau/, PAS LA LISTE DES COMMITS. La pose note un commit de branche, et
    # sa fusion le suit : « -- noyau » la liste, et son arbre, égal à celui de la pose, l'écarte.
    # Le filtre ne garde que les commits qui changent noyau/, au lieu d'ouvrir chacun d'eux.
    # SEUL UN COMMIT QUI CONTIENT LA POSE COMPTE. Avant la fusion du commit posé, la ligne est en
    # retard sur le projet, pas l'inverse. Sans commit qui la contienne, le retard ne se calcule
    # pas, et le script dit l'âge de la pose, comme sans dépôt.
    # UN CHANGEMENT DÉFAIT NE COMPTE PAS : un arbre revenu à celui de la pose remet la date à zéro.
    arbre=$(git -C "$source_depot" rev-parse "$pose:noyau" 2>/dev/null) || exit 0
    [ "$(git -C "$source_depot" rev-parse "$reference:noyau" 2>/dev/null)" != "$arbre" ] || exit 0
    date=""
    for commit in $(git -C "$source_depot" rev-list --first-parent --reverse "$pose..$reference" -- noyau 2>/dev/null); do
        git -C "$source_depot" merge-base --is-ancestor "$pose" "$commit" 2>/dev/null || continue
        if [ "$(git -C "$source_depot" rev-parse "$commit:noyau" 2>/dev/null)" = "$arbre" ]; then
            date=""
        elif [ -z "$date" ]; then
            date=$(git -C "$source_depot" log -1 --format=%ct "$commit" 2>/dev/null)
        fi
    done
    if [ -n "$date" ]; then
        jours=$(( (maintenant - date) / 86400 ))
        [ "$jours" -gt "$seuil" ] || exit 0
        # La commande vise le dossier principal : posé dans un worktree, le noyau repartirait avec lui.
        source_abs=$(cd "$source_depot" 2>/dev/null && pwd -P) || source_abs=$source_depot
        echo "Le noyau de ce projet a $jours jours de retard. Mise à jour : bash $source_abs/installer.sh $principal"
        exit 0
    fi
    raison="sa version n'est pas sur la ligne principale du noyau"
fi

date=$(git -C "$cible" log -1 --format=%ct -- .noyau-empreintes 2>/dev/null)
[ -n "$date" ] || date=$(stat -c %Y "$empreintes" 2>/dev/null)
[ -n "$date" ] || exit 0
jours=$(( (maintenant - date) / 86400 ))
[ "$jours" -gt "$seuil" ] || exit 0
# UNE VERSION INCONNUE N'EST PAS UN DÉPÔT INJOIGNABLE. Le dépôt peut être là, sans repère à comparer.
[ -n "$pose" ] && [ "$pose" != inconnue ] || raison="sa version n'est pas connue"
echo "Le noyau de ce projet a été posé il y a $jours jours, et $raison. Regarder s'il a avancé."
exit 0
