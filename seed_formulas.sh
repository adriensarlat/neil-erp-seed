#!/usr/bin/env bash
# =============================================================================
# seed_formulas.sh — Création des formations, formules, étapes, échéanciers,
#                    remises et frais exceptionnels pour Neil ERP
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

get_step_ids() {
  # Retourne les step IDs d'une formule, séparés par des espaces
  local formula_id="$1"
  curl -s "$API/formulas/$formula_id" -H "$KEY" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for s in sorted(d.get('steps', []), key=lambda x: x['order']):
    print(s['id'], end=' ')
" 2>/dev/null
}

add_discount() {
  local fid="$1" name="$2" type="$3" amount="$4"
  curl -s -X POST "$API/formulas/$fid/discounts" \
    -H "$KEY" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"type\":\"$type\",\"amount\":$amount}" > /dev/null
}

add_charge() {
  local fid="$1" name="$2" type="$3" amount="$4"
  curl -s -X POST "$API/formulas/$fid/charges" \
    -H "$KEY" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"type\":\"$type\",\"amount\":$amount}" > /dev/null
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
# 2. FORMULES + SETS
# =============================================================================
echo "=== Création des formules ==="

# --- Formule 1 : Licence Sciences L2-L3 (formation sur 2 ans, 8500€) ---
FM1=$(create_formula "Licence Sciences — Cycle L2-L3" 3 1 2025 2027 "2025-06-01" "2027-06-30" "[23,24]" 850000)
echo "Formule Licence Sciences L2-L3: ID=$FM1"
add_set "$FM1" "Tronc commun" 1 1 1 "$F_TRONC_L2L3"

# --- Formule 2 : Prépa Scientifique Intensive (2 trimestres, 4500€) ---
FM2=$(create_formula "Prépa Scientifique Intensive" 3 1 2025 2026 "2025-06-01" "2026-03-31" "[21]" 450000)
echo "Formule Prépa Intensive: ID=$FM2"
add_set "$FM2" "Trimestre 1 — Fondamentaux" 1 1 1 "$F_PREPA_T1"
add_set "$FM2" "Trimestre 2 — Approfondissement" 1 1 2 "$F_PREPA_T2"

# --- Formule 3 : Stage Recherche en Laboratoire (commercialisable, 1800€) ---
FM3=$(create_formula "Stage Recherche en Laboratoire" 3 1 2025 2026 "2025-06-01" "2026-06-30" "[25,26]" 180000 true)
echo "Formule Stage Labo (salable): ID=$FM3"
add_set "$FM3" "Stage obligatoire" 1 1 1 "$F_STAGE_LABO"

# --- Formule 4 : Licence Arts Plastiques (théorie + pratique, 6500€) ---
FM4=$(create_formula "Licence Arts Plastiques — Cycle complet" 5 2 2025 2026 "2025-06-01" "2026-06-30" "[22,23,24]" 650000)
echo "Formule Licence Arts: ID=$FM4"
add_set "$FM4" "Enseignements théoriques" 1 1 1 "$F_HIST_ART"
add_set "$FM4" "Ateliers pratiques" 1 1 2 "$F_ATELIERS"

# --- Formule 5 : Master Création Contemporaine (options dont stage, 7800€) ---
FM5=$(create_formula "Master Création Contemporaine" 6 2 2025 2026 "2025-06-01" "2026-06-30" "[25,26]" 780000)
echo "Formule Master Création: ID=$FM5"
add_set "$FM5" "Tronc commun" 1 1 1 "$F_MASTER_TC"
add_set "$FM5" "Options" 1 2 2 "$F_STAGE_CREA,$F_WORKSHOP"

echo ""

# =============================================================================
# 3. ÉTAPES D'INSCRIPTION
# =============================================================================
echo "=== Mise à jour des étapes d'inscription ==="

# --- Formule 1 : Licence Sciences (3 étapes) ---
# Candidature (frais 150€ déductibles) → Admission (commission + acompte 1000€) → Inscription
echo "Formule $FM1: Candidature → Admission → Inscription"
curl -s -X PATCH "$API/formulas/$FM1/steps" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d '{
    "steps": [
      {"name":"Candidature","description":"Dossier de candidature et pièces justificatives","is_subscription":false,"order":1,"has_charge":true,"charge":15000,"charge_label":"Frais de dossier","charge_is_deductible":true,"charge_is_due":true,"files":[{"name":"CV"},{"name":"Lettre de motivation"},{"name":"Relevés de notes"}]},
      {"name":"Admission","description":"Examen du dossier par la commission pédagogique","is_subscription":false,"order":2,"commission":true,"has_advance":true,"advance":100000,"advance_label":"Acompte de réservation"},
      {"name":"Inscription définitive","description":"Signature du contrat et inscription administrative","is_subscription":true,"order":3,"files":[{"name":"Pièce d identité"},{"name":"Attestation CVEC"},{"name":"Photo d identité"}]}
    ]
  }' > /dev/null

