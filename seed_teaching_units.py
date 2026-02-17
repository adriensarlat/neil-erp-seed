#!/usr/bin/env python3
"""
seed_teaching_units.py — Création des UE, sous-UE et modules (cours) pour chaque formation.
Chaque module = 1 cours de 1h, 2h ou 4h.
Le total des heures de modules couvre la durée prévue de la formation.
"""
import requests
import json
import sys
import math

API = "https://neil-claude.erp.neil.app/api"
HEADERS = {
    "X-Lucius-Api-Key": "LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww",
    "Content-Type": "application/json",
}

# Formation durations in hours (from seed_formulas.sh: duration in seconds / 3600)
FORMATION_HOURS = {
    10: 1200, 11: 200, 12: 200, 13: 140,
    14: 400, 15: 300, 16: 400, 17: 100, 18: 140,
}

# ============================================================================
# API helpers
# ============================================================================

def get_modules(fid):
    r = requests.get(f"{API}/formations/{fid}/modules", headers=HEADERS)
    return r.json()

def delete_module(fid, module_id):
    r = requests.delete(f"{API}/formations/{fid}/modules/{module_id}", headers=HEADERS)
    return r.status_code

def delete_ue(fid, node_id):
    r = requests.delete(f"{API}/formations/{fid}/teaching-units/{node_id}", headers=HEADERS)
    return r.status_code

def create_ue(fid, name, order, parent_node_id=None):
    body = {"unit": name, "order": order}
    if parent_node_id is not None:
        body["parent_node_id"] = parent_node_id
    r = requests.post(f"{API}/formations/{fid}/teaching-units", headers=HEADERS, json=body)
    data = r.json()
    return data["node"]["id"]

def create_module(fid, parent_node_id, name, order):
    body = {
        "modules": {"name": name},
        "parent_node_id": parent_node_id,
        "order": order,
        "is_active": True,
    }
    r = requests.post(f"{API}/formations/{fid}/modules", headers=HEADERS, json=body)
    data = r.json()
    if isinstance(data, list) and len(data) > 0:
        return data[0]["id"]
    elif isinstance(data, dict) and "id" in data:
        return data["id"]
    return None

def set_module_duration(fid, module_id, duration_seconds):
    requests.patch(
        f"{API}/formations/{fid}/modules/{module_id}",
        headers=HEADERS,
        json={"default_duration": duration_seconds},
    )

# ============================================================================
# Cleanup
# ============================================================================

def cleanup_formation(fid):
    data = get_modules(fid)
    modules = data.get("modules", [])
    nodes = data.get("nodes", [])

    for m in modules:
        delete_module(fid, m["id"])
    print(f"  Deleted {len(modules)} modules")

    for _ in range(5):
        data = get_modules(fid)
        nodes = data.get("nodes", [])
        ue_nodes = [n for n in nodes if n.get("unit") and n["unit"] != "Unité d'enseignement par défaut"]
        if not ue_nodes:
            break
        ue_nodes.sort(key=lambda n: len((n.get("path") or "").split("/")), reverse=True)
        for n in ue_nodes:
            delete_ue(fid, n["id"])

    print(f"  Cleanup complete")

def cleanup_all():
    print("=== CLEANUP ===")
    for fid in range(10, 19):
        print(f"Formation {fid}:")
        cleanup_formation(fid)
    print()

# ============================================================================
# Helper: distribute hours across sub-UEs proportionally
# ============================================================================

