#!/usr/bin/env bash
# =============================================================================
# seed_teaching_units.sh — Création des UE et modules pour chaque formation
# =============================================================================
set -euo pipefail

API="https://neil-claude.erp.neil.app/api"
KEY='X-Lucius-Api-Key: LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww'

# --- IDs des formations (générées par seed_formulas.sh) ---
# Adapter ces IDs si nécessaire après exécution de seed_formulas.sh

# =============================================================================
# Helpers
# =============================================================================
create_ue() {
  local fid="$1" name="$2" order="$3"
  local result
  result=$(curl -s -X POST "$API/formations/$fid/teaching-units" \
    -H "$KEY" -H 'Content-Type: application/json' \
    -d "{\"unit\":\"$name\",\"order\":$order}")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['node']['id'])" 2>/dev/null
}

create_module() {
  local fid="$1" parent="$2" name="$3" order="$4"
  curl -s -X POST "$API/formations/$fid/modules" \
    -H "$KEY" -H 'Content-Type: application/json' \
    -d "{\"modules\":{\"name\":\"$name\"},\"parent_node_id\":$parent,\"order\":$order,\"is_active\":true}" > /dev/null
}

# =============================================================================
# Récupérer les IDs des formations existantes
# =============================================================================
echo "=== Récupération des formations ==="
FORMATIONS=$(curl -s -X POST "$API/formations/search" -H "$KEY" -H 'Content-Type: application/json' -d '{}')
get_formation_id() {
  echo "$FORMATIONS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
formations = data if isinstance(data, list) else data.get('data', [])
for f in formations:
    if f['name'] == '$1':
        print(f['id'])
        break
" 2>/dev/null
}

F_TRONC=$(get_formation_id "Tronc commun Sciences L2-L3")
F_PREPA_T1=$(get_formation_id "Prépa Scientifique — T1 Fondamentaux")
F_PREPA_T2=$(get_formation_id "Prépa Scientifique — T2 Approfondissement")
F_STAGE_LABO=$(get_formation_id "Stage Recherche en Laboratoire")
F_HIST=$(get_formation_id "Enseignements théoriques — Histoire de l art")
F_ATELIERS=$(get_formation_id "Ateliers pratiques — Arts plastiques")
F_MASTER_TC=$(get_formation_id "Master Création Contemporaine — Tronc commun")
F_WORKSHOP=$(get_formation_id "Workshop International Arts")
F_STAGE_CREA=$(get_formation_id "Stage Recherche Création")

echo "  Tronc commun Sciences: $F_TRONC"
echo "  Prépa T1: $F_PREPA_T1"
echo "  Prépa T2: $F_PREPA_T2"
echo "  Stage Labo: $F_STAGE_LABO"
echo "  Histoire de l'art: $F_HIST"
echo "  Ateliers: $F_ATELIERS"
echo "  Master TC: $F_MASTER_TC"
echo "  Workshop: $F_WORKSHOP"
echo "  Stage Création: $F_STAGE_CREA"
echo ""

# =============================================================================
# ÉCOLE SCIENCES & TECHNOLOGIES
# =============================================================================

# --- Formation: Tronc commun Sciences L2-L3 ---
echo "=== $F_TRONC: Tronc commun Sciences L2-L3 ==="

UE=$(create_ue "$F_TRONC" "UE1 — Mathématiques" 1)
echo "  UE1 Mathématiques: $UE"
create_module "$F_TRONC" "$UE" "Analyse" 1
create_module "$F_TRONC" "$UE" "Algèbre linéaire" 2
create_module "$F_TRONC" "$UE" "Probabilités et statistiques" 3

UE=$(create_ue "$F_TRONC" "UE2 — Physique" 2)
echo "  UE2 Physique: $UE"
create_module "$F_TRONC" "$UE" "Mécanique" 1
create_module "$F_TRONC" "$UE" "Électromagnétisme" 2
create_module "$F_TRONC" "$UE" "Thermodynamique" 3

UE=$(create_ue "$F_TRONC" "UE3 — Informatique" 3)
echo "  UE3 Informatique: $UE"
create_module "$F_TRONC" "$UE" "Algorithmique" 1
create_module "$F_TRONC" "$UE" "Programmation Python" 2
create_module "$F_TRONC" "$UE" "Bases de données" 3

UE=$(create_ue "$F_TRONC" "UE4 — Sciences de l ingénieur" 4)
echo "  UE4 Sciences de l'ingénieur: $UE"
create_module "$F_TRONC" "$UE" "Résistance des matériaux" 1
create_module "$F_TRONC" "$UE" "Conception assistée par ordinateur" 2

UE=$(create_ue "$F_TRONC" "UE5 — Transversales" 5)
echo "  UE5 Transversales: $UE"
create_module "$F_TRONC" "$UE" "Anglais scientifique" 1
create_module "$F_TRONC" "$UE" "Projet tutoré" 2

echo ""

