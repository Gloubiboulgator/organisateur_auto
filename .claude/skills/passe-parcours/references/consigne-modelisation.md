# La consigne de la modélisation

Ce fichier est la consigne du sous-agent de la phase 1. La session la lui passe tout entière,
en ajoutant seulement le dossier du projet. Le sous-agent est un Opus, effort `medium`.

La consigne commence sous le trait.

---

Tu modélises le parcours utilisateur complet de l'app de ce projet, tel qu'il est aujourd'hui.
Ton rendu sert deux fois. L'admin le valide d'abord. Puis une synthèse pose dessus le chemin de
testeurs qui découvrent l'app.

## Ce que tu lis

- Les specs et la roadmap, pour le parcours voulu.
- Le code des écrans, pour le parcours réel. **Le code fait foi.** Un écran spécifié mais
  jamais atteint par un geste n'entre pas au parcours. Il va dans les écarts.
- Les captures existantes, s'il y en a.

## Ce que tu modélises

Tout ce qu'un utilisateur peut traverser, sans rien résumer.

- **Chaque écran**, y compris les fenêtres, les panneaux dépliés et les messages qui bloquent.
- **Chaque geste qui en sort**, avec son libellé exact tel qu'il s'affiche.
- **Chaque branche.** Premier lancement et retour d'un habitué. Erreur réseau, liste vide,
  fin de partie, réglages, partage, liens qui sortent de l'app.
- **Les culs-de-sac**, un écran dont aucun geste ne ramène ailleurs que par le retour système.

## Ce que tu rends

Un seul bloc JSON, dans cette forme exacte.

```json
{
  "sections": [{"id": "S1", "titre": "Premier lancement"}],
  "ecrans": [{"id": "E1", "section": "S1", "titre": "Accueil",
              "ce_qu_on_y_voit": "Une phrase.", "source": "chemin/du/fichier:ligne"}],
  "transitions": [{"de": "E1", "vers": "E2", "geste": "Toucher « Jouer »",
                   "condition": "Première partie seulement, ou vide"}],
  "ecarts": [{"sorte": "promis-non-atteint", "texte": "Une phrase, avec la spec citée."}],
  "version_modelisee": {"commit": "abc1234", "raison": "Une phrase : pourquoi ce commit."}
}
```

**Chaque écart porte sa sorte**, l'une de ces quatre, et rien d'autre.

- `promis-non-atteint`. La spec promet un écran ou un geste, et aucun geste réel n'y mène.
- `specs-contradictoires`. Deux specs disent deux choses, et le texte dit laquelle le code suit.
- `hors-spec`. Le code fait une chose qu'aucune spec ne tranche, un cul-de-sac compris.
- `version-testee`. La version testée diffère du code actuel. Ne s'emploie que si la session
  te nomme une version testée.

Un doute sur ta propre lecture n'est pas un écart. Il va dans ta réponse finale.

**La version modélisée** est le commit dont tu as lu le code. La page l'affiche en tête, et
l'admin valide en connaissant la version.

Aucun logigramme à écrire. Le script de rendu le dessine depuis les écrans et les transitions.

**Aucune taille maximale.** Un parcours de soixante écrans en compte soixante. Un parcours
résumé cache précisément l'écran où un testeur se perdra.
