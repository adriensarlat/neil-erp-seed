#!/usr/bin/env bash
# =============================================================================
# seed_formulas.sh — Création des formations et formules pour Neil ERP
# =============================================================================
set -euo pipefail

API="https://neil-claude.erp.neil.app/api"
KEY='X-Lucius-Api-Key: LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww'

# --- IDs existants ---
# Écoles: Sciences & Technologies (2), Arts & Lettres (3)
# Campus: Paris-Saclay (3), Lyon (4), Bordeaux (5), Marseille (6)
# Sociétés: SAS ÉduSciences (1), SARL ArtsCréa (2)
# Niveaux: Prépa (21), L1 (22), L2 (23), L3 (24), M1 (25), M2 (26)

# =============================================================================
# Helpers
# =============================================================================
create_formation() {
  local name="$1" faculties="$2" levels="$3" yf="$4" yt="$5" af="$6" at="$7" dur="$8" cap="$9"
  local result id
  result=$(curl -s -X POST "$API/formations" \
    -H "$KEY" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"is_active\":true,\"faculties\":$faculties,\"levels\":$levels,\"year_from\":$yf,\"year_to\":$yt,\"mod_setup\":\"teaching_units\",\"sequence_managers\":[\"modules\"],\"accessible_from\":\"${af}T00:00:00.000Z\",\"accessible_to\":\"${at}T23:59:59.000Z\",\"duration\":$dur,\"capacity\":$cap,\"tags\":[]}")
  id=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "ERR")
  echo "$id"
}

create_formula() {
  local name="$1" fac="$2" comp="$3" yf="$4" yt="$5" af="$6" at="$7" levels="$8" price="$9" salable="${10:-false}"
  local result id
  result=$(curl -s -X POST "$API/formulas" \
    -H "$KEY" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"faculty_id\":$fac,\"company_id\":$comp,\"year_from\":$yf,\"year_to\":$yt,\"accessible_from\":\"${af}T00:00:00.000Z\",\"accessible_to\":\"${at}T23:59:59.000Z\",\"levels\":$levels,\"tags\":[],\"is_active\":true,\"is_salable\":$salable,\"price\":$price,\"steps\":[{\"name\":\"Candidature\",\"is_subscription\":false,\"order\":1},{\"name\":\"Inscription\",\"is_subscription\":true,\"order\":2}]}")
  id=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "ERR")
  echo "$id"
}

add_set() {
  local formula_id="$1" name="$2" min="$3" max="$4" order="$5" formation_ids="$6"
  # formation_ids: comma separated, ex: "10" or "18,17"
  local to_patch=""
  IFS=',' read -ra IDS <<< "$formation_ids"
  for fid in "${IDS[@]}"; do
    [ -n "$to_patch" ] && to_patch+=","
    to_patch+="{\"formation_id\":$fid}"
  done

  curl -s -X POST "$API/formulas/$formula_id/sets" \
    -H "$KEY" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"min\":$min,\"max\":$max,\"order\":$order,\"formations\":{\"to_patch\":[$to_patch]}}" > /dev/null
}

# =============================================================================
# 1. FORMATIONS
# =============================================================================
echo "=== Création des formations ==="

# Sciences & Technologies
F_TRONC_L2L3=$(create_formation "Tronc commun Sciences L2-L3" "[3]" "[23,24]" 2025 2027 "2025-09-01" "2027-06-30" 4320000 120)
echo "Formation Tronc commun Sciences L2-L3: ID=$F_TRONC_L2L3"

F_PREPA_T1=$(create_formation "Prépa Scientifique — T1 Fondamentaux" "[3,4]" "[21]" 2025 2026 "2025-09-01" "2025-12-20" 720000 80)
echo "Formation Prépa T1 Fondamentaux: ID=$F_PREPA_T1"

F_PREPA_T2=$(create_formation "Prépa Scientifique — T2 Approfondissement" "[3,4]" "[21]" 2025 2026 "2026-01-06" "2026-03-28" 720000 80)
echo "Formation Prépa T2 Approfondissement: ID=$F_PREPA_T2"

F_STAGE_LABO=$(create_formation "Stage Recherche en Laboratoire" "[3]" "[25,26]" 2025 2026 "2025-09-01" "2026-06-30" 504000 40)
echo "Formation Stage Recherche Labo: ID=$F_STAGE_LABO"

# Arts & Lettres
F_HIST_ART=$(create_formation "Enseignements théoriques — Histoire de l art" "[5]" "[22,23,24]" 2025 2026 "2025-09-01" "2026-06-30" 1440000 60)
echo "Formation Histoire de l'art: ID=$F_HIST_ART"