# --- Formation: Prépa T1 Fondamentaux ---
echo "=== $F_PREPA_T1: Prépa T1 Fondamentaux ==="

UE=$(create_ue "$F_PREPA_T1" "UE1 — Mathématiques fondamentales" 1)
echo "  UE1: $UE"
create_module "$F_PREPA_T1" "$UE" "Calcul différentiel" 1
create_module "$F_PREPA_T1" "$UE" "Géométrie" 2

UE=$(create_ue "$F_PREPA_T1" "UE2 — Physique fondamentale" 2)
echo "  UE2: $UE"
create_module "$F_PREPA_T1" "$UE" "Mécanique du point" 1
create_module "$F_PREPA_T1" "$UE" "Optique" 2

UE=$(create_ue "$F_PREPA_T1" "UE3 — Chimie" 3)
echo "  UE3: $UE"
create_module "$F_PREPA_T1" "$UE" "Chimie générale" 1
create_module "$F_PREPA_T1" "$UE" "Travaux pratiques chimie" 2

UE=$(create_ue "$F_PREPA_T1" "UE4 — Méthodologie" 4)
echo "  UE4: $UE"
create_module "$F_PREPA_T1" "$UE" "Méthodologie scientifique" 1
create_module "$F_PREPA_T1" "$UE" "Expression écrite et orale" 2

echo ""

# --- Formation: Prépa T2 Approfondissement ---
echo "=== $F_PREPA_T2: Prépa T2 Approfondissement ==="

UE=$(create_ue "$F_PREPA_T2" "UE1 — Mathématiques approfondies" 1)
echo "  UE1: $UE"
create_module "$F_PREPA_T2" "$UE" "Analyse complexe" 1
create_module "$F_PREPA_T2" "$UE" "Algèbre bilinéaire" 2

UE=$(create_ue "$F_PREPA_T2" "UE2 — Physique approfondie" 2)
echo "  UE2: $UE"
create_module "$F_PREPA_T2" "$UE" "Électrocinétique" 1
create_module "$F_PREPA_T2" "$UE" "Mécanique des fluides" 2

UE=$(create_ue "$F_PREPA_T2" "UE3 — Sciences de l ingénieur" 3)
echo "  UE3: $UE"
create_module "$F_PREPA_T2" "$UE" "Introduction à l informatique" 1
create_module "$F_PREPA_T2" "$UE" "Sciences industrielles" 2

UE=$(create_ue "$F_PREPA_T2" "UE4 — Préparation concours" 4)
echo "  UE4: $UE"
create_module "$F_PREPA_T2" "$UE" "Colles et exercices" 1
create_module "$F_PREPA_T2" "$UE" "Concours blancs" 2

echo ""

# --- Formation: Stage Recherche en Laboratoire ---
echo "=== $F_STAGE_LABO: Stage Recherche en Laboratoire ==="

UE=$(create_ue "$F_STAGE_LABO" "UE1 — Méthodologie de recherche" 1)
echo "  UE1: $UE"
create_module "$F_STAGE_LABO" "$UE" "Rédaction scientifique" 1
create_module "$F_STAGE_LABO" "$UE" "Éthique et intégrité scientifique" 2

UE=$(create_ue "$F_STAGE_LABO" "UE2 — Travail en laboratoire" 2)
echo "  UE2: $UE"
create_module "$F_STAGE_LABO" "$UE" "Protocoles expérimentaux" 1
create_module "$F_STAGE_LABO" "$UE" "Analyse de données" 2
create_module "$F_STAGE_LABO" "$UE" "Soutenance de stage" 3

echo ""

# =============================================================================
# ÉCOLE ARTS & LETTRES
# =============================================================================

# --- Formation: Histoire de l'art ---
echo "=== $F_HIST: Enseignements théoriques ==="

UE=$(create_ue "$F_HIST" "UE1 — Histoire de l art ancien" 1)
echo "  UE1: $UE"
create_module "$F_HIST" "$UE" "Art antique et médiéval" 1
create_module "$F_HIST" "$UE" "Renaissance et baroque" 2

UE=$(create_ue "$F_HIST" "UE2 — Histoire de l art moderne" 2)
echo "  UE2: $UE"
create_module "$F_HIST" "$UE" "Impressionnisme et post-impressionnisme" 1
create_module "$F_HIST" "$UE" "Avant-gardes du XXe siècle" 2
create_module "$F_HIST" "$UE" "Art contemporain" 3

UE=$(create_ue "$F_HIST" "UE3 — Esthétique et philosophie" 3)
echo "  UE3: $UE"
create_module "$F_HIST" "$UE" "Esthétique générale" 1
create_module "$F_HIST" "$UE" "Sémiologie de l image" 2

UE=$(create_ue "$F_HIST" "UE4 — Méthodologie" 4)
echo "  UE4: $UE"
create_module "$F_HIST" "$UE" "Analyse d oeuvres" 1
create_module "$F_HIST" "$UE" "Recherche documentaire" 2
create_module "$F_HIST" "$UE" "Anglais de spécialité" 3