def distribute_hours(ues_definition, target_hours):
    """
    ues_definition: list of UEs, each with sub_ues, each with a list of course
    names and a 'weight' for proportional distribution.
    Returns the same structure but with (name, hours) tuples as modules.
    """
    # Each sub-UE has a weight = number of base courses * typical hours
    # We distribute target_hours proportionally across all sub-UEs
    total_weight = 0
    for ue in ues_definition:
        for sub in ue["sub_ues"]:
            total_weight += sub["weight"]

    result = []
    assigned_total = 0
    all_subs = []

    for ue in ues_definition:
        ue_result = {"name": ue["name"], "sub_ues": []}
        for sub in ue["sub_ues"]:
            sub_hours = round(target_hours * sub["weight"] / total_weight)
            # Ensure at least as many hours as courses (1h min per course)
            sub_hours = max(sub_hours, len(sub["courses"]))
            all_subs.append((ue_result, sub, sub_hours))
            assigned_total += sub_hours
        result.append(ue_result)

    # Adjust to match target exactly
    diff = target_hours - assigned_total
    # Distribute diff across largest sub-UEs
    all_subs.sort(key=lambda x: x[2], reverse=True)
    i = 0
    while diff != 0:
        step = 2 if abs(diff) > len(all_subs) else (1 if diff > 0 else -1)
        if diff > 0:
            all_subs[i % len(all_subs)] = (all_subs[i % len(all_subs)][0], all_subs[i % len(all_subs)][1], all_subs[i % len(all_subs)][2] + step)
            diff -= step
        else:
            idx = i % len(all_subs)
            if all_subs[idx][2] > len(all_subs[idx][1]["courses"]):
                all_subs[idx] = (all_subs[idx][0], all_subs[idx][1], all_subs[idx][2] - 1)
                diff += 1
        i += 1
        if i > 1000:
            break

    # Now generate modules for each sub-UE
    for ue_result, sub, sub_hours in all_subs:
        modules = generate_modules(sub["courses"], sub_hours)
        sub_result = {"name": sub["name"], "modules": modules}
        ue_result["sub_ues"].append(sub_result)

    return result


def generate_modules(courses, target_hours):
    """
    Given a list of course names and a target total hours,
    generate modules of 1h, 2h, or 4h to fill the hours.
    When a course needs multiple slots, uses pedagogical labels:
    Cours 1, Cours 2... for regular courses; TP 1, TP 2... for TP courses;
    TD 1, TD 2... for TD courses.
    """
    n_courses = len(courses)
    if n_courses == 0:
        return []

    # Base allocation: distribute hours across courses
    base_per_course = target_hours // n_courses
    remainder = target_hours % n_courses

    modules = []
    for i, course in enumerate(courses):
        course_hours = base_per_course + (1 if i < remainder else 0)
        if course_hours <= 0:
            continue

        # Split into sessions of 4h, 2h, 1h
        sessions = []
        remaining = course_hours
        session_num = 1

        while remaining > 0:
            if remaining >= 4:
                h = 4
            elif remaining >= 2:
                h = 2
            else:
                h = 1
            sessions.append((session_num, h))
            remaining -= h
            session_num += 1

        # Name sessions with pedagogical labels
        if len(sessions) == 1:
            modules.append((course, sessions[0][1]))
        else:
            # Determine label based on course name prefix
            lower = course.lower()
            if lower.startswith("tp "):
                label = "TP"
            elif lower.startswith("td "):
                label = "TD"
            elif lower.startswith("projet"):
                label = "Projet"
            elif lower.startswith("atelier"):
                label = "Atelier"
            elif lower.startswith("stage") or lower.startswith("résidence"):
                label = "Journée"
            elif lower.startswith("concours"):
                label = "Session"
            elif lower.startswith("colles"):
                label = "Colle"
            else:
                label = "Cours"
            for num, h in sessions:
                modules.append((f"{course} — {label} {num}", h))

    return modules


# ============================================================================
# Formation structures
# Each sub-UE has: name, courses (list of course names), weight (relative hours)
# ============================================================================

