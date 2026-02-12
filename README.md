# Neil ERP — Scripts de Seed

Scripts de génération de données de démonstration pour l'ERP Neil.

## Contenu

| Script | Description |
|--------|-------------|
| `seed_neil.sh` | Création des écoles, campus, centres d'activité, salles, sociétés, niveaux et liaisons |
| `seed_students.py` | Génération de 200 étudiants avec données complètes et photos de profil |

## Données générées

- **2 écoles** : Sciences & Technologies, Arts & Lettres
- **4 campus** : Paris-Saclay, Lyon-Part-Dieu, Bordeaux-Chartrons, Marseille-Vieux-Port
- **4 centres d'activité** : avec horaires d'ouverture et 18 salles (dont un amphi 120 places)
- **2 sociétés** : SAS ÉduSciences (1 établissement), SARL ArtsCréa (2 établissements)
- **19 niveaux** : Prépa → M2 pour chaque filière
- **200 étudiants** : avec noms, emails, dates de naissance, adresses, n° sécu, photos de profil, répartis sur les deux écoles (dont 20 en double cursus)

## Prérequis

```bash
# Pour le script Python
pip3 install requests
```

## Utilisation

```bash
# 1. Écoles, campus, centres, salles, sociétés, niveaux
bash seed_neil.sh

# 2. Étudiants
python3 seed_students.py
```

## Configuration

Les scripts utilisent :
- **API** : `https://neil-claude.erp.neil.app/api/`
- **Auth** : Header `X-Lucius-Api-Key`

Modifiez les constantes `API_BASE` et `API_KEY` dans chaque script pour pointer vers votre instance.
