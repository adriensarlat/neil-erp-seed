#!/usr/bin/env bash
#
# seed_neil.sh — Script de seed complet pour l'ERP Neil
# Crée 2 écoles × 2 campus, 4 centres d'activité avec salles, puis lie le tout
#
# Idempotent : si les écoles existent déjà, récupère les IDs existants
#
# Usage : ./seed_neil.sh
#
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
API_BASE="https://neil-claude.erp.neil.app/api"
COUNTRY_FR=75

# ─── Couleurs ───────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

if ! command -v jq &>/dev/null; then
    log_error "jq est requis. Installez-le avec : brew install jq"
    exit 1
fi

# ─── Appel API (retourne: body sur stdout, http_code sur fd3) ───────────────
# Usage: response=$(api_call METHOD ENDPOINT [BODY])
# En cas d'erreur HTTP >= 400 : exit 1
api_call() {
    local method="$1" endpoint="$2" body="${3:-}"
    local url="${API_BASE}${endpoint}"
    local tmp; tmp=$(mktemp)
    local http_code

    if [[ -n "$body" ]]; then
        http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
            -X "$method" \
            -H 'X-Lucius-Api-Key: LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww' \
            -H 'Content-Type: application/json' \
            -d "$body" "$url")
    else
        http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
            -X "$method" \
            -H 'X-Lucius-Api-Key: LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww' \
            -H 'Content-Type: application/json' "$url")
    fi

    local response; response=$(cat "$tmp"); rm -f "$tmp"

    if [[ "$http_code" -ge 400 ]]; then
        log_error "HTTP ${http_code} — ${method} ${endpoint}" >&2
        log_error "Réponse : ${response}" >&2
        exit 1
    fi
    echo "$response"
}

# Variante qui ne quitte pas en cas d'erreur, retourne le code HTTP
api_call_safe() {
    local method="$1" endpoint="$2" body="${3:-}"
    local url="${API_BASE}${endpoint}"
    local tmp; tmp=$(mktemp)
    local http_code

    if [[ -n "$body" ]]; then
        http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
            -X "$method" \
            -H 'X-Lucius-Api-Key: LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww' \
            -H 'Content-Type: application/json' \
            -d "$body" "$url")
    else
        http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
            -X "$method" \
            -H 'X-Lucius-Api-Key: LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww' \
            -H 'Content-Type: application/json' "$url")
    fi

    local response; response=$(cat "$tmp"); rm -f "$tmp"
    echo "${http_code}|${response}"
}

# ─── Helpers de création ────────────────────────────────────────────────────

# create_school_or_get "Nom" "Short" "1er campus"  →  stdout: "school_id faculty_id"
create_school_or_get() {
    local name="$1" short_name="$2" first_faculty="$3"
    local payload
    payload=$(jq -n --arg n "$name" --arg s "$short_name" --arg f "$first_faculty" \
        '{name:$n, short_name:$s, faculty:{name:$f}}')

    log_info "Création école '${name}' + campus '${first_faculty}'..." >&2
    local result; result=$(api_call_safe POST "/schools" "$payload")
    local code="${result%%|*}"
    local body="${result#*|}"

    if [[ "$code" == "201" || "$code" == "200" ]]; then
        local sid fid
        sid=$(echo "$body" | jq -r '.id')
        fid=$(echo "$body" | jq -r '.faculty.id')
        log_success "École '${name}' créée (ID:${sid}) + Campus '${first_faculty}' (ID:${fid})" >&2
        echo "${sid} ${fid}"
    elif [[ "$code" == "409" ]]; then
        log_warn "École '${name}' existe déjà — récupération des IDs..." >&2
        local schools; schools=$(api_call GET "/schools")
        local sid; sid=$(echo "$schools" | jq -r --arg n "$name" '.[] | select(.name==$n) | .id')
        local faculties; faculties=$(api_call GET "/faculties")
        local fid; fid=$(echo "$faculties" | jq -r --arg n "$first_faculty" '.[] | select(.name==$n) | .id')
        log_success "École '${name}' (ID:${sid}) + Campus '${first_faculty}' (ID:${fid}) [existants]" >&2
        echo "${sid} ${fid}"
    else
        log_error "HTTP ${code} — POST /schools" >&2
        log_error "Réponse : ${body}" >&2
        exit 1
    fi
}