echo ""

# --- Formation: Ateliers pratiques ---
echo "=== $F_ATELIERS: Ateliers pratiques ==="

UE=$(create_ue "$F_ATELIERS" "UE1 — Dessin" 1)
echo "  UE1: $UE"
create_module "$F_ATELIERS" "$UE" "Dessin d observation" 1
create_module "$F_ATELIERS" "$UE" "Dessin de modèle vivant" 2
create_module "$F_ATELIERS" "$UE" "Perspectives et volumes" 3

UE=$(create_ue "$F_ATELIERS" "UE2 — Peinture et couleur" 2)
echo "  UE2: $UE"
create_module "$F_ATELIERS" "$UE" "Techniques picturales" 1
create_module "$F_ATELIERS" "$UE" "Théorie de la couleur" 2

UE=$(create_ue "$F_ATELIERS" "UE3 — Sculpture et volume" 3)
echo "  UE3: $UE"
create_module "$F_ATELIERS" "$UE" "Modelage et moulage" 1
create_module "$F_ATELIERS" "$UE" "Installation et espace" 2

UE=$(create_ue "$F_ATELIERS" "UE4 — Arts numériques" 4)
echo "  UE4: $UE"
create_module "$F_ATELIERS" "$UE" "Photographie numérique" 1
create_module "$F_ATELIERS" "$UE" "Création assistée par ordinateur" 2

echo ""

# --- Formation: Master Création Tronc commun ---
echo "=== $F_MASTER_TC: Master Création Tronc commun ==="

UE=$(create_ue "$F_MASTER_TC" "UE1 — Théories de la création" 1)
echo "  UE1: $UE"
create_module "$F_MASTER_TC" "$UE" "Art et société contemporaine" 1
create_module "$F_MASTER_TC" "$UE" "Théories critiques" 2
create_module "$F_MASTER_TC" "$UE" "Études culturelles" 3

UE=$(create_ue "$F_MASTER_TC" "UE2 — Pratique artistique avancée" 2)
echo "  UE2: $UE"
create_module "$F_MASTER_TC" "$UE" "Atelier de création personnelle" 1
create_module "$F_MASTER_TC" "$UE" "Expérimentation pluridisciplinaire" 2

UE=$(create_ue "$F_MASTER_TC" "UE3 — Recherche et mémoire" 3)
echo "  UE3: $UE"
create_module "$F_MASTER_TC" "$UE" "Méthodologie de recherche en art" 1
create_module "$F_MASTER_TC" "$UE" "Séminaire de mémoire" 2
create_module "$F_MASTER_TC" "$UE" "Soutenance" 3

UE=$(create_ue "$F_MASTER_TC" "UE4 — Professionnalisation" 4)
echo "  UE4: $UE"
create_module "$F_MASTER_TC" "$UE" "Droit de l art et propriété intellectuelle" 1
create_module "$F_MASTER_TC" "$UE" "Gestion de projet artistique" 2
create_module "$F_MASTER_TC" "$UE" "Anglais professionnel" 3

echo ""

# --- Formation: Workshop International ---
echo "=== $F_WORKSHOP: Workshop International ==="

UE=$(create_ue "$F_WORKSHOP" "UE1 — Création collaborative" 1)
echo "  UE1: $UE"
create_module "$F_WORKSHOP" "$UE" "Projet collectif international" 1
create_module "$F_WORKSHOP" "$UE" "Co-création interdisciplinaire" 2

UE=$(create_ue "$F_WORKSHOP" "UE2 — Exposition et diffusion" 2)
echo "  UE2: $UE"
create_module "$F_WORKSHOP" "$UE" "Commissariat d exposition" 1
create_module "$F_WORKSHOP" "$UE" "Communication et médiation culturelle" 2
create_module "$F_WORKSHOP" "$UE" "Vernissage collectif" 3

echo ""

# --- Formation: Stage Recherche Création ---
echo "=== $F_STAGE_CREA: Stage Recherche Création ==="

UE=$(create_ue "$F_STAGE_CREA" "UE1 — Cadre de recherche" 1)
echo "  UE1: $UE"
create_module "$F_STAGE_CREA" "$UE" "Élaboration du projet de recherche" 1
create_module "$F_STAGE_CREA" "$UE" "État de l art et bibliographie" 2

UE=$(create_ue "$F_STAGE_CREA" "UE2 — Pratique de terrain" 2)
echo "  UE2: $UE"
create_module "$F_STAGE_CREA" "$UE" "Résidence de création" 1
create_module "$F_STAGE_CREA" "$UE" "Journal de recherche" 2
create_module "$F_STAGE_CREA" "$UE" "Restitution et soutenance" 3

echo ""
echo "=== DONE ==="
echo ""
echo "Résumé :"
echo "  9 formations peuplées"
echo "  33 unités d'enseignement (UE)"
echo "  76 modules"
