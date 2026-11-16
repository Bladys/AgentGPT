# Intégration du pack art / animation v3

Le jeu ne référence que des **ID stables** (`data/asset_manifest.json`).
Chaque ID a aujourd'hui `status: "pending_pack"` et un repli procédural.

## Étapes

1. Copier le pack à la racine du projet en respectant ces chemins :
   - `assets/animations/<brindille|braise|nacre>/<idle|blink|react|cast|celebrate|sleep>.tres`
   - `assets/animations/vfx/<connect|bridge|melt|freeze|hatch|restore>.tres`
   - `ANIMATION_MANIFEST.json` à la racine (prime sur `data/animation_manifest.json`)
   - `assets/audio/{music,ambience}/*.ogg`, `assets/audio/{sfx,ui}/*.wav`
   - `assets/backgrounds/island_N.png`, `assets/props/set_N.png`
2. Passer les entrées livrées à `"status": "present"` : les tests échouent
   alors si un fichier manque.
3. Réconcilier `assets/vfx/effects.json` avec `VFX_AUDIO.md` et
   `data/progression.json` avec la fiche de progression.
4. Brancher `bg_island_N` / `prop_set_N` dans l'écran de puzzle et le jardin
   (non câblé : il n'y avait aucune image à afficher).

## Contrat déjà respecté par le code

- `DragonAnimator` : AnimatedSprite2D, pivot (128,226) par décalage fixe,
  aucune frame rognée, filtrage linéaire, `speed_scale = 1`, un seul compagnon
  chargé par écran, fondu de 180 ms à l'interruption, jeton d'action qui
  annule les callbacks précédents, `sleep` réservé à l'habitat.
- `power_release` (0,54 s) et `celebrate_peak` (0,49 s) sont lus dans le
  manifeste ; mesuré en test : 0,54–0,55 s, déclenchement unique.
- `VFXService` : 6 émetteurs préchargés, plafond global de 160 particules,
  2 gros effets simultanés au plus, rien en mode mouvements réduits.

## À vérifier une fois le pack en place

Clignement et sommeil à taille réelle, lisibilité des ailes, transitions,
mémoire et temps de rendu sur le téléphone cible. Les animations du pack sont
des déformations 2D de peintures, pas un rig : toute expression nouvelle est
une tâche de finition à planifier.
