# Contrôles LOCAUX de ce projet. Sourcé par scripts/doc-lint.sh, qui fournit déjà section(),
# check() et garde_plante().
#
# Les numéros portent le préfixe L, pour qu'aucun contrôle du noyau ne puisse entrer en
# collision avec l'un d'eux. Le noyau garde 1, 2, 3. Ce fichier prend L1, L2, L3.
#
# Ce qui a sa place ICI plutôt que dans le noyau : tout ce qui dépend du produit, d'un site
# externe, d'une machine, ou d'un vocabulaire propre au projet.
#
# Exemple, à décommenter et à adapter.
#
# section "L1. Ce que ce contrôle garantit"
# out=$(grep -rn 'motif-interdit' $DOCS || true)
# check "aucun motif interdit" "$out"