# --- Formule 2 : Prépa Scientifique (3 étapes) ---
# Candidature (frais 80€) → Confirmation (acompte 500€) → Inscription
echo "Formule $FM2: Candidature → Confirmation → Inscription"
curl -s -X PATCH "$API/formulas/$FM2/steps" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d '{
    "steps": [
      {"name":"Candidature","description":"Test de niveau et dossier scolaire","is_subscription":false,"order":1,"has_charge":true,"charge":8000,"charge_label":"Frais de candidature","charge_is_deductible":true,"charge_is_due":true,"files":[{"name":"Bulletins scolaires"},{"name":"Résultats bac"}]},
      {"name":"Confirmation","description":"Confirmation de place et versement de l acompte","is_subscription":false,"order":2,"has_advance":true,"advance":50000,"advance_label":"Acompte de confirmation"},
      {"name":"Inscription","description":"Inscription définitive et choix du campus","is_subscription":true,"order":3,"files":[{"name":"Pièce d identité"},{"name":"Attestation CVEC"}]}
    ]
  }' > /dev/null

# --- Formule 3 : Stage Recherche Labo (3 étapes) ---
# Pré-inscription (frais 50€ non déductibles) → Validation scientifique (commission) → Inscription
echo "Formule $FM3: Pré-inscription → Validation → Inscription"
curl -s -X PATCH "$API/formulas/$FM3/steps" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d '{
    "steps": [
      {"name":"Pré-inscription","description":"Choix du laboratoire et dépôt de candidature","is_subscription":false,"order":1,"has_charge":true,"charge":5000,"charge_label":"Frais de traitement","charge_is_deductible":false,"charge_is_due":true,"files":[{"name":"Projet de recherche"},{"name":"CV académique"}]},
      {"name":"Validation scientifique","description":"Accord du directeur de laboratoire","is_subscription":false,"order":2,"commission":true},
      {"name":"Inscription au stage","description":"Paiement et convention de stage","is_subscription":true,"order":3,"files":[{"name":"Convention de stage signée"}]}
    ]
  }' > /dev/null

# --- Formule 4 : Licence Arts Plastiques (3 étapes) ---
# Candidature artistique (frais 120€) → Jury (commission + acompte 800€) → Inscription
echo "Formule $FM4: Candidature artistique → Jury → Inscription"
curl -s -X PATCH "$API/formulas/$FM4/steps" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d '{
    "steps": [
      {"name":"Candidature artistique","description":"Soumission du dossier artistique (portfolio) et entretien","is_subscription":false,"order":1,"has_charge":true,"charge":12000,"charge_label":"Frais de candidature","charge_is_deductible":true,"charge_is_due":true,"files":[{"name":"Portfolio artistique"},{"name":"Lettre de motivation"},{"name":"Bulletins scolaires"}]},
      {"name":"Jury d admission","description":"Passage devant le jury artistique","is_subscription":false,"order":2,"commission":true,"has_advance":true,"advance":80000,"advance_label":"Acompte de réservation"},
      {"name":"Inscription administrative","description":"Finalisation de l inscription et choix des ateliers","is_subscription":true,"order":3,"files":[{"name":"Pièce d identité"},{"name":"Attestation CVEC"},{"name":"Photo d identité"},{"name":"Attestation assurance"}]}
    ]
  }' > /dev/null