# create_faculty_or_get "Nom" SCHOOL_ID  →  stdout: faculty_id
create_faculty_or_get() {
    local name="$1" school_id="$2"
    local payload
    payload=$(jq -n --arg n "$name" --argjson s "$school_id" '{name:$n, school_id:$s}')

    log_info "  Création campus '${name}'..." >&2
    local result; result=$(api_call_safe POST "/faculties" "$payload")
    local code="${result%%|*}"
    local body="${result#*|}"

    if [[ "$code" == "201" || "$code" == "200" ]]; then
        local fid; fid=$(echo "$body" | jq -r '.id')
        log_success "  Campus '${name}' (ID:${fid})" >&2
        echo "$fid"
    elif [[ "$code" == "409" ]]; then
        log_warn "  Campus '${name}' existe déjà — récupération..." >&2
        local faculties; faculties=$(api_call GET "/faculties")
        local fid; fid=$(echo "$faculties" | jq -r --arg n "$name" '.[] | select(.name==$n) | .id')
        log_success "  Campus '${name}' (ID:${fid}) [existant]" >&2
        echo "$fid"
    else
        log_error "HTTP ${code} — POST /faculties" >&2
        log_error "Réponse : ${body}" >&2
        exit 1
    fi
}

# create_center "Nom" "#color" "adresse" "ville" "CP"  →  stdout: center_id
create_center() {
    local name="$1" color="$2" addr="$3" city="$4" postal="$5"
    local payload
    payload=$(jq -n \
        --arg name "$name" --arg color "$color" \
        --arg addr "$addr" --arg city "$city" --arg postal "$postal" \
        --argjson country "$COUNTRY_FR" \
        '{name:$name, color:$color, address:{address:$addr, city:$city, postal_code:$postal, country_id:$country}}')

    log_info "  Création centre '${name}' (${city})..." >&2
    local result; result=$(api_call_safe POST "/centers" "$payload")
    local code="${result%%|*}"
    local body="${result#*|}"

    if [[ "$code" == "201" || "$code" == "200" ]]; then
        local cid; cid=$(echo "$body" | jq -r '.id')
        log_success "  Centre '${name}' (ID:${cid})" >&2
        echo "$cid"
    elif [[ "$code" == "409" ]]; then
        log_warn "  Centre '${name}' existe déjà — récupération..." >&2
        local centers; centers=$(api_call GET "/centers")
        local cid; cid=$(echo "$centers" | jq -r --arg n "$name" '.[] | select(.name==$n) | .id')
        log_success "  Centre '${name}' (ID:${cid}) [existant]" >&2
        echo "$cid"
    else
        log_error "HTTP ${code} — POST /centers" >&2
        log_error "Réponse : ${body}" >&2
        exit 1
    fi
}

# create_room "Nom" CENTER_ID [CAPACITY]  →  stdout: room_id
create_room() {
    local name="$1" center_id="$2" capacity="${3:-}"
    local payload
    if [[ -n "$capacity" ]]; then
        payload=$(jq -n --arg n "$name" --argjson c "$center_id" --argjson cap "$capacity" \
            '{name:$n, center_id:$c, capacity:$cap}')
    else
        payload=$(jq -n --arg n "$name" --argjson c "$center_id" \
            '{name:$n, center_id:$c}')
    fi

    log_info "    + Salle '${name}'${capacity:+ (${capacity} places)}..." >&2
    local result; result=$(api_call_safe POST "/rooms" "$payload")
    local code="${result%%|*}"
    local body="${result#*|}"

    if [[ "$code" == "201" || "$code" == "200" ]]; then
        local rid; rid=$(echo "$body" | jq -r '.id')
        log_success "    Salle '${name}' (ID:${rid})" >&2
        echo "$rid"
    elif [[ "$code" == "409" ]]; then
        log_warn "    Salle '${name}' existe déjà — skip" >&2
        echo "0"
    else
        log_error "HTTP ${code} — POST /rooms" >&2
        log_error "Réponse : ${body}" >&2
        exit 1
    fi
}

