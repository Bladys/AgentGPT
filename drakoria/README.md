# Drakoria — Gardens of Dragons *(titre provisoire)*

**Trace la vie. Réveille les dragons.**

Jeu mobile de puzzle 2D, portrait, solo, hors ligne, en français ou en anglais
selon la langue du système. Projet Godot **4.7.2** (version vérifiée sur le
binaire installé : `4.7.2.stable.official`), GDScript uniquement.

> **État : prototype jouable de la tranche de 50 niveaux (île 1).**
> Les visuels et les sons sont **provisoires** (dessin procédural, tonalités
> synthétisées) : le pack art/animation v3 n'était pas dans le dépôt au moment
> de l'implémentation. Tous les points d'intégration sont prêts
> (voir [docs/ASSET_INTEGRATION.md](docs/ASSET_INTEGRATION.md)).
> Ce dépôt ne contient **pas** 300 niveaux : 50 grilles sont validées par le
> solveur, les îles 2 à 6 sont affichées « en préparation ».

## Lancer

```bash
godot --path . --import          # première fois : cache des classes
godot --path .                   # jouer (souris = doigt)
```

## Tests

```bash
DRAKORIA_SAVE_ROOT=user://test_tmp/ godot --headless --path . res://tests/test_runner.tscn
```

1 478 vérifications, 0 échec au dernier passage — détail et limites dans
[docs/TEST_REPORT.md](docs/TEST_REPORT.md).

## Architecture

| Rôle | Fichier |
|---|---|
| PuzzleModel (état, gestes, annulation, persistance, invariants) | `src/core/puzzle_model.gd` |
| RuleResolver (activateurs, objectifs) | `src/core/rule_resolver.gd` |
| Solver (dépendances, solutions, difficulté mesurée, indices) | `src/core/solver.gd` |
| LevelLoader (schéma `drakoria.level/1`) | `src/core/level_loader.gd` |
| GestureController / BoardView | `src/game/` |
| ProgressionService, SaveService + SaveStore (atomique, versionné) | `src/services/` |
| AudioService (Master ← Music, Ambience, SFX, UI), VFXService | `src/services/` |
| DragonAnimator, AnimationEventRouter, AnimContract | `src/anim/` |
| AdsService, PurchaseService, AnalyticsService (factices), InterstitialPolicy | `src/commerce/` |
| Écrans : accueil, carte, puzzle, réussite, restauration, collection, boutique, paramètres | `src/ui/` |
| Générateur de candidats + grilles faites main | `tools/build_levels.gd` |

Principes tenus par le code et vérifiés par les tests :

- Le **modèle décide**, les vues rejouent ses événements. Aucune règle, victoire
  ou récompense n'est résolue depuis un callback d'animation.
- Les interactions ne sont résolues qu'**après validation** d'un canal ; le
  terrain transformé persiste si le canal est effacé ; un activateur ne se
  déclenche qu'une fois ; annuler restaure terrain, activateurs et compteurs.
- Les trois pouvoirs ne font que rendre une case praticable : un pouvoir ne
  peut donc jamais rendre un niveau insoluble.
- La graine de première réussite est accordée une seule fois ; toute
  récompense passe par un identifiant de transaction dédupliqué.

### Choix de règles à connaître

- Toucher un canal validé le **reprend** : si le doigt est relâché hors
  destination, ce canal est retiré (un geste, annulable). C'est aussi la
  façon de retirer un canal.
- L'auto-intersection est **refusée** (le tracé ne se coupe pas lui-même).
- L'indice révèle un segment de plus à chaque appui pour la paire indiquée.

## Niveaux

`data/levels/level_001…050.json` — chaque fichier contient dimensions, paires
(énergie, motif, numéro), obstacles, terrain, activateurs (paire, autel, cible,
état avant/après), objectifs, compagnon requis, solution de référence ordonnée,
résultats du solveur et version.

- 10 grilles **faites à la main** : 1, 2, 3, 4, 5, 10, 11 (pont), 21 (fonte),
  31 (gel), 41 (deux pouvoirs enchaînés).
- 40 grilles sont des **candidats aléatoires retenus par le solveur**
  (`origin: generated_candidate`). Aucune n'a été jouée par un humain
  (`human_playtested: false`).
- Aucune grille n'est la symétrie d'une autre (forme canonique sous les 8
  symétries du carré, vérifiée).
- La difficulté est **mesurée**, pas déclarée : `greedy_success_ratio` (part
  des ordres de paires où « toujours le plus court chemin » réussit) et nombre
  de solutions tendues. Répartition : 19 faciles, 22 moyennes, 9 difficiles.
  Ces mesures ne disent rien de l'intérêt ressenti : seul un test humain le dira.

Régénérer : `godot --headless --path . -s tools/build_levels.gd -- 1 50`
(≈ 3 min, déterministe).

`data/progression.json` est **provisoire** (Brindille après le niveau 10,
Braise après 20, Nacre après 30) : la fiche de progression du dossier de
production fait autorité et doit le remplacer.

## Économie (prototype)

Aucun SDK, aucune publicité réelle, aucune collecte réseau, aucun paiement.
Les achats simulés portent l'étiquette « Démonstration — aucun paiement ».
Hypothèses codées dans `InterstitialPolicy` (à tester, pas des promesses) :
pas d'interstitiel avant le niveau 15, un au plus après quatre réussites,
180 s minimum, jamais après une récompensée ni si l'achat « sans interstitiels »
est possédé. Dans ce prototype la décision est seulement journalisée.
Les prix (3,99 € ; 1,99–2,99 €) sont des hypothèses de test.

Aucune rentabilité n'est affirmée. Avant toute acquisition payante, définir
les seuils (rétention J1/J7, coût d'acquisition, marge nette après frais de
magasin, remboursements et production) et le budget d'essai.

## Export Android de test

**Non produit ici** : l'environnement de build bloque `dl.google.com`
(SDK Android). Sur un poste équipé :

1. Godot 4.7.2 + modèles d'export 4.7.2 (*Éditeur → Gérer les modèles d'export*).
2. JDK 17 et SDK Android (platform-tools, build-tools) ; chemins dans
   *Paramètres de l'éditeur → Export → Android* ; keystore de débogage.
3. `godot --headless --path . --export-debug "Android (test)" build/drakoria-test.apk`

Le préréglage `export_presets.cfg` est fourni mais **n'a pas été exécuté**.
L'identifiant de paquet est un placeholder.

## Limites restantes

- Pack art/animation v3 non intégré : dragons, VFX, fonds, musique sont des
  substituts. Les 24 clips / 804 images n'ont pas été vérifiés dans ce projet.
- Aucune mesure sur téléphone : fréquence d'images, mémoire, lisibilité réelle,
  son au casque/haut-parleur, test tactile humain — tout reste à faire.
- 40 niveaux sur 50 sont générés et non joués par un humain.
- Musique et ambiances silencieuses tant que les fichiers manquent.
- Marges d'encoche codées mais non testées sur appareil.
- Disponibilité du titre commercial non vérifiée. Rien n'a été publié ni acheté.
