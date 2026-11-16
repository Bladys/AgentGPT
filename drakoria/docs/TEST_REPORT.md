# Rapport de tests

Moteur : Godot 4.7.2.stable.official (Linux, headless). Dernier passage :
**1 478 vérifications réussies, 0 échec**.

Commande : `DRAKORIA_SAVE_ROOT=user://test_tmp/ godot --headless --path . res://tests/test_runner.tscn`

## Ce qui est vérifié

| Domaine | Résultat |
|---|---|
| 50 grilles : schéma, solveur indépendant, solution de référence rejouée geste par geste jusqu'à la victoire | 50 / 50 |
| Chaque activateur est nécessaire (grille insoluble sans lui, preuve exhaustive) | oui |
| Aucun niveau n'exige un compagnon encore verrouillé ; aucun compagnon payant | oui |
| Aucune grille symétrique d'une autre | oui |
| Règles : diagonale, croisement, auto-intersection, destination terminale, refus sans effet, persistance du terrain, activation unique | oui |
| Annulation : 1 000 séquences aléatoires, 14 160 gestes, 258 activations en fin de séquence ; chaque annulation retrouve l'état exact précédent, annuler jusqu'au bout = état initial | 0 écart |
| Fermeture / réouverture : 300 états (dont fermeture en plein tracé) rechargés à l'identique ; 8 sauvegardes altérées rejetées vers un plateau initial sain | 0 état impossible |
| Stockage atomique : repli sur la copie de secours, fichier temporaire orphelin ignoré, migration v1→v2, version future refusée | oui |
| Indices : suivre les indices résout les 50 niveaux depuis un état gêné ; pire calcul 3 ms sur ce poste | 50 / 50 |
| Progression : graine unique, transactions dédupliquées, déblocages, île 2 après le niveau 50 | oui |
| Publicité factice : règles d'interstitiel, aucune récompense si la vidéo échoue | oui |
| Achats factices : rien d'enregistré sans confirmation, revenu 0, pas de double achat | oui |
| Textes : 144 clés FR = 144 clés EN, toutes les clés utilisées existent | oui |
| Animation : `power_release` mesuré à 0,54–0,55 s, VFX unique, annulation sans callback tardif, mouvements réduits sans particule, plafonds respectés | oui |
| Audio : bus vers Master, sons de tracé limités, suspension pub/arrière-plan puis préférences restaurées | oui |
| Interface : 8 écrans en FR et EN, boutons ≥ 48 unités, partie complète pilotée par l'écran de puzzle | oui |
| Case 8×8 sur 360×640 : 43 unités (minimum demandé 36) | oui |

Rendu réel contrôlé par captures (xvfb, OpenGL logiciel) en 540×960 et 360×640,
français et anglais, taille de texte normale et très grande.

## Ce qui n'est PAS vérifié

- Aucun essai sur téléphone : 60 images/s, mode réduit, mémoire, encoches,
  précision tactile réelle, vibrations.
- Aucune écoute : les sons sont des tonalités de maquette, il n'y a pas de musique.
- Aucun test humain des niveaux : durée de 1 à 3 minutes, intérêt et
  progression ressentie restent des hypothèses.