# link_faculty_to_centers FACULTY_ID CENTER_ID1 [CENTER_ID2 ...]
link_faculty_to_centers() {
    local fid="$1"; shift
    local centers_json="["
    local first=true
    for cid in "$@"; do
        $first || centers_json+=","
        centers_json+="{\"center_id\":${cid}}"
        first=false
    done
    centers_json+="]"

    log_info "  Liaison campus ID:${fid} → centres [$*]..." >&2
    api_call POST "/faculties/${fid}/centers" "{\"centers\":${centers_json}}" >/dev/null
    log_success "  Campus ID:${fid} lié aux centres [$*]" >&2
}

# ═══════════════════════════════════════════════════════════════════════════
#                              MAIN
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   NEIL ERP — Seed complet (écoles, campus, centres, salles)     ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ÉTAPE 1 — Écoles & Campus
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${YELLOW}━━ ÉTAPE 1 : Écoles & Campus ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -r SCHOOL1_ID FAC_PARIS_ID   <<< "$(create_school_or_get "Sciences & Technologies" "S&T" "Campus Paris - Saclay")"
FAC_LYON_ID=$(create_faculty_or_get "Campus Lyon - Part-Dieu" "$SCHOOL1_ID")
echo ""

read -r SCHOOL2_ID FAC_BORDEAUX_ID <<< "$(create_school_or_get "Arts & Lettres" "A&L" "Campus Bordeaux - Chartrons")"
FAC_MARSEILLE_ID=$(create_faculty_or_get "Campus Marseille - Vieux-Port" "$SCHOOL2_ID")
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ÉTAPE 2 — Centres d'activité & Salles
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${YELLOW}━━ ÉTAPE 2 : Centres d'activité & Salles ━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── Centre 1 : Pôle Scientifique de Saclay (→ Campus Paris-Saclay) ──
echo -e "${MAGENTA}  ── Centre 1 : Pôle Scientifique de Saclay ──${NC}"
CTR_SACLAY_ID=$(create_center \
    "Pôle Scientifique de Saclay" "#1E88E5" \
    "3 rue Joliot-Curie, Bâtiment Breguet" "Gif-sur-Yvette" "91190")

create_room "Amphithéâtre Curie"       "$CTR_SACLAY_ID" 120
create_room "Salle de TD - Newton"     "$CTR_SACLAY_ID" 35
create_room "Salle de TD - Euler"      "$CTR_SACLAY_ID" 35
create_room "Laboratoire Informatique"  "$CTR_SACLAY_ID" 24
create_room "Salle de réunion Pasteur"  "$CTR_SACLAY_ID" 12
echo ""

# ── Centre 2 : Espace Lyon Part-Dieu (→ Campus Lyon) ──
echo -e "${MAGENTA}  ── Centre 2 : Espace Lyon Part-Dieu ──${NC}"
CTR_LYON_ID=$(create_center \
    "Espace Lyon Part-Dieu" "#43A047" \
    "47 boulevard Vivier Merle" "Lyon" "69003")

create_room "Salle Lumière"        "$CTR_LYON_ID" 40
create_room "Salle Ampère"         "$CTR_LYON_ID" 30
create_room "Labo Physique-Chimie" "$CTR_LYON_ID" 20
create_room "Salle Informatique"   "$CTR_LYON_ID" 28
echo ""

# ── Centre 3 : Maison des Arts de Bordeaux (→ Campus Bordeaux) ──
echo -e "${MAGENTA}  ── Centre 3 : Maison des Arts de Bordeaux ──${NC}"
CTR_BORDEAUX_ID=$(create_center \
    "Maison des Arts de Bordeaux" "#FB8C00" \
    "12 quai des Chartrons" "Bordeaux" "33000")

create_room "Atelier Peinture & Sculpture"  "$CTR_BORDEAUX_ID" 25
create_room "Studio Photographie"           "$CTR_BORDEAUX_ID" 15
create_room "Salle de conférence Montaigne" "$CTR_BORDEAUX_ID" 60
create_room "Bibliothèque"                  "$CTR_BORDEAUX_ID" 40
echo ""