def build_structures():
    S = {}

    # =========================================================================
    # F10: Tronc commun Sciences L2-L3 — 1200h
    # =========================================================================
    S[10] = [
        {"name": "UE1 — Mathématiques", "sub_ues": [
            {"name": "Analyse", "weight": 60, "courses": [
                "Analyse réelle", "Analyse complexe", "Suites et séries numériques",
                "Intégrales multiples", "Équations différentielles ordinaires",
                "Équations aux dérivées partielles", "Analyse numérique",
                "Analyse fonctionnelle", "Mesure et intégration",
                "TD Analyse", "TP Analyse numérique",
            ]},
            {"name": "Algèbre", "weight": 48, "courses": [
                "Algèbre linéaire", "Algèbre bilinéaire", "Groupes et anneaux",
                "Espaces vectoriels normés", "Réduction des endomorphismes",
                "Algèbre commutative", "TD Algèbre", "TP Calcul formel",
            ]},
            {"name": "Probabilités et Statistiques", "weight": 44, "courses": [
                "Probabilités discrètes", "Probabilités continues", "Variables aléatoires",
                "Statistiques descriptives", "Statistiques inférentielles",
                "Tests d'hypothèses", "Régression linéaire",
                "TD Probabilités", "TP Statistiques R",
            ]},
        ]},
        {"name": "UE2 — Physique", "sub_ues": [
            {"name": "Mécanique", "weight": 56, "courses": [
                "Cinématique du point", "Dynamique du point", "Énergie et travail",
                "Mécanique du solide", "Mécanique analytique", "Mécanique des fluides",
                "Oscillations et ondes mécaniques",
                "TD Mécanique", "TP Mécanique",
            ]},
            {"name": "Électromagnétisme", "weight": 48, "courses": [
                "Électrostatique", "Magnétostatique", "Induction électromagnétique",
                "Ondes électromagnétiques", "Circuits en régime continu",
                "Circuits en régime sinusoïdal", "Électronique analogique",
                "TD Électromagnétisme", "TP Électronique",
            ]},
            {"name": "Thermodynamique et Optique", "weight": 44, "courses": [
                "Premier principe", "Second principe", "Machines thermiques",
                "Transferts thermiques", "Optique géométrique",
                "Optique ondulatoire", "Interférences et diffraction",
                "TD Thermodynamique", "TP Optique",
            ]},
        ]},
        {"name": "UE3 — Informatique", "sub_ues": [
            {"name": "Algorithmique et Programmation", "weight": 52, "courses": [
                "Algorithmique fondamentale", "Programmation Python",
                "Programmation C", "Programmation orientée objet",
                "Structures de données", "Complexité algorithmique",
                "TP Python avancé", "TP C avancé", "Projet programmation",
            ]},
            {"name": "Systèmes et Réseaux", "weight": 40, "courses": [
                "Architecture des ordinateurs", "Systèmes d'exploitation Unix",
                "Réseaux et protocoles TCP/IP", "Administration système Linux",
                "Sécurité informatique", "TP Systèmes", "TP Réseaux",
            ]},
            {"name": "Bases de données et Web", "weight": 40, "courses": [
                "Modèle relationnel", "SQL et requêtes avancées",
                "Conception de bases de données", "NoSQL et Big Data",
                "Développement web front-end", "Développement web back-end",
                "TP SQL", "Projet web",
            ]},
        ]},
        {"name": "UE4 — Sciences de l'ingénieur", "sub_ues": [
            {"name": "Conception et Matériaux", "weight": 44, "courses": [
                "Résistance des matériaux", "Science des matériaux",
                "CAO — Conception assistée", "Fabrication numérique",
                "Impression 3D et prototypage", "Métrologie",
                "TP Matériaux", "Projet CAO",
            ]},
            {"name": "Automatique et Signal", "weight": 36, "courses": [
                "Traitement du signal analogique", "Traitement du signal numérique",
                "Automatique linéaire continue", "Automatique discrète",
                "Systèmes asservis", "TP Signal", "TP Automatique",
            ]},
        ]},
        {"name": "UE5 — Transversales", "sub_ues": [
            {"name": "Langues et Communication", "weight": 36, "courses": [
                "Anglais scientifique S1", "Anglais scientifique S2",
                "Anglais scientifique S3", "Anglais scientifique S4",
                "Anglais oral et TOEIC", "Communication écrite",
                "Communication orale et présentation",
                "Rédaction technique", "LV2 facultative",
            ]},
            {"name": "Projets et Professionnalisation", "weight": 52, "courses": [
                "Projet tutoré S1", "Projet tutoré S2",
                "Projet tutoré S3", "Projet tutoré S4",
                "Projet intégrateur", "Gestion de projet",
                "Méthodologie de travail scientifique",
                "Insertion professionnelle", "Connaissance de l'entreprise",
                "Droit du travail", "Éthique scientifique", "Stage d'observation",
            ]},
        ]},
    ]

    # =========================================================================
    # F11: Prépa Scientifique T1 Fondamentaux — 200h
    # =========================================================================
    S[11] = [
        {"name": "UE1 — Mathématiques fondamentales", "sub_ues": [
            {"name": "Calcul et Analyse", "weight": 28, "courses": [
                "Calcul différentiel", "Suites numériques", "Intégration",
                "Fonctions de plusieurs variables", "Développements limités",
                "TD Calcul",
            ]},
            {"name": "Géométrie", "weight": 20, "courses": [
                "Géométrie euclidienne", "Géométrie affine",
                "Nombres complexes et géométrie", "TD Géométrie",
            ]},
        ]},
        {"name": "UE2 — Physique fondamentale", "sub_ues": [
            {"name": "Mécanique", "weight": 24, "courses": [
                "Mécanique du point", "Cinématique", "Énergie et travail",
                "TP Mécanique", "TD Mécanique",
            ]},
            {"name": "Optique", "weight": 22, "courses": [
                "Optique géométrique", "Lentilles et miroirs",
                "Optique ondulatoire", "TP Optique",
            ]},
        ]},
        {"name": "UE3 — Chimie", "sub_ues": [
            {"name": "Chimie générale", "weight": 24, "courses": [
                "Atomistique", "Liaisons chimiques", "Thermochimie",
                "Cinétique chimique", "Équilibres chimiques",
            ]},
            {"name": "Travaux pratiques", "weight": 20, "courses": [
                "TP Chimie organique", "TP Chimie analytique",
                "TP Dosages", "TP Synthèse",
            ]},
        ]},
        {"name": "UE4 — Méthodologie", "sub_ues": [
            {"name": "Compétences transversales", "weight": 18, "courses": [
                "Méthodologie scientifique", "Expression écrite",
                "Expression orale", "Anglais", "Culture générale scientifique",
            ]},
        ]},
    ]

    # =========================================================================
    # F12: Prépa Scientifique T2 Approfondissement — 200h
    # =========================================================================
    S[12] = [
        {"name": "UE1 — Mathématiques approfondies", "sub_ues": [
            {"name": "Analyse avancée", "weight": 28, "courses": [
                "Analyse complexe", "Séries de Fourier", "Séries entières",
                "Équations différentielles", "Intégrales à paramètre",
                "TD Analyse avancée",
            ]},
            {"name": "Algèbre avancée", "weight": 20, "courses": [
                "Algèbre bilinéaire", "Polynômes", "Fractions rationnelles",
                "Espaces préhilbertiens", "TD Algèbre avancée",
            ]},
        ]},
        {"name": "UE2 — Physique approfondie", "sub_ues": [
            {"name": "Électrocinétique", "weight": 24, "courses": [
                "Circuits RC RL RLC", "Régime sinusoïdal forcé",
                "Filtrage analogique", "TP Électrocinétique", "TD Circuits",
            ]},
            {"name": "Mécanique des fluides", "weight": 24, "courses": [
                "Statique des fluides", "Dynamique des fluides parfaits",
                "Dynamique des fluides visqueux", "TP Fluides", "TD Fluides",
            ]},
        ]},
        {"name": "UE3 — Sciences de l'ingénieur", "sub_ues": [
            {"name": "Informatique", "weight": 22, "courses": [
                "Introduction à Python", "Algorithmique de base",
                "Structures de données simples", "TP Informatique", "Projet Python",
            ]},
            {"name": "Sciences industrielles", "weight": 18, "courses": [
                "Cinématique des mécanismes", "Statique des solides",
                "Asservissement", "TP Sciences industrielles",
            ]},
        ]},
        {"name": "UE4 — Préparation concours", "sub_ues": [
            {"name": "Entraînement intensif", "weight": 20, "courses": [
                "Colles mathématiques", "Colles physique", "Colles chimie",
                "Concours blanc 1", "Concours blanc 2", "Concours blanc 3",
                "Correction et méthodologie",
            ]},
        ]},
    ]

    # =========================================================================
    # F13: Stage Recherche en Laboratoire — 140h
    # =========================================================================
    S[13] = [
        {"name": "UE1 — Méthodologie de recherche", "sub_ues": [
            {"name": "Rédaction scientifique", "weight": 18, "courses": [
                "Rédaction d'articles", "Structure d'un article",
                "Bibliographie et sources", "Normes de publication",
                "Atelier d'écriture scientifique",
            ]},
            {"name": "Éthique et intégrité", "weight": 14, "courses": [
                "Éthique de la recherche", "Intégrité scientifique",
                "Propriété intellectuelle", "Études de cas éthiques",
            ]},
        ]},
        {"name": "UE2 — Travail en laboratoire", "sub_ues": [
            {"name": "Protocoles expérimentaux", "weight": 22, "courses": [
                "Conception de protocoles", "Sécurité au laboratoire",
                "Techniques de mesure", "Instrumentation avancée",
                "Gestion des échantillons", "Métrologie",
            ]},
            {"name": "Analyse et restitution", "weight": 26, "courses": [
                "Analyse de données expérimentales", "Statistiques appliquées",
                "Logiciels d'analyse", "Présentation de résultats",
                "Poster scientifique", "Cahier de laboratoire",
                "Rapport de stage", "Soutenance de stage",
            ]},
        ]},
    ]

    # =========================================================================
    # F14: Histoire de l'art — Enseignements théoriques — 400h
    # =========================================================================
    S[14] = [
        {"name": "UE1 — Histoire de l'art ancien", "sub_ues": [
            {"name": "Antiquité", "weight": 24, "courses": [
                "Art égyptien", "Art mésopotamien", "Art grec archaïque",
                "Art grec classique", "Art hellénistique", "Art romain",
                "Archéologie et patrimoine", "TD Antiquité",
            ]},
            {"name": "Moyen Âge et Renaissance", "weight": 28, "courses": [
                "Art paléochrétien et byzantin", "Art roman",
                "Art gothique", "Enluminure médiévale",
                "Renaissance italienne — Quattrocento", "Renaissance italienne — Cinquecento",
                "Renaissance nordique", "Maniérisme",
                "TD Moyen Âge et Renaissance",
            ]},
            {"name": "Baroque et Classicisme", "weight": 20, "courses": [
                "Art baroque italien", "Baroque espagnol",
                "Classicisme français", "Peinture hollandaise du Siècle d'or",
                "Architecture baroque", "TD Baroque et Classicisme",
            ]},
        ]},
        {"name": "UE2 — Histoire de l'art moderne", "sub_ues": [
            {"name": "XIXe siècle", "weight": 28, "courses": [
                "Néoclassicisme", "Romantisme", "Réalisme",
                "Impressionnisme", "Post-impressionnisme", "Nabis et Symbolisme",
                "Art nouveau", "Photographie au XIXe",
                "TD XIXe siècle",
            ]},
            {"name": "XXe siècle et contemporain", "weight": 32, "courses": [
                "Fauvisme", "Expressionnisme", "Cubisme",
                "Futurisme et Constructivisme", "Dadaïsme", "Surréalisme",
                "Expressionnisme abstrait", "Pop Art",
                "Minimalisme", "Art conceptuel",
                "Land Art et Arte Povera", "TD XXe siècle",
            ]},
        ]},
        {"name": "UE3 — Esthétique et philosophie", "sub_ues": [
            {"name": "Esthétique", "weight": 24, "courses": [
                "Esthétique antique", "Esthétique classique",
                "Esthétique moderne", "Esthétique contemporaine",
                "Le beau et le sublime", "Philosophie de l'art",
                "TD Esthétique",
            ]},
            {"name": "Sémiologie", "weight": 20, "courses": [
                "Sémiologie de l'image", "Analyse iconographique",
                "Sémiologie visuelle", "Sémiotique de l'art contemporain",
                "TD Sémiologie",
            ]},
        ]},
        {"name": "UE4 — Méthodologie et Langues", "sub_ues": [
            {"name": "Analyse d'œuvres", "weight": 28, "courses": [
                "Analyse de peinture", "Analyse de sculpture",
                "Analyse d'architecture", "Analyse de photographie",
                "Analyse d'arts décoratifs", "Commentaire d'œuvre",
                "Dissertation", "TD Analyse",
            ]},
            {"name": "Recherche et Langues", "weight": 20, "courses": [
                "Recherche documentaire", "Méthodologie universitaire",
                "Anglais de spécialité S1", "Anglais de spécialité S2",
                "Allemand ou Espagnol", "Rédaction académique",
            ]},
        ]},
    ]

    # =========================================================================
    # F15: Ateliers pratiques — Arts plastiques — 300h
    # =========================================================================
    S[15] = [
        {"name": "UE1 — Dessin", "sub_ues": [
            {"name": "Observation et Technique", "weight": 24, "courses": [
                "Dessin d'observation", "Dessin de modèle vivant",
                "Croquis rapide et carnet", "Nature morte",
                "Dessin au fusain", "Dessin à l'encre", "Dessin au crayon",
            ]},
            {"name": "Perspectives et Volumes", "weight": 20, "courses": [
                "Perspective linéaire", "Perspective atmosphérique",
                "Dessin de volumes", "Dessin d'architecture",
                "Projet dessin",
            ]},
        ]},
        {"name": "UE2 — Peinture et couleur", "sub_ues": [
            {"name": "Techniques picturales", "weight": 24, "courses": [
                "Peinture acrylique", "Peinture à l'huile",
                "Aquarelle", "Techniques mixtes",
                "Atelier peinture grand format", "Peinture abstraite",
            ]},
            {"name": "Théorie de la couleur", "weight": 16, "courses": [
                "Colorimétrie", "Harmonie des couleurs",
                "Couleur et lumière", "Exercices chromatiques",
            ]},
        ]},
        {"name": "UE3 — Sculpture et volume", "sub_ues": [
            {"name": "Modelage et Moulage", "weight": 22, "courses": [
                "Modelage argile", "Moulage plâtre", "Modelage cire",
                "Taille directe", "Assemblage", "Atelier modelage libre",
            ]},
            {"name": "Installation et Espace", "weight": 18, "courses": [
                "Installation in situ", "Art et espace public",
                "Scénographie", "Projet installation", "Land art",
            ]},
        ]},
        {"name": "UE4 — Arts numériques", "sub_ues": [
            {"name": "Photographie", "weight": 20, "courses": [
                "Photographie numérique", "Retouche photo",
                "Studio photo", "Reportage photographique",
                "Photographie argentique",
            ]},
            {"name": "Création numérique", "weight": 24, "courses": [
                "PAO — Mise en page", "Illustration vectorielle",
                "Vidéo et montage", "Animation 2D",
                "Création 3D", "Projet numérique",
            ]},
        ]},
    ]

    # =========================================================================
    # F16: Master Création Contemporaine — Tronc commun — 400h
    # =========================================================================
    S[16] = [
        {"name": "UE1 — Théories de la création", "sub_ues": [
            {"name": "Art et Société", "weight": 22, "courses": [
                "Art et société contemporaine", "Sociologie de l'art",
                "Art et politique", "Art et mondialisation",
                "Conférences invités", "TD Art et société",
            ]},
            {"name": "Théories critiques", "weight": 20, "courses": [
                "Théories critiques contemporaines", "Post-modernisme",
                "Études postcoloniales", "Gender studies et art",
                "Philosophie contemporaine", "TD Théories critiques",
            ]},
            {"name": "Études culturelles", "weight": 18, "courses": [
                "Cultural studies", "Industries culturelles",
                "Médias et création", "Art et numérique",
                "TD Études culturelles",
            ]},
        ]},
        {"name": "UE2 — Pratique artistique avancée", "sub_ues": [
            {"name": "Création personnelle", "weight": 32, "courses": [
                "Atelier de création S1", "Atelier de création S2",
                "Atelier de création S3", "Atelier de création S4",
                "Jury de création intermédiaire", "Jury de création final",
                "Portfolio artistique", "Accrochage personnel",
            ]},
            {"name": "Expérimentation", "weight": 28, "courses": [
                "Expérimentation pluridisciplinaire", "Nouvelles technologies et art",
                "Performance et art vivant", "Art sonore",
                "Art vidéo avancé", "Atelier expérimental",
                "Art et intelligence artificielle",
            ]},
        ]},
        {"name": "UE3 — Recherche et mémoire", "sub_ues": [
            {"name": "Méthodologie", "weight": 18, "courses": [
                "Méthodologie de recherche en art", "Épistémologie de l'art",
                "Recherche-création", "Outils de recherche numérique",
                "Veille artistique",
            ]},
            {"name": "Mémoire", "weight": 20, "courses": [
                "Séminaire de mémoire S1", "Séminaire de mémoire S2",
                "Séminaire de mémoire S3", "Rédaction du mémoire",
                "Soutenance du mémoire",
            ]},
        ]},
        {"name": "UE4 — Professionnalisation", "sub_ues": [
            {"name": "Droit et Gestion", "weight": 20, "courses": [
                "Droit de l'art", "Propriété intellectuelle",
                "Droit des contrats artistiques", "Gestion de projet artistique",
                "Économie de l'art", "Financement et mécénat",
            ]},
            {"name": "Langues et réseau", "weight": 22, "courses": [
                "Anglais professionnel S1", "Anglais professionnel S2",
                "Anglais de l'art contemporain", "Réseaux professionnels",
                "Portfolio et CV artistique", "Préparation exposition",
                "Stage en institution culturelle",
            ]},
        ]},
    ]

    # =========================================================================
    # F17: Workshop International Arts — 100h
    # =========================================================================
    S[17] = [
        {"name": "UE1 — Création collaborative", "sub_ues": [
            {"name": "Projet collectif", "weight": 28, "courses": [
                "Brief et conception du projet", "Recherche et inspiration",
                "Production collective jour 1", "Production collective jour 2",
                "Production collective jour 3", "Production collective jour 4",
                "Finalisation du projet",
            ]},
            {"name": "Co-création interdisciplinaire", "weight": 16, "courses": [
                "Co-création interdisciplinaire", "Atelier interculturel",
                "Dialogue artistique", "Critique collective",
            ]},
        ]},
        {"name": "UE2 — Exposition et diffusion", "sub_ues": [
            {"name": "Commissariat d'exposition", "weight": 22, "courses": [
                "Commissariat d'exposition", "Scénographie d'exposition",
                "Accrochage et mise en espace", "Catalogue et documentation",
                "Éclairage scénographique",
            ]},
            {"name": "Communication et médiation", "weight": 18, "courses": [
                "Communication culturelle", "Médiation des publics",
                "Relations presse culturelle", "Vernissage collectif",
                "Bilan et retour d'expérience",
            ]},
        ]},
    ]

    # =========================================================================
    # F18: Stage Recherche Création — 140h
    # =========================================================================
    S[18] = [
        {"name": "UE1 — Cadre de recherche", "sub_ues": [
            {"name": "Projet de recherche", "weight": 20, "courses": [
                "Élaboration du projet", "Problématique et hypothèses",
                "Cadre théorique", "Méthodologie de recherche-création",
                "Définition du corpus",
            ]},
            {"name": "État de l'art", "weight": 16, "courses": [
                "Bibliographie commentée", "Revue de littérature artistique",
                "Cartographie des pratiques", "Veille artistique et critique",
            ]},
        ]},
        {"name": "UE2 — Pratique de terrain", "sub_ues": [
            {"name": "Résidence de création", "weight": 28, "courses": [
                "Résidence semaine 1 — Exploration", "Résidence semaine 2 — Expérimentation",
                "Résidence semaine 3 — Production", "Résidence semaine 4 — Finalisation",
                "Atelier en résidence", "Échanges avec artistes résidents",
                "Rencontres professionnelles",
            ]},
            {"name": "Restitution", "weight": 24, "courses": [
                "Journal de recherche-création", "Documentation du processus créatif",
                "Préparation de la restitution", "Restitution publique",
                "Soutenance finale", "Rapport de stage",
            ]},
        ]},
    ]

    return S