- Export Android non exécuté (SDK inaccessible depuis l'environnement de build).
- Pack d'animation v3 absent : le contrat est testé avec le substitut dessiné,
  pas avec les 24 clips livrés.
- Les tests d'arrière-plan simulent la suspension ; les notifications système
  Android réelles ne sont pas exercées.

## Grilles

| N° | Taille | Paires | Rôle | Origine | Compagnons | Glouton | Sol. tendues | Difficulté mesurée |
|---|---|---|---|---|---|---|---|---|
| 1 | 4×4 | 2 | learning | main | — | 1.0 | 12+ | easy |
| 2 | 4×4 | 2 | learning | main | — | 1.0 | 4 | easy |
| 3 | 5×5 | 3 | learning | main | — | 1.0 | 4 | easy |
| 4 | 5×5 | 3 | variation | main | — | 1.0 | 12+ | easy |
| 5 | 5×5 | 3 | variation | main | — | 1.0 | 1 | easy |
| 6 | 5×5 | 3 | consolidation | candidat | — | 0.333 | 8 | medium |
| 7 | 5×5 | 3 | consolidation | candidat | — | 0.5 | 1 | medium |
| 8 | 4×4 | 2 | breather | candidat | — | 0.5 | 1 | medium |
| 9 | 5×5 | 3 | challenge | candidat | — | 0.167 | 2 | hard |
| 10 | 5×5 | 4 | challenge | main | — | 1.0 | 6 | easy |
| 11 | 5×5 | 2 | learning | main | brindille | 1.0 | 1 | easy |
| 12 | 5×5 | 2 | learning | candidat | brindille | 0.5 | 1 | medium |
| 13 | 5×5 | 2 | learning | candidat | brindille | 0.5 | 1 | medium |
| 14 | 5×5 | 2 | variation | candidat | brindille | 0.5 | 3 | medium |
| 15 | 5×5 | 2 | variation | candidat | brindille | 0.5 | 6 | medium |
| 16 | 6×6 | 4 | consolidation | candidat | brindille | 0.333 | 3 | medium |
| 17 | 6×6 | 4 | consolidation | candidat | brindille | 0.333 | 6 | medium |
| 18 | 5×5 | 2 | breather | candidat | — | 0.5 | 12+ | medium |
| 19 | 6×6 | 4 | challenge | candidat | brindille | 0.167 | 7 | hard |
| 20 | 6×6 | 4 | challenge | candidat | brindille | 0.083 | 6 | hard |
| 21 | 6×6 | 3 | learning | main | braise | 1.0 | 4 | easy |
| 22 | 6×6 | 4 | learning | candidat | braise | 0.667 | 12+ | easy |
| 23 | 6×6 | 4 | learning | candidat | braise | 0.667 | 2 | easy |
| 24 | 6×6 | 4 | variation | candidat | brindille | 0.5 | 4 | medium |
| 25 | 6×6 | 4 | variation | candidat | braise | 0.5 | 2 | medium |
| 26 | 6×6 | 5 | consolidation | candidat | braise | 0.333 | 7 | medium |
| 27 | 6×6 | 5 | consolidation | candidat | braise | 0.333 | 2 | medium |
| 28 | 6×6 | 4 | breather | candidat | — | 0.667 | 12+ | easy |
| 29 | 6×6 | 5 | challenge | candidat | braise | 0.125 | 1 | hard |
| 30 | 6×6 | 5 | challenge | candidat | brindille | 0.125 | 4 | hard |
| 31 | 6×6 | 3 | learning | main | nacre | 1.0 | 4 | easy |
| 32 | 6×6 | 4 | learning | candidat | nacre | 0.667 | 1 | easy |
| 33 | 6×6 | 4 | learning | candidat | nacre | 0.667 | 12+ | easy |
| 34 | 6×6 | 4 | variation | candidat | nacre | 0.5 | 4 | medium |
| 35 | 6×6 | 4 | variation | candidat | nacre | 0.5 | 1 | medium |
| 36 | 7×7 | 5 | consolidation | candidat | brindille | 0.375 | 4 | medium |
| 37 | 7×7 | 5 | consolidation | candidat | nacre | 0.333 | 8 | medium |
| 38 | 6×6 | 4 | breather | candidat | — | 0.667 | 12+ | easy |
| 39 | 7×7 | 5 | challenge | candidat | braise | 0.083 | 4 | hard |
| 40 | 7×7 | 5 | challenge | candidat | nacre | 0.15 | 12+ | hard |
| 41 | 7×7 | 4 | learning | main | brindille,braise | 1.0 | 2 | easy |
| 42 | 7×7 | 5 | learning | candidat | nacre | 0.75 | 12+ | easy |
| 43 | 7×7 | 5 | learning | candidat | nacre | 0.833 | 12+ | easy |
| 44 | 7×7 | 5 | variation | candidat | nacre | 0.5 | 2 | medium |
| 45 | 7×7 | 5 | variation | candidat | brindille | 0.5 | 4 | medium |
| 46 | 8×8 | 5 | consolidation | candidat | nacre,brindille | 0.333 | 12+ | medium |
| 47 | 8×8 | 5 | consolidation | candidat | nacre,brindille | 0.333 | 12+ | medium |
| 48 | 7×7 | 5 | breather | candidat | — | 0.667 | 12+ | easy |
| 49 | 8×8 | 5 | challenge | candidat | nacre,brindille | 0.167 | 2 | hard |
| 50 | 8×8 | 5 | challenge | candidat | nacre,brindille,braise | 0.125 | 12+ | hard |

« Glouton » : part des ordres de paires où le plus court chemin résout la grille (1.0 = trivial). « Sol. tendues » : solutions sans détour, comptées jusqu'à 12.
