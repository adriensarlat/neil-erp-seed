#!/usr/bin/env python3
"""
seed_groups.py — Création des ensembles de classes et classes par formation.
Affecte les étudiants inscrits définitivement aux différentes classes.

Logique d'affectation :
- Récupère les étudiants inscrits définitivement par formule
- Résout la correspondance formule → set → formation en tenant compte du min/max
  - Sets obligatoires (min=max=1) : tous les étudiants de la formule
  - Sets optionnels (min<max) : répartition aléatoire réaliste
- Adapte la structure des groupes à l'effectif réel de chaque formation

Structure des groupes :
- Grandes formations (40+) : Classes CM + Groupes TD + Groupes TP
- Formations moyennes (20-40) : Classe unique + Groupes TD/Atelier
- Petites formations (<20) : Groupes spécialisés uniquement
"""
import requests
import json
import random
import sys

API = "https://neil-claude.erp.neil.app/api"
HEADERS = {
    "X-Lucius-Api-Key": "LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww",
    "Content-Type": "application/json",
}

random.seed(42)

COLORS = [
    "#e74c3c", "#3498db", "#2ecc71", "#f39c12", "#9b59b6",
    "#1abc9c", "#e67e22", "#34495e", "#16a085", "#c0392b",
    "#2980b9", "#27ae60", "#d35400", "#8e44ad",
]

# ============================================================================
# API helpers
# ============================================================================

def get_formula_students(formula_id):
    """Get all students enrolled at the final step (inscrits définitivement)."""
    r = requests.get(f"{API}/formulas/{formula_id}/students", headers=HEADERS)
    data = r.json()
    inscrits = []
    for step in data["step_students"]:
        if step.get("is_subscription"):
            inscrits = [s["id"] for s in step.get("students", [])]
    return inscrits


def get_formula_sets(formula_id):
    """Get the sets (with formations) for a formula."""
    r = requests.get(f"{API}/formulas/{formula_id}/sets", headers=HEADERS)
    return r.json().get("sets", [])


def get_existing_group_sets(formation_id):
    """Get existing group-sets and groups for a formation."""
    r = requests.get(f"{API}/formations/{formation_id}/groups", headers=HEADERS)
    data = r.json()
    return data.get("groups", [])


def rename_group_set(formation_id, gs_id, name):
    r = requests.patch(
        f"{API}/formations/{formation_id}/group-sets/{gs_id}",
        headers=HEADERS,
        json={"name": name},
    )
    return r.status_code in (200, 201)


def create_group_set(formation_id, name):
    r = requests.post(
        f"{API}/formations/{formation_id}/group-sets",
        headers=HEADERS,
        json={"name": name},
    )
    data = r.json()
    return data["id"]


def create_group(formation_id, group_set_id, name, color, capacity):
    r = requests.post(
        f"{API}/formations/{formation_id}/groups",
        headers=HEADERS,
        json={"groups": {"name": name, "group_set_id": group_set_id, "color": color, "capacity": capacity}},
    )
    data = r.json()
    if isinstance(data, list) and len(data) > 0:
        return data[0]["id"]
    return None


def assign_students_to_group(formation_id, group_id, student_ids):
    if not student_ids:
        return
    r = requests.post(
        f"{API}/formations/{formation_id}/groups/{group_id}/students",
        headers=HEADERS,
        json={"students": [{"student_id": sid} for sid in student_ids]},
    )
    return r.status_code in (200, 201)


def split_students(student_ids, n_groups):
    """Split students evenly into n groups."""
    shuffled = list(student_ids)
    random.shuffle(shuffled)
    groups = [[] for _ in range(n_groups)]
    for i, sid in enumerate(shuffled):
        groups[i % n_groups].append(sid)
    return groups


# ============================================================================
# Resolve students per formation from formula sets
# ============================================================================

