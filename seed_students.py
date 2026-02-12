#!/usr/bin/env python3
"""
Génère 200 étudiants répartis sur les 2 écoles de l'ERP Neil.
~120 en Sciences & Technologies (school_id=2)
~100 en Arts & Lettres (school_id=3)
~20 sont inscrits dans les 2 écoles (double cursus)
"""

import requests
import random
import json
import time
import sys

API_BASE = "https://neil-claude.erp.neil.app/api"
API_KEY = "LoYrwWXSNbqY/PFKRv4l2rCV.X3YF1HYVqBVcNeaOQnMmN52EyhLXNmzKNNl1Z+7ViFN31AxZT+ja9RqED7SlQIww"
HEADERS = {
    "X-Lucius-Api-Key": API_KEY,
    "Content-Type": "application/json"
}

COUNTRY_FR = 75

# ─── Données de génération ─────────────────────────────────────────────
FIRST_NAMES_M = [
    "Adam", "Alexandre", "Antoine", "Arthur", "Baptiste", "Benjamin", "Charles",
    "Clément", "Damien", "David", "Édouard", "Émile", "Étienne", "Fabien",
    "Florian", "Gabriel", "Guillaume", "Hugo", "Ibrahim", "Ismaël", "Julien",
    "Kévin", "Léo", "Louis", "Lucas", "Mathieu", "Maxime", "Nathan", "Nicolas",
    "Olivier", "Paul", "Pierre", "Quentin", "Raphaël", "Romain", "Samuel",
    "Théo", "Thomas", "Valentin", "Victor", "Xavier", "Yann", "Zacharie",
    "Adrien", "Bastien", "Cédric", "Dylan", "Erwan", "Félix", "Gaël"
]

FIRST_NAMES_F = [
    "Adèle", "Alice", "Amandine", "Anaïs", "Aurélie", "Béatrice", "Camille",
    "Charlotte", "Chloé", "Clara", "Diane", "Élodie", "Emma", "Eva", "Fanny",
    "Gabrielle", "Hélène", "Inès", "Jade", "Julie", "Justine", "Laetitia",
    "Laura", "Léa", "Lina", "Louise", "Manon", "Marie", "Mathilde", "Morgane",
    "Nathalie", "Nina", "Noémie", "Océane", "Pauline", "Rachel", "Romane",
    "Sarah", "Sofia", "Sophie", "Valentine", "Victoire", "Yasmine", "Zoé",
    "Agathe", "Clémence", "Élise", "Flora", "Margaux", "Salomé"
]

LAST_NAMES = [
    "Martin", "Bernard", "Thomas", "Petit", "Robert", "Richard", "Durand",
    "Dubois", "Moreau", "Laurent", "Simon", "Michel", "Lefèvre", "Leroy",
    "Roux", "David", "Bertrand", "Morel", "Fournier", "Girard", "Bonnet",
    "Dupont", "Lambert", "Fontaine", "Rousseau", "Vincent", "Müller", "Lefèvre",
    "Faure", "André", "Mercier", "Blanc", "Guérin", "Boyer", "Garnier",
    "Chevalier", "François", "Legrand", "Gauthier", "Garcia", "Perrin",
    "Robin", "Clément", "Morin", "Nicolas", "Henry", "Roussel", "Mathieu",
    "Gautier", "Masson", "Marchand", "Duval", "Denis", "Dumont", "Marie",
    "Lemaire", "Noël", "Meyer", "Dufour", "Meunier", "Brun", "Blanchard",
    "Giraud", "Joly", "Rivière", "Lucas", "Brunet", "Gaillard", "Barbier",
    "Arnaud", "Martinez", "Gérard", "Renard", "Schmitt", "Roy", "Collet",
    "Leclercq", "Renaud", "Colin", "Vidal", "Picard", "Aubert"
]