# ============================================================================
# Verify hours
# ============================================================================

def verify_and_build(structures):
    """Distribute hours and verify totals match targets."""
    result = {}
    print("=== VÉRIFICATION DES HEURES ===")
    all_ok = True

    for fid in sorted(structures.keys()):
        target = FORMATION_HOURS[fid]
        distributed = distribute_hours(structures[fid], target)
        total = sum(h for ue in distributed for sub in ue["sub_ues"] for _, h in sub["modules"])
        status = "OK" if total == target else f"ERREUR ({total}h)"
        if total != target:
            all_ok = False
        print(f"  F{fid}: {total}h / {target}h — {status}")

        # Count modules
        n_modules = sum(len(sub["modules"]) for ue in distributed for sub in ue["sub_ues"])
        n_sub_ues = sum(len(ue["sub_ues"]) for ue in distributed)
        n_ues = len(distributed)
        print(f"         {n_ues} UEs, {n_sub_ues} sous-UEs, {n_modules} modules")

        result[fid] = distributed

    print()
    return result, all_ok


# ============================================================================
# Seed
# ============================================================================

def seed_formation(fid, ues):
    print(f"=== Formation {fid} ===")
    module_count = 0
    total_hours = 0

    for ue_order, ue in enumerate(ues, 1):
        ue_node_id = create_ue(fid, ue["name"], ue_order)
        print(f"  UE: {ue['name']} (node={ue_node_id})")

        for sub_order, sub in enumerate(ue["sub_ues"], 1):
            sub_node_id = create_ue(fid, sub["name"], sub_order, parent_node_id=ue_node_id)
            sub_hours = sum(h for _, h in sub["modules"])
            print(f"    Sous-UE: {sub['name']} ({sub_hours}h, {len(sub['modules'])} modules, node={sub_node_id})")

            for mod_order, (mod_name, mod_hours) in enumerate(sub["modules"], 1):
                mod_id = create_module(fid, sub_node_id, mod_name, mod_order)
                if mod_id:
                    set_module_duration(fid, mod_id, mod_hours * 3600)
                    module_count += 1
                    total_hours += mod_hours

    print(f"  → {module_count} modules créés = {total_hours}h")
    print()


def seed_all(distributed):
    print("=== CRÉATION ===")
    for fid in sorted(distributed.keys()):
        seed_formation(fid, distributed[fid])


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    structures = build_structures()
    distributed, ok = verify_and_build(structures)

    if not ok:
        print("ERREUR: les heures ne correspondent pas.")
        sys.exit(1)

    cleanup_all()
    seed_all(distributed)

    # Summary
    total_modules = sum(
        len(sub["modules"])
        for ues in distributed.values()
        for ue in ues for sub in ue["sub_ues"]
    )
    total_sub_ues = sum(
        len(ue["sub_ues"])
        for ues in distributed.values()
        for ue in ues
    )
    total_ues = sum(len(ues) for ues in distributed.values())
    total_hours = sum(
        h for ues in distributed.values()
        for ue in ues for sub in ue["sub_ues"]
        for _, h in sub["modules"]
    )

    print("=== RÉSUMÉ ===")
    print(f"  {len(distributed)} formations")
    print(f"  {total_ues} UEs")
    print(f"  {total_sub_ues} sous-UEs")
    print(f"  {total_modules} modules (cours)")
    print(f"  {total_hours}h au total")
    print("=== DONE ===")