# ── Centre 4 : Campus Méditerranée (→ Campus Marseille) ──
echo -e "${MAGENTA}  ── Centre 4 : Campus Méditerranée ──${NC}"
CTR_MARSEILLE_ID=$(create_center \
    "Campus Méditerranée" "#E53935" \
    "58 quai du Port" "Marseille" "13002")

create_room "Salle Cézanne"        "$CTR_MARSEILLE_ID" 35
create_room "Salle Pagnol"         "$CTR_MARSEILLE_ID" 30
create_room "Studio Musique & Son" "$CTR_MARSEILLE_ID" 18
create_room "Salle de Danse"       "$CTR_MARSEILLE_ID" 20
create_room "Espace Exposition"    "$CTR_MARSEILLE_ID" 50
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ÉTAPE 3 — Liaison Campus ↔ Centres
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${YELLOW}━━ ÉTAPE 3 : Liaison Campus ↔ Centres ━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Campus Paris-Saclay → Centre Saclay
link_faculty_to_centers "$FAC_PARIS_ID" "$CTR_SACLAY_ID"

# Campus Lyon → Centre Lyon + Centre Saclay (accès partagé aux labos scientifiques)
link_faculty_to_centers "$FAC_LYON_ID" "$CTR_LYON_ID" "$CTR_SACLAY_ID"

# Campus Bordeaux → Centre Maison des Arts
link_faculty_to_centers "$FAC_BORDEAUX_ID" "$CTR_BORDEAUX_ID"

# Campus Marseille → Centre Méditerranée + Centre Bordeaux (échanges Arts & Lettres)
link_faculty_to_centers "$FAC_MARSEILLE_ID" "$CTR_MARSEILLE_ID" "$CTR_BORDEAUX_ID"

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RÉSUMÉ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<SUMMARY

$(echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}")
$(echo -e "${GREEN}   ✅  SEED COMPLET TERMINÉ AVEC SUCCÈS !                       ${NC}")
$(echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}")

$(echo -e "  ${YELLOW}École 1 : Sciences & Technologies${NC} (ID:${SCHOOL1_ID})")
  ├── Campus Paris-Saclay (ID:${FAC_PARIS_ID})
  │   └── 🏢 Pôle Scientifique de Saclay (ID:${CTR_SACLAY_ID})
  │       ├── 🎓 Amphithéâtre Curie (120 places)
  │       ├── Salle de TD Newton (35 pl.)
  │       ├── Salle de TD Euler (35 pl.)
  │       ├── Labo Informatique (24 pl.)
  │       └── Salle réunion Pasteur (12 pl.)
  └── Campus Lyon Part-Dieu (ID:${FAC_LYON_ID})
      ├── 🏢 Espace Lyon Part-Dieu (ID:${CTR_LYON_ID})
      │   ├── Salle Lumière (40 pl.)
      │   ├── Salle Ampère (30 pl.)
      │   ├── Labo Physique-Chimie (20 pl.)
      │   └── Salle Informatique (28 pl.)
      └── 🔗 Pôle Scientifique de Saclay (partagé)

$(echo -e "  ${YELLOW}École 2 : Arts & Lettres${NC} (ID:${SCHOOL2_ID})")
  ├── Campus Bordeaux-Chartrons (ID:${FAC_BORDEAUX_ID})
  │   └── 🏢 Maison des Arts de Bordeaux (ID:${CTR_BORDEAUX_ID})
  │       ├── Atelier Peinture & Sculpture (25 pl.)
  │       ├── Studio Photographie (15 pl.)
  │       ├── Salle conf. Montaigne (60 pl.)
  │       └── Bibliothèque (40 pl.)
  └── Campus Marseille Vieux-Port (ID:${FAC_MARSEILLE_ID})
      ├── 🏢 Campus Méditerranée (ID:${CTR_MARSEILLE_ID})
      │   ├── Salle Cézanne (35 pl.)
      │   ├── Salle Pagnol (30 pl.)
      │   ├── Studio Musique & Son (18 pl.)
      │   ├── Salle de Danse (20 pl.)
      │   └── Espace Exposition (50 pl.)
      └── 🔗 Maison des Arts de Bordeaux (partagé)

SUMMARY