# --- Formule 5 : Master Création Contemporaine (4 étapes) ---
# Candidature (frais 150€) → Entretien/commission (acompte 1200€) → Choix options → Inscription
echo "Formule $FM5: Candidature → Entretien → Choix options → Inscription"
curl -s -X PATCH "$API/formulas/$FM5/steps" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d '{
    "steps": [
      {"name":"Candidature","description":"Dossier académique, portfolio et projet de recherche","is_subscription":false,"order":1,"has_charge":true,"charge":15000,"charge_label":"Frais de dossier","charge_is_deductible":true,"charge_is_due":true,"files":[{"name":"Portfolio"},{"name":"Projet de recherche"},{"name":"CV"},{"name":"Diplômes"}]},
      {"name":"Entretien et commission","description":"Entretien individuel et délibération de la commission","is_subscription":false,"order":2,"commission":true,"has_advance":true,"advance":120000,"advance_label":"Acompte d admission"},
      {"name":"Choix des options","description":"Sélection des formations optionnelles","is_subscription":false,"order":3},
      {"name":"Inscription définitive","description":"Validation administrative et signature du contrat","is_subscription":true,"order":4,"files":[{"name":"Pièce d identité"},{"name":"Attestation CVEC"},{"name":"Attestation assurance"},{"name":"RIB"}]}
    ]
  }' > /dev/null

echo ""

# =============================================================================
# 4. ÉCHÉANCIERS DE PAIEMENT
# =============================================================================
echo "=== Ajout des échéanciers de paiement ==="

# Récupérer les step IDs (subscription step = dernier) pour chaque formule
FM1_STEPS=($(get_step_ids "$FM1"))
FM2_STEPS=($(get_step_ids "$FM2"))
FM3_STEPS=($(get_step_ids "$FM3"))
FM4_STEPS=($(get_step_ids "$FM4"))
FM5_STEPS=($(get_step_ids "$FM5"))

FM1_SUB=${FM1_STEPS[-1]}  # Dernier step = subscription
FM2_SUB=${FM2_STEPS[-1]}
FM3_SUB=${FM3_STEPS[-1]}
FM4_SUB=${FM4_STEPS[-1]}
FM5_SUB=${FM5_STEPS[-1]}

# --- Formule 1 : Licence Sciences (8500€) → Comptant / 3x / 10 mensualités ---
echo "Formule $FM1: 3 échéanciers (comptant, 3x, 10 mensualités)"
curl -s -X PATCH "$API/formulas/$FM1" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d "{
    \"schedule_templates\": [
      {\"name\":\"Paiement comptant\",\"steps\":{\"$FM1_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"Solde intégral\",\"amount\":850000,\"charge_type\":\"payment\"}
      ]}},
      {\"name\":\"Paiement en 3 fois\",\"steps\":{\"$FM1_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"1er versement\",\"amount\":284000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-12-15T00:00:00.000Z\",\"label\":\"2e versement\",\"amount\":283000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-03-15T00:00:00.000Z\",\"label\":\"3e versement\",\"amount\":283000,\"charge_type\":\"payment\"}
      ]}},
      {\"name\":\"10 mensualités\",\"steps\":{\"$FM1_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"Mensualité 1\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-10-15T00:00:00.000Z\",\"label\":\"Mensualité 2\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-11-15T00:00:00.000Z\",\"label\":\"Mensualité 3\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-12-15T00:00:00.000Z\",\"label\":\"Mensualité 4\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-01-15T00:00:00.000Z\",\"label\":\"Mensualité 5\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-02-15T00:00:00.000Z\",\"label\":\"Mensualité 6\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-03-15T00:00:00.000Z\",\"label\":\"Mensualité 7\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-04-15T00:00:00.000Z\",\"label\":\"Mensualité 8\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-05-15T00:00:00.000Z\",\"label\":\"Mensualité 9\",\"amount\":85000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-06-15T00:00:00.000Z\",\"label\":\"Mensualité 10\",\"amount\":85000,\"charge_type\":\"payment\"}
      ]}}
    ]
  }" > /dev/null

