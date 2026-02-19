# Neil ERP — Seed Scripts

## Projet

Scripts de seed pour l'instance de démo Neil ERP. L'objectif est de remplir l'ERP avec des données réalistes et cohérentes.

## API

- **URL** : `https://neil-claude.erp.neil.app/api/`
- **Auth** : Header `X-Lucius-Api-Key: LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww`
- **Swagger** : `GET /swagger.json` (incomplet, beaucoup de champs non documentés)

## Quirks de l'API (non documentés)

- `FormationCreate` requiert `is_active: true` et `tags: []` (sinon 500)
- `FormulaCreate` requiert `company_id` (absent du swagger)
- Unités d'enseignement : le champ est `unit` et non `name`
- Module creation : `POST` retourne un array, `default_duration` se set via `PATCH` séparé
- Partage de formation inter-écoles bloqué (`protected_resource`)
- Prix en **centimes** (850000 = 8500.00 EUR), durées en **secondes** (3600 = 1h)
- Étapes d'inscription : `PATCH /formulas/{id}/steps` avec body `{"steps": [...]}`
- Dernière étape ne peut pas avoir d'avance (advance)
- Échéanciers utilisent les step IDs comme clés
- Remises : utiliser le type `fixed` avec montant en centimes (pas `variable`)
- Inscription étudiant : `POST /students/{id}/formulas` avec `{"formulas": {"formula_id": N}}`
- Avancement d'étape : `PATCH /students/{id}/formulas/{sf_id}` avec `{"step": {"formula_step_id": N}}`
- Ajout de réduction : même PATCH avec `{"discounts": [{"formula_discount_id": N}]}`
- Suppression module : `DELETE /formations/{fid}/modules/{module_id}` (module_id de l'array modules, pas node_id)
- Suppression UE : `DELETE /formations/{fid}/teaching-units/{node_id}` (échoue si enfants existent)
- Sous-UE : même endpoint que UE mais avec `parent_node_id`
- Création groupe : `POST /formations/{fid}/groups` avec `{"groups": {"name", "group_set_id", "color", "capacity"}}` (retourne array)
- Création ensemble : `POST /formations/{fid}/group-sets` avec `{"name": "..."}`
- Affectation étudiants : `POST /formations/{fid}/groups/{gid}/students` avec `{"students": [{"student_id": N}]}`
- Chaque formation a un ensemble par défaut "Ensemble de classes par défaut" (renommable via PATCH)

## Données actuelles sur l'ERP

### Écoles et campus
- Sciences & Technologies (school=2) : Campus Saclay (faculty=3), Campus Lyon (faculty=4)
- Arts & Lettres (school=3) : Campus Bordeaux (faculty=5), Campus Marseille (faculty=6)

### Centres et salles
- 4 centres (IDs 4-7) avec horaires, 18 salles (IDs 3-20)

### Sociétés
- SAS ÉduSciences (company=1), SARL ArtsCréa (company=2)

### Niveaux
- Prépa (21), L1 (22), L2 (23), L3 (24), M1 (25), M2 (26)

### Formations (IDs 10-18)
| ID | Nom | Heures | École |
|----|-----|--------|-------|
| 10 | Tronc commun Sciences L2-L3 | 1200h | S&T |
| 11 | Prépa T1 Fondamentaux | 200h | S&T |
| 12 | Prépa T2 Approfondissement | 200h | S&T |
| 13 | Stage Recherche Labo | 140h | S&T |
| 14 | Histoire de l'art | 400h | A&L |
| 15 | Ateliers pratiques | 300h | A&L |
| 16 | Master Création TC | 400h | A&L |
| 17 | Workshop International | 100h | A&L |
| 18 | Stage Recherche Création | 140h | A&L |

### Formules (IDs 2-6)
| ID | Nom | École | Steps |
|----|-----|-------|-------|
| 2 | Licence Sciences L2-L3 | S&T | 12→13→14 |
| 3 | Prépa Scientifique | S&T | 15→16→17 |
| 4 | Stage Recherche Labo | S&T | 18→19→20 |
| 5 | Licence Arts Plastiques | A&L | 21→22→23 |
| 6 | Master Création | A&L | 24→25→26→27 |

### Réductions par formule
- FM2 : Bourse mérite (2), Paiement comptant (3), Fratrie (4)
- FM3 : Paiement anticipé (5), Bourse excellence (6)
- FM4 : Étudiant établissement (7)
- FM5 : Bourse talent (8), Paiement comptant (9), Fratrie (10)
- FM6 : Bourse recherche (11), Ancien étudiant (12), Paiement comptant (13)

### Étudiants
- 200 au total : 100 S&T, 80 A&L, 20 double cursus
- 220 inscriptions aux formules (65% définitifs, ~30% avec réduction)

### Structure pédagogique
- 31 UEs, 65 sous-UEs, 1042 modules (cours de 1h, 2h ou 4h)
- Total = durée de chaque formation

### Classes et groupes (16 ensembles, 38 classes)
Affectation basée sur les sets des formules (obligatoire vs optionnel).
FM6 Set Options (min:1, max:2) : ~60% prennent F17+F18, ~40% une seule option.

| Formation | Ensembles | Classes |
|-----------|-----------|---------|
| F10 (43 étu.) | Classes (GS10), Groupes de TD (GS27), Groupes de TP (GS28) | Classe A (40), Classe B (41), TD 1-3 (42-44), TP 1-4 (45-48) |
| F11 (25 étu.) | Classe (GS11), Groupes de TD (GS29) | Prépa T1 (49), TD 1-2 (50-51) |
| F12 (25 étu.) | Classe (GS12), Groupes de TD (GS30) | Prépa T2 (52), TD 1-2 (53-54) |
| F13 (10 étu.) | Groupes de laboratoire (GS13) | Labo Physique (55), Labo Chimie (56) |
| F14 (41 étu.) | Classes (GS14), Groupes de TD (GS31) | Classe A (57), Classe B (58), TD 1-3 (59-61) |
| F15 (41 étu.) | Ateliers (GS15), Groupes de TP (GS32) | Atelier Dessin-Peinture (62), Sculpture-Volume (63), Arts numériques (64), TP 1-4 (65-68) |
| F16 (28 étu.) | Promotion (GS16), Ateliers de création (GS33) | Master 1 Création (69), Arts visuels (70), Arts vivants (71) |
| F17 (22 étu.) | Groupes de projet (GS17) | Projet Installation (72), Performance (73), Numérique (74) |
| F18 (22 étu.) | Groupes de recherche (GS18) | Recherche Matériaux (75), Image (76), Son-Espace (77) |

## Conventions

- **Langue** : noms et données en français
- **Pas de confirmation** : exécuter directement sans demander
- **Update plutôt que delete/create** : utiliser PATCH quand possible
- **Modules** : nommer avec Cours, TP, TD, Atelier, Projet (jamais "Séance")
- **Scripts Python** pour les opérations complexes (meilleure gestion erreurs, JSON natif)
- **Scripts Bash** pour les opérations simples (curl direct)
- **Toujours push sur le repo** après modification des scripts

## Ordre d'exécution

```bash
bash seed_neil.sh              # 1. Infrastructure
bash seed_formulas.sh          # 2. Formations et formules
python3 seed_teaching_units.py # 3. UE et modules
python3 seed_students.py       # 4. Étudiants
python3 seed_enrollments.py    # 5. Inscriptions
python3 seed_groups.py         # 6. Classes et groupes
```