F_ATELIERS=$(create_formation "Ateliers pratiques — Arts plastiques" "[5]" "[22,23,24]" 2025 2026 "2025-09-01" "2026-06-30" 1080000 45)
echo "Formation Ateliers Arts plastiques: ID=$F_ATELIERS"

F_MASTER_TC=$(create_formation "Master Création Contemporaine — Tronc commun" "[5,6]" "[25,26]" 2025 2026 "2025-09-01" "2026-06-30" 1440000 35)
echo "Formation Master Tronc commun: ID=$F_MASTER_TC"

F_WORKSHOP=$(create_formation "Workshop International Arts" "[6]" "[25,26]" 2025 2026 "2025-09-01" "2026-06-30" 360000 25)
echo "Formation Workshop International: ID=$F_WORKSHOP"

F_STAGE_CREA=$(create_formation "Stage Recherche Création" "[5,6]" "[25,26]" 2025 2026 "2025-09-01" "2026-06-30" 504000 30)
echo "Formation Stage Recherche Création: ID=$F_STAGE_CREA"

echo ""

# =============================================================================
# 2. FORMULES
# =============================================================================
echo "=== Création des formules ==="

# --- Formule 1 : Licence Sciences L2-L3 (formation sur 2 ans) ---
FM1=$(create_formula "Licence Sciences — Cycle L2-L3" 3 1 2025 2027 "2025-06-01" "2027-06-30" "[23,24]" 850000)
echo "Formule Licence Sciences L2-L3: ID=$FM1"
add_set "$FM1" "Tronc commun" 1 1 1 "$F_TRONC_L2L3"
echo "  + Set Tronc commun → Formation $F_TRONC_L2L3"

# --- Formule 2 : Prépa Scientifique Intensive (2 trimestres) ---
FM2=$(create_formula "Prépa Scientifique Intensive" 3 1 2025 2026 "2025-06-01" "2026-03-31" "[21]" 450000)
echo "Formule Prépa Intensive: ID=$FM2"
add_set "$FM2" "Trimestre 1 — Fondamentaux" 1 1 1 "$F_PREPA_T1"
echo "  + Set T1 → Formation $F_PREPA_T1"
add_set "$FM2" "Trimestre 2 — Approfondissement" 1 1 2 "$F_PREPA_T2"
echo "  + Set T2 → Formation $F_PREPA_T2"

# --- Formule 3 : Stage Recherche en Laboratoire (commercialisable) ---
FM3=$(create_formula "Stage Recherche en Laboratoire" 3 1 2025 2026 "2025-06-01" "2026-06-30" "[25,26]" 180000 true)
echo "Formule Stage Labo (salable): ID=$FM3"
add_set "$FM3" "Stage obligatoire" 1 1 1 "$F_STAGE_LABO"
echo "  + Set Stage → Formation $F_STAGE_LABO"

# --- Formule 4 : Licence Arts Plastiques (théorie + pratique) ---
FM4=$(create_formula "Licence Arts Plastiques — Cycle complet" 5 2 2025 2026 "2025-06-01" "2026-06-30" "[22,23,24]" 650000)
echo "Formule Licence Arts: ID=$FM4"
add_set "$FM4" "Enseignements théoriques" 1 1 1 "$F_HIST_ART"
echo "  + Set Théorie → Formation $F_HIST_ART"
add_set "$FM4" "Ateliers pratiques" 1 1 2 "$F_ATELIERS"
echo "  + Set Pratique → Formation $F_ATELIERS"

# --- Formule 5 : Master Création Contemporaine (tronc commun + options dont stage) ---
FM5=$(create_formula "Master Création Contemporaine" 6 2 2025 2026 "2025-06-01" "2026-06-30" "[25,26]" 780000)
echo "Formule Master Création: ID=$FM5"
add_set "$FM5" "Tronc commun" 1 1 1 "$F_MASTER_TC"
echo "  + Set Tronc commun → Formation $F_MASTER_TC"
add_set "$FM5" "Options" 1 2 2 "$F_STAGE_CREA,$F_WORKSHOP"
echo "  + Set Options (min:1 max:2) → Formations $F_STAGE_CREA + $F_WORKSHOP"

echo ""
echo "=== DONE ==="
echo ""
echo "Résumé :"
echo "  9 formations créées"
echo "  5 formules créées avec 8 sets au total"
echo ""
echo "Cas couverts :"
echo "  - Formation sur 2 ans : Formule $FM1 (Licence Sciences L2-L3)"
echo "  - Formule en 2 trimestres : Formule $FM2 (Prépa T1 + T2)"
echo "  - Stage commercialisé : Formule $FM3 (is_salable=true)"
echo "  - Stage en option : Formule $FM5 Set Options (Stage Recherche Création)"