# --- Formule 2 : Prépa Scientifique (4500€) → Comptant / 2x par trimestre ---
echo "Formule $FM2: 2 échéanciers (comptant, 2x par trimestre)"
curl -s -X PATCH "$API/formulas/$FM2" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d "{
    \"schedule_templates\": [
      {\"name\":\"Paiement comptant\",\"steps\":{\"$FM2_SUB\":[
        {\"due_date\":\"2025-09-01T00:00:00.000Z\",\"label\":\"Solde intégral\",\"amount\":450000,\"charge_type\":\"payment\"}
      ]}},
      {\"name\":\"Paiement en 2 fois (par trimestre)\",\"steps\":{\"$FM2_SUB\":[
        {\"due_date\":\"2025-09-01T00:00:00.000Z\",\"label\":\"1er versement (T1)\",\"amount\":225000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-01-05T00:00:00.000Z\",\"label\":\"2e versement (T2)\",\"amount\":225000,\"charge_type\":\"payment\"}
      ]}}
    ]
  }" > /dev/null

# --- Formule 3 : Stage Recherche (1800€) → Paiement unique ---
echo "Formule $FM3: 1 échéancier (paiement unique)"
curl -s -X PATCH "$API/formulas/$FM3" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d "{
    \"schedule_templates\": [
      {\"name\":\"Paiement unique\",\"steps\":{\"$FM3_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"Frais de stage\",\"amount\":180000,\"charge_type\":\"payment\"}
      ]}}
    ]
  }" > /dev/null

# --- Formule 4 : Licence Arts (6500€) → Comptant / 3x / 8 mensualités ---
echo "Formule $FM4: 3 échéanciers (comptant, 3x, 8 mensualités)"
curl -s -X PATCH "$API/formulas/$FM4" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d "{
    \"schedule_templates\": [
      {\"name\":\"Paiement comptant\",\"steps\":{\"$FM4_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"Solde intégral\",\"amount\":650000,\"charge_type\":\"payment\"}
      ]}},
      {\"name\":\"Paiement en 3 fois\",\"steps\":{\"$FM4_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"1er versement\",\"amount\":217000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-12-15T00:00:00.000Z\",\"label\":\"2e versement\",\"amount\":217000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-03-15T00:00:00.000Z\",\"label\":\"3e versement\",\"amount\":216000,\"charge_type\":\"payment\"}
      ]}},
      {\"name\":\"8 mensualités\",\"steps\":{\"$FM4_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"Mensualité 1\",\"amount\":81250,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-10-15T00:00:00.000Z\",\"label\":\"Mensualité 2\",\"amount\":81250,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-11-15T00:00:00.000Z\",\"label\":\"Mensualité 3\",\"amount\":81250,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-12-15T00:00:00.000Z\",\"label\":\"Mensualité 4\",\"amount\":81250,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-01-15T00:00:00.000Z\",\"label\":\"Mensualité 5\",\"amount\":81250,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-02-15T00:00:00.000Z\",\"label\":\"Mensualité 6\",\"amount\":81250,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-03-15T00:00:00.000Z\",\"label\":\"Mensualité 7\",\"amount\":81250,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-04-15T00:00:00.000Z\",\"label\":\"Mensualité 8\",\"amount\":81250,\"charge_type\":\"payment\"}
      ]}}
    ]
  }" > /dev/null