def resolve_formation_students():
    """
    For each formation, determine which students are actually enrolled,
    based on formula sets min/max logic.

    Returns dict: formation_id -> list of student_ids
    """
    formation_students = {}

    # Formula -> sets mapping
    # FM2 -> Set1(F10, min1/max1)
    # FM3 -> Set2(F11, 1/1), Set3(F12, 1/1)
    # FM4 -> Set4(F13, 1/1)
    # FM5 -> Set5(F14, 1/1), Set6(F15, 1/1)
    # FM6 -> Set7(F16, 1/1), Set8(F17+F18, min1/max2)

    for fm_id in [2, 3, 4, 5, 6]:
        students = get_formula_students(fm_id)
        sets = get_formula_sets(fm_id)

        print(f"  FM{fm_id}: {len(students)} inscrits définitivement, {len(sets)} sets")

        for s in sets:
            set_min = s.get("min", 1)
            set_max = s.get("max", 1)
            formations = [f["id"] for f in s.get("formations", [])]

            if set_min == set_max == 1 and len(formations) == 1:
                # Obligatoire, une seule formation : tous les étudiants
                fid = formations[0]
                formation_students[fid] = list(students)
                print(f"    Set '{s['name']}' (obligatoire) → F{fid}: {len(students)} étudiants")

            elif set_max > 1 and len(formations) > 1:
                # Set optionnel avec choix (ex: FM6 Options min:1, max:2)
                # Répartition réaliste :
                # ~60% prennent toutes les options (max)
                # ~40% restants répartis aléatoirement sur une seule option
                shuffled = list(students)
                random.shuffle(shuffled)

                n_both = int(len(shuffled) * 0.60)
                rest = shuffled[n_both:]

                # Initialiser les listes
                for fid in formations:
                    formation_students.setdefault(fid, [])

                # 60% dans toutes les formations du set
                for fid in formations:
                    formation_students[fid].extend(shuffled[:n_both])

                # 40% restants : chacun choisit une option aléatoire
                for sid in rest:
                    chosen = random.choice(formations)
                    formation_students[chosen].append(sid)

                for fid in formations:
                    print(f"    Set '{s['name']}' (optionnel, {set_min}-{set_max}) → F{fid}: {len(formation_students[fid])} étudiants")

            elif len(formations) == 1:
                # Obligatoire avec une seule formation (même si min!=max, tous y vont)
                fid = formations[0]
                formation_students[fid] = list(students)
                print(f"    Set '{s['name']}' → F{fid}: {len(students)} étudiants")

    return formation_students


# ============================================================================
# Formation group structures (adapted dynamically)
# ============================================================================

