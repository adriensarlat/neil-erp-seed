# Neil ERP — Scripts de Seed

Scripts de génération de données de démonstration pour l'ERP Neil.

## Contenu

| Script | Description |
|--------|-------------|
| `seed_neil.sh` | Création des écoles, campus, centres d'activité, salles, sociétés, niveaux et liaisons |
| `seed_formulas.sh` | Création des formations et formules avec sets, étapes, échéanciers, remises |
| `seed_teaching_units.py` | Création des UE, sous-UE et modules (cours 1h/2h/4h) dans chaque formation |
| `seed_students.py` | Génération de 200 étudiants avec données complètes et photos de profil |
| `seed_enrollments.py` | Inscription des étudiants aux formules avec répartition par étapes et réductions |

## Données générées

- **2 écoles** : Sciences & Technologies, Arts & Lettres
- **4 campus** : Paris-Saclay, Lyon-Part-Dieu, Bordeaux-Chartrons, Marseille-Vieux-Port
- **4 centres d'activité** : avec horaires d'ouverture et 18 salles (dont un amphi 120 places)
- **2 sociétés** : SAS ÉduSciences (1 établissement), SARL ArtsCréa (2 établissements)
- **6 niveaux** : Prépa, L1, L2, L3, M1, M2
- **9 formations** : tronc commun, trimestres, stages, ateliers, workshops
- **5 formules** : avec 8 sets liant formules et formations
- **31 UE, 65 sous-UE et 1042 modules** : structure pédagogique complète (chaque module = cours de 1h, 2h ou 4h, total = durée de la formation)
- **200 étudiants** : avec noms, emails, dates de naissance, adresses, n° sécu, photos de profil, répartis sur les deux écoles (dont 20 en double cursus)
- **220 inscriptions** : 65% inscrits définitivement, reste réparti sur les étapes intermédiaires, 30% avec réduction

### Formules & Formations

| Formule | École | Sets | Cas couvert |
|---------|-------|------|-------------|
| Licence Sciences L2-L3 | S&T | 1 set (tronc commun) | Formation sur 2 ans |
| Prépa Scientifique Intensive | S&T | 2 sets (T1 + T2) | Formule divisée en 2 trimestres |
| Stage Recherche en Laboratoire | S&T | 1 set (stage) | Stage commercialisé (`is_salable`) |
| Licence Arts Plastiques | A&L | 2 sets (théorie + pratique) | Cursus classique |
| Master Création Contemporaine | A&L | 2 sets (tronc commun + options) | Stage en option (min:1, max:2) |

## Prérequis

```bash
# Pour le script Python
pip3 install requests
```

## Utilisation

```bash
# 1. Écoles, campus, centres, salles, sociétés, niveaux
bash seed_neil.sh

# 2. Formations et formules
bash seed_formulas.sh

# 3. Unités d'enseignement, sous-UE et modules
python3 seed_teaching_units.py

# 4. Étudiants
python3 seed_students.py

# 5. Inscriptions aux formules
python3 seed_enrollments.py
```

## Configuration

Les scripts utilisent :
- **API** : `https://neil-claude.erp.neil.app/api/`
- **Auth** : Header `X-Lucius-Api-Key`

Modifiez les constantes `API_BASE` et `API_KEY` dans chaque script pour pointer vers votre instance.