CITIES = [
    ("Paris", "75001", "75"), ("Paris", "75011", "75"), ("Paris", "75015", "75"),
    ("Lyon", "69001", "69"), ("Lyon", "69003", "69"), ("Lyon", "69007", "69"),
    ("Marseille", "13001", "13"), ("Marseille", "13002", "13"), ("Marseille", "13008", "13"),
    ("Bordeaux", "33000", "33"), ("Bordeaux", "33200", "33"),
    ("Gif-sur-Yvette", "91190", "91"), ("Orsay", "91400", "91"), ("Palaiseau", "91120", "91"),
    ("Villeurbanne", "69100", "69"), ("Toulouse", "31000", "31"),
    ("Nantes", "44000", "44"), ("Montpellier", "34000", "34"),
    ("Lille", "59000", "59"), ("Strasbourg", "67000", "67"),
    ("Nice", "06000", "06"), ("Rennes", "35000", "35"),
    ("Aix-en-Provence", "13100", "13"), ("Pessac", "33600", "33"),
]

STREETS = [
    "rue de la Paix", "avenue des Champs-Élysées", "boulevard Victor Hugo",
    "rue du Commerce", "avenue de la République", "rue Pasteur",
    "rue Jean Jaurès", "rue de la Liberté", "avenue Gambetta",
    "rue du Faubourg Saint-Antoine", "boulevard Voltaire", "rue Nationale",
    "avenue du Général de Gaulle", "rue des Lilas", "impasse des Acacias",
    "allée des Tilleuls", "rue du Château", "rue de la Gare",
    "place de la Mairie", "rue des Écoles", "rue Saint-Jacques",
    "boulevard de la Mer", "rue du Soleil", "avenue Jean Moulin",
]

DEPARTMENTS = [
    ("75", "Paris"), ("69", "Lyon"), ("13", "Marseille"), ("33", "Bordeaux"),
    ("91", "Essonne"), ("31", "Toulouse"), ("44", "Nantes"), ("34", "Montpellier"),
    ("59", "Lille"), ("67", "Strasbourg"), ("06", "Nice"), ("35", "Rennes"),
]


def generate_phone():
    return f"+33 6 {random.randint(10,99)} {random.randint(10,99)} {random.randint(10,99)} {random.randint(10,99)}"


def generate_social_number(gender, birth_year, birth_month, dept_num):
    sex = "1" if gender == "male" else "2"
    year = str(birth_year)[-2:]
    month = f"{birth_month:02d}"
    dept = dept_num.zfill(2)[:2]
    commune = f"{random.randint(1,999):03d}"
    order = f"{random.randint(1,999):03d}"
    base = f"{sex}{year}{month}{dept}{commune}{order}"
    key = 97 - (int(base) % 97)
    return f"{base}{key:02d}"


def generate_cvec():
    return f"CVEC{random.randint(1000000000, 9999999999)}"


def create_student(i, first_name, last_name, gender, school_id):
    birth_year = random.randint(1998, 2007)
    birth_month = random.randint(1, 12)
    birth_day = random.randint(1, 28)
    birth_date = f"{birth_year}-{birth_month:02d}-{birth_day:02d}"

    dept_num, dept_name = random.choice(DEPARTMENTS)
    city, postal, _ = random.choice(CITIES)

    email_base = f"{first_name.lower().replace('é','e').replace('è','e').replace('ë','e').replace('ê','e').replace('à','a').replace('â','a').replace('î','i').replace('ï','i').replace('ô','o').replace('ù','u').replace('û','u').replace('ç','c').replace('ü','u').replace('ö','o').replace('ä','a')}"
    email_last = f"{last_name.lower().replace('é','e').replace('è','e').replace('ë','e').replace('ê','e').replace('à','a').replace('â','a').replace('î','i').replace('ï','i').replace('ô','o').replace('ù','u').replace('û','u').replace('ç','c').replace('ü','u').replace('ö','o').replace('ä','a').replace(' ','')}"
    email = f"{email_base}.{email_last}{random.randint(1,99)}@edu-neil.fr"

    payload = {
        "first_name": first_name,
        "last_name": last_name,
        "email": email,
        "birth_date": birth_date,
        "school_id": school_id,
        "gender": gender,
        "phone_number": generate_phone(),
        "birth_name": last_name,
        "birth_place": dept_name,
        "birth_department_number": dept_num,
        "nationality_id": COUNTRY_FR,
        "social_number": generate_social_number(gender, birth_year, birth_month, dept_num),
        "cvec_number": generate_cvec(),
        "top_level_sportsperson": random.random() < 0.03,
        "disability_recognition": random.random() < 0.05,
        "third_time": random.random() < 0.08,
        "address": {
            "address": f"{random.randint(1,150)} {random.choice(STREETS)}",
            "city": city,
            "postal_code": postal,
            "country_id": COUNTRY_FR
        }
    }

    resp = requests.post(f"{API_BASE}/students", headers=HEADERS, json=payload)
    if resp.status_code not in (200, 201):
        print(f"  ❌ ERREUR {resp.status_code} pour {first_name} {last_name}: {resp.text[:200]}")
        return None
    data = resp.json()
    student_id = data["id"]

    # Avatar via pravatar.cc (utilise l'index pour un avatar unique et stable)
    avatar_payload = {
        "bucket": "avatars",
        "path": f"students/{student_id}",
        "128": f"https://i.pravatar.cc/128?u=student-{student_id}-{i}",
        "512": f"https://i.pravatar.cc/512?u=student-{student_id}-{i}"
    }
    requests.patch(f"{API_BASE}/students/{student_id}/avatar", headers=HEADERS, json=avatar_payload)

    return student_id