def build_group_plan(formation_students):
    """
    Build group structure per formation, adapted to actual student count.
    """
    plan = {}

    for fid, students in sorted(formation_students.items()):
        n = len(students)

        if fid == 10:
            # Tronc commun Sciences L2-L3
            plan[fid] = {"sets": [
                {"name": "Classes", "groups": [
                    {"name": "Classe A", "capacity": (n // 2) + 2},
                    {"name": "Classe B", "capacity": (n // 2) + 2},
                ]},
                {"name": "Groupes de TD", "groups": [
                    {"name": "TD 1", "capacity": (n // 3) + 2},
                    {"name": "TD 2", "capacity": (n // 3) + 2},
                    {"name": "TD 3", "capacity": (n // 3) + 2},
                ]},
                {"name": "Groupes de TP", "groups": [
                    {"name": "TP 1", "capacity": (n // 4) + 2},
                    {"name": "TP 2", "capacity": (n // 4) + 2},
                    {"name": "TP 3", "capacity": (n // 4) + 2},
                    {"name": "TP 4", "capacity": (n // 4) + 2},
                ]},
            ]}

        elif fid == 11:
            plan[fid] = {"sets": [
                {"name": "Classe", "groups": [
                    {"name": "Prépa T1", "capacity": n + 5},
                ]},
                {"name": "Groupes de TD", "groups": [
                    {"name": "TD 1", "capacity": (n // 2) + 2},
                    {"name": "TD 2", "capacity": (n // 2) + 2},
                ]},
            ]}

        elif fid == 12:
            plan[fid] = {"sets": [
                {"name": "Classe", "groups": [
                    {"name": "Prépa T2", "capacity": n + 5},
                ]},
                {"name": "Groupes de TD", "groups": [
                    {"name": "TD 1", "capacity": (n // 2) + 2},
                    {"name": "TD 2", "capacity": (n // 2) + 2},
                ]},
            ]}

        elif fid == 13:
            plan[fid] = {"sets": [
                {"name": "Groupes de laboratoire", "groups": [
                    {"name": "Labo Physique", "capacity": (n // 2) + 2},
                    {"name": "Labo Chimie", "capacity": (n // 2) + 2},
                ]},
            ]}

        elif fid == 14:
            plan[fid] = {"sets": [
                {"name": "Classes", "groups": [
                    {"name": "Classe A", "capacity": (n // 2) + 2},
                    {"name": "Classe B", "capacity": (n // 2) + 2},
                ]},
                {"name": "Groupes de TD", "groups": [
                    {"name": "TD 1", "capacity": (n // 3) + 2},
                    {"name": "TD 2", "capacity": (n // 3) + 2},
                    {"name": "TD 3", "capacity": (n // 3) + 2},
                ]},
            ]}

        elif fid == 15:
            plan[fid] = {"sets": [
                {"name": "Ateliers", "groups": [
                    {"name": "Atelier Dessin-Peinture", "capacity": (n // 3) + 2},
                    {"name": "Atelier Sculpture-Volume", "capacity": (n // 3) + 2},
                    {"name": "Atelier Arts numériques", "capacity": (n // 3) + 2},
                ]},
                {"name": "Groupes de TP", "groups": [
                    {"name": "TP 1", "capacity": (n // 4) + 2},
                    {"name": "TP 2", "capacity": (n // 4) + 2},
                    {"name": "TP 3", "capacity": (n // 4) + 2},
                    {"name": "TP 4", "capacity": (n // 4) + 2},
                ]},
            ]}

        elif fid == 16:
            plan[fid] = {"sets": [
                {"name": "Promotion", "groups": [
                    {"name": "Master 1 Création", "capacity": n + 5},
                ]},
                {"name": "Ateliers de création", "groups": [
                    {"name": "Atelier Arts visuels", "capacity": (n // 2) + 2},
                    {"name": "Atelier Arts vivants", "capacity": (n // 2) + 2},
                ]},
            ]}

        elif fid == 17:
            plan[fid] = {"sets": [
                {"name": "Groupes de projet", "groups": [
                    {"name": "Projet Installation", "capacity": (n // 3) + 2},
                    {"name": "Projet Performance", "capacity": (n // 3) + 2},
                    {"name": "Projet Numérique", "capacity": (n // 3) + 2},
                ]},
            ]}

        elif fid == 18:
            plan[fid] = {"sets": [
                {"name": "Groupes de recherche", "groups": [
                    {"name": "Recherche Matériaux", "capacity": (n // 3) + 2},
                    {"name": "Recherche Image", "capacity": (n // 3) + 2},
                    {"name": "Recherche Son-Espace", "capacity": (n // 3) + 2},
                ]},
            ]}

    return plan


# ============================================================================
# Main
# ============================================================================

def seed_groups():
    print("=== RÉSOLUTION DES ÉTUDIANTS PAR FORMATION ===")
    formation_students = resolve_formation_students()

    print(f"\n=== EFFECTIFS PAR FORMATION ===")
    for fid in sorted(formation_students.keys()):
        print(f"  F{fid}: {len(formation_students[fid])} étudiants")

    plan = build_group_plan(formation_students)
    color_idx = 0

    print("\n=== CRÉATION DES CLASSES ===")
    for fid in sorted(plan.keys()):
        config = plan[fid]
        students = formation_students[fid]

        print(f"\nFormation {fid} ({len(students)} étudiants)")

        # Get existing group-sets (rename default one for first set)
        existing_gs = get_existing_group_sets(fid)
        default_gs_id = None
        for gs in existing_gs:
            if gs["name"] == "Ensemble de classes par défaut":
                default_gs_id = gs["id"]
                break

        for set_idx, gs_config in enumerate(config["sets"]):
            gs_name = gs_config["name"]

            # First set: rename the default group-set
            if set_idx == 0 and default_gs_id:
                rename_group_set(fid, default_gs_id, gs_name)
                gs_id = default_gs_id
                print(f"  Ensemble: {gs_name} (renommé, id={gs_id})")
            else:
                gs_id = create_group_set(fid, gs_name)
                print(f"  Ensemble: {gs_name} (id={gs_id})")

            # Create groups and assign students
            n_groups = len(gs_config["groups"])
            student_splits = split_students(students, n_groups)

            for grp_idx, grp_config in enumerate(gs_config["groups"]):
                color = COLORS[color_idx % len(COLORS)]
                color_idx += 1

                grp_id = create_group(fid, gs_id, grp_config["name"], color, grp_config["capacity"])
                if grp_id is None:
                    print(f"    ERREUR création groupe {grp_config['name']}")
                    continue

                grp_students = student_splits[grp_idx]
                assign_students_to_group(fid, grp_id, grp_students)
                print(f"    {grp_config['name']}: {len(grp_students)} étudiants (id={grp_id})")

    # Summary
    total_sets = sum(len(c["sets"]) for c in plan.values())
    total_groups = sum(len(g) for c in plan.values() for gs in c["sets"] for g in [gs["groups"]])
    print(f"\n=== RÉSUMÉ ===")
    print(f"  {len(plan)} formations")
    print(f"  {total_sets} ensembles de classes")
    print(f"  {total_groups} classes au total")
    print(f"=== DONE ===")


if __name__ == "__main__":
    seed_groups()