# --- Formule 5 : Master Création (7800€) → Comptant / 3x / 10 mensualités ---
echo "Formule $FM5: 3 échéanciers (comptant, 3x, 10 mensualités)"
curl -s -X PATCH "$API/formulas/$FM5" \
  -H "$KEY" -H 'Content-Type: application/json' \
  -d "{
    \"schedule_templates\": [
      {\"name\":\"Paiement comptant\",\"steps\":{\"$FM5_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"Solde intégral\",\"amount\":780000,\"charge_type\":\"payment\"}
      ]}},
      {\"name\":\"Paiement en 3 fois\",\"steps\":{\"$FM5_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"1er versement\",\"amount\":260000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-12-15T00:00:00.000Z\",\"label\":\"2e versement\",\"amount\":260000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-03-15T00:00:00.000Z\",\"label\":\"3e versement\",\"amount\":260000,\"charge_type\":\"payment\"}
      ]}},
      {\"name\":\"10 mensualités\",\"steps\":{\"$FM5_SUB\":[
        {\"due_date\":\"2025-09-15T00:00:00.000Z\",\"label\":\"Mensualité 1\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-10-15T00:00:00.000Z\",\"label\":\"Mensualité 2\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-11-15T00:00:00.000Z\",\"label\":\"Mensualité 3\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2025-12-15T00:00:00.000Z\",\"label\":\"Mensualité 4\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-01-15T00:00:00.000Z\",\"label\":\"Mensualité 5\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-02-15T00:00:00.000Z\",\"label\":\"Mensualité 6\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-03-15T00:00:00.000Z\",\"label\":\"Mensualité 7\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-04-15T00:00:00.000Z\",\"label\":\"Mensualité 8\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-05-15T00:00:00.000Z\",\"label\":\"Mensualité 9\",\"amount\":78000,\"charge_type\":\"payment\"},
        {\"due_date\":\"2026-06-15T00:00:00.000Z\",\"label\":\"Mensualité 10\",\"amount\":78000,\"charge_type\":\"payment\"}
      ]}}
    ]
  }" > /dev/null

echo ""

# =============================================================================
# 5. REMISES ET FRAIS EXCEPTIONNELS
# =============================================================================
echo "=== Ajout des remises et frais exceptionnels ==="

# --- Formule 1 : Licence Sciences (8500€) ---
echo "Formule $FM1: remises + frais"
add_discount "$FM1" "Bourse au mérite" "fixed" 100000
add_discount "$FM1" "Réduction paiement comptant (-5%)" "fixed" 42500
add_discount "$FM1" "Fratrie" "fixed" 85000
add_charge "$FM1" "Frais de matériel scientifique" "fixed" 35000

# --- Formule 2 : Prépa Scientifique (4500€) ---
echo "Formule $FM2: remises + frais"
add_discount "$FM2" "Réduction paiement anticipé" "fixed" 30000
add_discount "$FM2" "Bourse excellence" "fixed" 67500
add_charge "$FM2" "Manuels et supports de cours" "fixed" 15000

# --- Formule 3 : Stage Recherche (1800€) ---
echo "Formule $FM3: remises + frais"
add_discount "$FM3" "Étudiant de l établissement" "fixed" 36000
add_charge "$FM3" "Équipement de laboratoire" "fixed" 12000

# --- Formule 4 : Licence Arts (6500€) ---
echo "Formule $FM4: remises + frais"
add_discount "$FM4" "Bourse talent artistique" "fixed" 80000
add_discount "$FM4" "Réduction paiement comptant (-5%)" "fixed" 32500
add_discount "$FM4" "Fratrie" "fixed" 65000
add_charge "$FM4" "Fournitures artistiques" "fixed" 25000
add_charge "$FM4" "Accès ateliers spécialisés" "fixed" 18000

# --- Formule 5 : Master Création (7800€) ---
echo "Formule $FM5: remises + frais"
add_discount "$FM5" "Bourse recherche création" "fixed" 150000
add_discount "$FM5" "Ancien étudiant Licence" "fixed" 78000
add_discount "$FM5" "Réduction paiement comptant (-5%)" "fixed" 39000
add_charge "$FM5" "Matériel studio" "fixed" 30000

echo ""
echo "=== DONE ==="
echo ""
echo "Résumé :"
echo "  9 formations créées"
echo "  5 formules créées avec 8 sets"
echo "  5 parcours d'inscription (3-4 étapes chacun)"
echo "  12 échéanciers de paiement"
echo "  13 remises et 6 frais exceptionnels"