def register_to_school(student_id, school_id):
    """Inscrit un étudiant dans une école supplémentaire"""
    resp = requests.post(
        f"{API_BASE}/students/{student_id}/registrations",
        headers=HEADERS,
        json={"school_id": school_id}
    )
    return resp.status_code in (200, 201)


# ═══════════════════════════════════════════════════════════════════════════
#                              MAIN
# ═══════════════════════════════════════════════════════════════════════════
print()
print("══════════════════════════════════════════════════════════════════")
print("   NEIL ERP — Génération de 200 étudiants")
print("══════════════════════════════════════════════════════════════════")
print()

random.seed(42)  # Reproductible

# Répartition :
# - 100 uniquement en S&T (school_id=2)
# - 80 uniquement en A&L (school_id=3)
# - 20 double cursus (inscrits dans les 2)
ONLY_ST = 100
ONLY_AL = 80
DOUBLE = 20
TOTAL = ONLY_ST + ONLY_AL + DOUBLE

created_ids = []
double_cursus_ids = []

for i in range(1, TOTAL + 1):
    # Déterminer genre
    gender = random.choice(["male", "female"])
    if random.random() < 0.02:
        gender = "non_binary"

    if gender == "male":
        first_name = random.choice(FIRST_NAMES_M)
    elif gender == "female":
        first_name = random.choice(FIRST_NAMES_F)
    else:
        first_name = random.choice(FIRST_NAMES_M + FIRST_NAMES_F)

    last_name = random.choice(LAST_NAMES)

    # Déterminer école principale
    if i <= ONLY_ST:
        school_id = 2  # S&T
        tag = "S&T"
    elif i <= ONLY_ST + ONLY_AL:
        school_id = 3  # A&L
        tag = "A&L"
    else:
        school_id = 2  # Double cursus, principal = S&T
        tag = "S&T+A&L"

    student_id = create_student(i, first_name, last_name, gender, school_id)

    if student_id:
        created_ids.append(student_id)

        # Double cursus : inscrire aussi dans la 2e école
        if i > ONLY_ST + ONLY_AL:
            ok = register_to_school(student_id, 3)
            if ok:
                double_cursus_ids.append(student_id)
                tag = "S&T+A&L ✨"

    # Progress
    bar = "█" * (i * 40 // TOTAL) + "░" * (40 - i * 40 // TOTAL)
    sys.stdout.write(f"\r  [{bar}] {i}/{TOTAL} — {first_name} {last_name} ({tag})")
    sys.stdout.flush()

print()
print()
print("══════════════════════════════════════════════════════════════════")
print(f"   ✅ {len(created_ids)} étudiants créés avec succès !")
print(f"   📊 {ONLY_ST} en S&T | {ONLY_AL} en A&L | {len(double_cursus_ids)} double cursus")
print("══════════════════════════════════════════════════════════════════")
print()
