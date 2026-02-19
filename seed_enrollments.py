#!/usr/bin/env python3
"""
seed_enrollments.py — Inscription des étudiants aux formules.

Répartition :
- Majorité inscrite définitivement (dernière étape = is_subscription)
- Reste réparti sur les étapes intermédiaires
- Certains inscrits avec réduction, d'autres sans

Formules par école :
- S&T (school=2) : FM2 Licence Sciences, FM3 Prépa Scientifique, FM4 Stage Labo
- A&L (school=3) : FM5 Licence Arts, FM6 Master Création
- Double cursus : une formule par école
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

# ============================================================================
# Configuration des formules
# ============================================================================
# school_id -> list of formulas available
# Each formula: id, steps (ordered), discounts (list of discount_ids)
FORMULAS = {
    2: {  # FM2: Licence Sciences L2-L3
        "id": 2,
        "name": "Licence Sciences — Cycle L2-L3",
        "steps": [12, 13, 14],  # Candidature → Admission → Inscription définitive
        "discounts": [2, 3, 4],  # Bourse mérite, Paiement comptant, Fratrie
    },
    3: {  # FM3: Prépa Scientifique
        "id": 3,
        "name": "Prépa Scientifique Intensive",
        "steps": [15, 16, 17],  # Candidature → Confirmation → Inscription
        "discounts": [5, 6],  # Paiement anticipé, Bourse excellence
    },
    4: {  # FM4: Stage Recherche
        "id": 4,
        "name": "Stage Recherche en Laboratoire",
        "steps": [18, 19, 20],  # Pré-inscription → Validation → Inscription
        "discounts": [7],  # Étudiant établissement
    },
    5: {  # FM5: Licence Arts
        "id": 5,
        "name": "Licence Arts Plastiques",
        "steps": [21, 22, 23],  # Candidature → Jury → Inscription
        "discounts": [8, 9, 10],  # Bourse talent, Paiement comptant, Fratrie
    },
    6: {  # FM6: Master Création
        "id": 6,
        "name": "Master Création Contemporaine",
        "steps": [24, 25, 26, 27],  # Candidature → Entretien → Choix options → Inscription
        "discounts": [11, 12, 13],  # Bourse recherche, Ancien étudiant, Paiement comptant
    },
}

# Formulas by school
SCHOOL_FORMULAS = {
    2: [FORMULAS[2], FORMULAS[3], FORMULAS[4]],  # S&T
    3: [FORMULAS[5], FORMULAS[6]],                # A&L
}

# ============================================================================
# API helpers
# ============================================================================

def get_all_students():
    r = requests.post(f"{API}/students/search", headers=HEADERS, json={"limit": 300})
    data = r.json()
    return data if isinstance(data, list) else data.get("data", data.get("students", []))


def enroll_student(student_id, formula_id):
    """Enroll student in formula. Returns student_formula_id or None."""
    r = requests.post(
        f"{API}/students/{student_id}/formulas",
        headers=HEADERS,
        json={"formulas": {"formula_id": formula_id}},
    )
    data = r.json()
    if "error" in data:
        return None
    # Response contains formulas array, find the one we just created
    formulas = data.get("formulas", [])
    if formulas:
        # Return the latest (highest sf_id)
        return max(f["student_formula_id"] for f in formulas)
    return None


def advance_step(student_id, sf_id, step_id):
    """Advance student formula to given step."""
    r = requests.patch(
        f"{API}/students/{student_id}/formulas/{sf_id}",
        headers=HEADERS,
        json={"step": {"formula_step_id": step_id}},
    )
    return r.status_code in (200, 201)


def add_discount(student_id, sf_id, formula_discount_id):
    """Add a discount to student formula."""
    r = requests.patch(
        f"{API}/students/{student_id}/formulas/{sf_id}",
        headers=HEADERS,
        json={"discounts": [{"formula_discount_id": formula_discount_id}]},
    )
    return r.status_code in (200, 201)


# ============================================================================
# Main enrollment logic
# ============================================================================

def enroll_students():
    print("=== Récupération des étudiants ===")
    students = get_all_students()
    print(f"  {len(students)} étudiants trouvés")

    # Categorize students by school
    st_only = []   # school_id = 2 only
    al_only = []   # school_id = 3 only
    double = []    # both schools

    for s in students:
        schools = s.get("schools", [])
        if 2 in schools and 3 in schools:
            double.append(s)
        elif 2 in schools:
            st_only.append(s)
        elif 3 in schools:
            al_only.append(s)

    print(f"  S&T uniquement: {len(st_only)}")
    print(f"  A&L uniquement: {len(al_only)}")
    print(f"  Double cursus: {len(double)}")
    print()

    # Shuffle for randomness
    random.shuffle(st_only)
    random.shuffle(al_only)
    random.shuffle(double)

    stats = {
        "total_enrollments": 0,
        "by_formula": {},
        "by_step": {},
        "with_discount": 0,
        "without_discount": 0,
    }

    def do_enroll(student, formula, target_step_idx, apply_discount):
        """Enroll one student in one formula, advance to target step, optionally add discount."""
        sid = student["id"]
        fm = formula
        fm_id = fm["id"]
        steps = fm["steps"]
        target_step = steps[target_step_idx]

        # Enroll (creates at step 1)
        sf_id = enroll_student(sid, fm_id)
        if sf_id is None:
            return False

        # Advance through steps up to target
        for step_idx in range(1, target_step_idx + 1):
            advance_step(sid, sf_id, steps[step_idx])

        # Apply discount
        if apply_discount and fm["discounts"]:
            discount_id = random.choice(fm["discounts"])
            add_discount(sid, sf_id, discount_id)
            stats["with_discount"] += 1
        else:
            stats["without_discount"] += 1

        stats["total_enrollments"] += 1
        fm_name = fm["name"]
        stats["by_formula"][fm_name] = stats["by_formula"].get(fm_name, 0) + 1
        step_name = f"Étape {target_step_idx + 1}/{len(steps)}"
        if target_step_idx == len(steps) - 1:
            step_name = "Inscrit définitivement"
        stats["by_step"][step_name] = stats["by_step"].get(step_name, 0) + 1

        return True

    def assign_step_and_discount(n_students, formula):
        """
        Returns list of (step_index, has_discount) tuples.
        ~65% inscrit définitivement (last step)
        ~20% étape intermédiaire
        ~15% première étape (candidature)
        ~30% avec réduction
        """
        assignments = []
        n_steps = len(formula["steps"])

        for i in range(n_students):
            r = random.random()
            if r < 0.65:
                step_idx = n_steps - 1  # Inscription définitive
            elif r < 0.85:
                # Intermediate steps
                if n_steps > 2:
                    step_idx = random.randint(1, n_steps - 2)
                else:
                    step_idx = 0
            else:
                step_idx = 0  # Candidature

            has_discount = random.random() < 0.30
            assignments.append((step_idx, has_discount))

        return assignments

    # ── S&T students ──
    print("=== Inscription étudiants S&T ===")
    # Distribute S&T students across 3 formulas: ~50% Licence, ~30% Prépa, ~20% Stage
    n_st = len(st_only)
    n_licence = int(n_st * 0.50)
    n_prepa = int(n_st * 0.30)
    n_stage = n_st - n_licence - n_prepa

    groups_st = [
        (st_only[:n_licence], FORMULAS[2], "Licence Sciences"),
        (st_only[n_licence:n_licence + n_prepa], FORMULAS[3], "Prépa Scientifique"),
        (st_only[n_licence + n_prepa:], FORMULAS[4], "Stage Recherche"),
    ]

    enrolled = 0
    for group, formula, label in groups_st:
        assignments = assign_step_and_discount(len(group), formula)
        for student, (step_idx, has_disc) in zip(group, assignments):
            ok = do_enroll(student, formula, step_idx, has_disc)
            enrolled += 1
            bar = "█" * (enrolled * 40 // n_st) + "░" * (40 - enrolled * 40 // n_st)
            sys.stdout.write(f"\r  [{bar}] {enrolled}/{n_st} S&T")
            sys.stdout.flush()
    print()

    # ── A&L students ──
    print("=== Inscription étudiants A&L ===")
    # Distribute A&L students: ~60% Licence Arts, ~40% Master Création
    n_al = len(al_only)
    n_arts = int(n_al * 0.60)
    n_master = n_al - n_arts

    groups_al = [
        (al_only[:n_arts], FORMULAS[5], "Licence Arts"),
        (al_only[n_arts:], FORMULAS[6], "Master Création"),
    ]

    enrolled = 0
    for group, formula, label in groups_al:
        assignments = assign_step_and_discount(len(group), formula)
        for student, (step_idx, has_disc) in zip(group, assignments):
            ok = do_enroll(student, formula, step_idx, has_disc)
            enrolled += 1
            bar = "█" * (enrolled * 40 // n_al) + "░" * (40 - enrolled * 40 // n_al)
            sys.stdout.write(f"\r  [{bar}] {enrolled}/{n_al} A&L")
            sys.stdout.flush()
    print()

    # ── Double cursus students ──
    print("=== Inscription étudiants double cursus ===")
    enrolled = 0
    for student in double:
        # One formula per school
        fm_st = random.choice(SCHOOL_FORMULAS[2])
        fm_al = random.choice(SCHOOL_FORMULAS[3])

        for fm in [fm_st, fm_al]:
            step_idx_final = len(fm["steps"]) - 1
            # Double cursus: 80% inscrits définitivement, 20% en cours
            if random.random() < 0.80:
                step_idx = step_idx_final
            else:
                step_idx = random.randint(0, step_idx_final - 1) if step_idx_final > 0 else 0
            has_disc = random.random() < 0.25
            do_enroll(student, fm, step_idx, has_disc)

        enrolled += 1
        bar = "█" * (enrolled * 40 // len(double)) + "░" * (40 - enrolled * 40 // len(double))
        sys.stdout.write(f"\r  [{bar}] {enrolled}/{len(double)} double cursus")
        sys.stdout.flush()
    print()
    print()

    # ── Summary ──
    print("=== RÉSUMÉ ===")
    print(f"  {stats['total_enrollments']} inscriptions au total")
    print()
    print("  Par formule :")
    for fm_name, count in sorted(stats["by_formula"].items()):
        print(f"    {fm_name}: {count}")
    print()
    print("  Par étape :")
    for step, count in sorted(stats["by_step"].items()):
        print(f"    {step}: {count}")
    print()
    print(f"  Avec réduction : {stats['with_discount']}")
    print(f"  Sans réduction : {stats['without_discount']}")
    print()
    print("=== DONE ===")


if __name__ == "__main__":
    enroll_students()
