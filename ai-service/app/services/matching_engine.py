from app.models.schemas import AdopterAssessmentSchema, PetDataSchema, MatchResultSchema
from typing import Tuple, List

class TransparentMatchingEngine:
    """
    Transparent weighted compatibility engine for AdoptMatch.
    Weights:
    - Home Compatibility: 20%
    - Lifestyle Compatibility: 20%
    - Energy Compatibility: 15%
    - Experience Compatibility: 15%
    - Pet Preference: 10%
    - Family Compatibility: 10%
    - Care Capacity: 10%
    """

    @staticmethod
    def normalize_exercise_requirement(req: str) -> Tuple[str, int, bool]:
        """
        Normalize exercise requirement into (canonical_label, required_daily_hours, is_known).
        Handles case insensitivity, whitespace, underscores and hyphens (e.g. 'High', 'HIGH', 'very_high').
        Unknown values do not silently assume low requirements; they fall back safely to 4 hours.
        """
        if not req or not str(req).strip():
            return ("Unknown", 4, False)

        clean = " ".join(str(req).strip().replace("_", " ").replace("-", " ").upper().split())
        mapping = {
            "LOW": ("Low", 1),
            "LIGHT": ("Low", 1),
            "MODERATE": ("Moderate", 2),
            "MEDIUM": ("Moderate", 2),
            "MED": ("Moderate", 2),
            "HIGH": ("High", 4),
            "VERY HIGH": ("Very High", 6),
            "VERYHIGH": ("Very High", 6),
            "EXTREME": ("Very High", 6),
        }
        if clean in mapping:
            label, hrs = mapping[clean]
            return (label, hrs, True)

        return (f"Unknown ({req})", 4, False)

    @staticmethod
    def calculate_match(assessment: AdopterAssessmentSchema, pet: PetDataSchema) -> MatchResultSchema:
        # Safety/welfare constraints cannot be compensated for by other weights.
        blockers: List[str] = []
        if not assessment.landlord_allows_pets:
            blockers.append("Housing permission is required before adoption")
        if assessment.housing_type in ["APARTMENT", "CONDO"] and not pet.apartment_friendly:
            blockers.append("This pet requires a house or larger outdoor living space")
        if assessment.has_children and not pet.child_friendly:
            blockers.append("This pet requires an adult-only home")
        if pet.special_needs and not assessment.special_needs_willingness:
            blockers.append("This pet requires special-needs care capacity")

        # Pet compatibility: validate existing household pets
        if assessment.has_other_pets:
            if assessment.other_pets_species:
                norm_species = [s.strip().lower() for s in assessment.other_pets_species if s and s.strip()]
                has_dogs = any(s in ["dog", "dogs", "canine", "puppy"] for s in norm_species)
                has_cats = any(s in ["cat", "cats", "feline", "kitten"] for s in norm_species)

                if has_dogs and not pet.dog_friendly:
                    blockers.append("This pet is not compatible with dogs in the household")
                if has_cats and not pet.cat_friendly:
                    blockers.append("This pet is not compatible with cats in the household")

                other_animals = [s for s in norm_species if s not in ["dog", "dogs", "canine", "puppy", "cat", "cats", "feline", "kitten"]]
                if other_animals and not (pet.dog_friendly and pet.cat_friendly):
                    blockers.append("This pet is not confirmed compatible with other household animals")
            else:
                # Information missing: fail closed, never assume safe
                if not pet.dog_friendly:
                    blockers.append("Existing household pet species not specified; this pet must be the only dog in the household" if pet.species == "Dog" else "Existing household pet species not specified; pet is not dog-friendly")
                if not pet.cat_friendly:
                    blockers.append("Existing household pet species not specified; this pet must be the only cat in the household" if pet.species == "Cat" else "Existing household pet species not specified; pet is not cat-friendly")

        # Exercise requirement normalization with safe fallback
        canon_ex, required_hours, is_known_ex = TransparentMatchingEngine.normalize_exercise_requirement(pet.exercise_requirement)
        if assessment.daily_free_time_hours < required_hours:
            blockers.append(f"At least {required_hours} daily care/exercise hours are required")

        if blockers:
            return MatchResultSchema(pet_id=pet.id, score=0,
                classification="Not Recommended", reasons=[], considerations=blockers,
                eligible=False, blocking_reasons=blockers)

        score = 0
        reasons: List[str] = []
        considerations: List[str] = []

        # 1. Home Compatibility (20 pts)
        home_pts = 0
        if assessment.housing_type == "APARTMENT" and pet.apartment_friendly:
            home_pts += 12
            reasons.append("Perfectly suited for apartment living")
        elif assessment.housing_type in ["HOUSE", "TOWNHOUSE"]:
            home_pts += 12
            reasons.append("Home environment provides comfortable space")
        else:
            home_pts += 6
            if not pet.apartment_friendly:
                considerations.append("Requires larger living space or yard access")

        if assessment.has_yard and assessment.yard_fenced:
            home_pts += 8
            reasons.append("Fenced yard is ideal for outdoor activity")
        elif assessment.has_yard:
            home_pts += 5
        else:
            home_pts += 3

        score += home_pts

        # 2. Lifestyle Compatibility (20 pts)
        lifestyle_pts = 0
        if assessment.daily_free_time_hours >= 4:
            lifestyle_pts += 10
            reasons.append("Your daily free time matches pet social needs")
        elif assessment.daily_free_time_hours >= 2:
            lifestyle_pts += 7
        else:
            lifestyle_pts += 4
            considerations.append("Pet requires substantial daily attention")

        if assessment.working_schedule in ["REMOTE", "FLEXIBLE"]:
            lifestyle_pts += 10
            reasons.append("Remote/flexible schedule allows consistent companionship")
        elif assessment.working_schedule == "HYBRID":
            lifestyle_pts += 8
        else:
            lifestyle_pts += 5
            if pet.species == "Dog" and pet.energy_level in ["High", "Very High"]:
                considerations.append("Full-time office schedule may need mid-day dog walker")

        score += lifestyle_pts

        # 3. Energy Compatibility (15 pts) - Ordered level distance
        activity_scale = {
            "SEDENTARY": 1,
            "MODERATE": 2,
            "ACTIVE": 3,
            "VERY_ACTIVE": 4,
        }
        energy_scale = {
            "LOW": 1,
            "MODERATE": 2,
            "HIGH": 3,
            "VERY HIGH": 4,
            "VERY_HIGH": 4,
        }
        activity = assessment.activity_level.upper()
        p_energy = pet.energy_level.upper()
        act_val = activity_scale.get(activity, 2)
        eng_val = energy_scale.get(p_energy, 2)
        diff = abs(act_val - eng_val)

        if diff == 0:
            energy_pts = 15
            reasons.append(f"Your {activity.lower()} lifestyle perfectly matches {pet.name}'s {pet.energy_level.lower()} energy level")
        elif diff == 1:
            energy_pts = 10
        else:
            energy_pts = 5
            if eng_val > act_val:
                considerations.append("High energy level requires regular active exercise")
            else:
                considerations.append("Pet energy level differs noticeably from your typical routine")

        score += energy_pts

        # 4. Experience Compatibility (15 pts)
        exp_pts = 0
        exp = assessment.pet_experience.upper()
        if exp == "EXPERIENCED":
            exp_pts += 15
            reasons.append("Suitable for experienced pet owners")
        elif exp == "INTERMEDIATE":
            exp_pts += 13
            reasons.append("Fits intermediate pet ownership experience")
        else: # BEGINNER
            if pet.house_trained and pet.leash_trained and pet.temperament and "Gentle" in pet.temperament:
                exp_pts += 15
                reasons.append("Excellent for first-time adopters due to gentle temperament & training")
            else:
                exp_pts += 9
                considerations.append("May benefit from basic ongoing training")

        score += exp_pts

        # 5. Pet Preference (10 pts)
        pref_pts = 0

        # 5a. Species preference (3 pts)
        if assessment.preferred_species.lower() in [pet.species.lower(), "any"]:
            pref_pts += 3
            reasons.append(f"Matches your preference for a {pet.species}")
        else:
            considerations.append(f"Species ({pet.species}) differs from preferred ({assessment.preferred_species})")

        # 5b. Age range preference (3 pts)
        if assessment.preferred_age_min <= pet.age_months <= assessment.preferred_age_max:
            pref_pts += 3
            reasons.append(f"Age ({pet.age_months}m) is within your preferred range ({assessment.preferred_age_min}-{assessment.preferred_age_max}m)")
        else:
            diff_months = pet.age_months - assessment.preferred_age_max if pet.age_months > assessment.preferred_age_max else assessment.preferred_age_min - pet.age_months
            if diff_months <= 6:
                pref_pts += 1
            considerations.append(f"Age ({pet.age_months}m) is outside your preferred range ({assessment.preferred_age_min}-{assessment.preferred_age_max}m)")

        # 5c. Size preference (2 pts)
        if assessment.preferred_size.lower() in [pet.size.lower(), "any"]:
            pref_pts += 2
            reasons.append(f"Matches your size preference ({pet.size})")
        else:
            considerations.append(f"Size ({pet.size}) differs from preferred ({assessment.preferred_size})")

        # 5d. Gender preference (2 pts)
        if assessment.preferred_gender.lower() in [pet.gender.lower(), "any"]:
            pref_pts += 2
            reasons.append(f"Matches your gender preference ({pet.gender})")
        else:
            considerations.append(f"Gender ({pet.gender}) differs from preferred ({assessment.preferred_gender})")

        score += pref_pts

        # 6. Family Compatibility (10 pts)
        fam_pts = 0
        if assessment.has_children:
            if pet.child_friendly:
                fam_pts += 5
                reasons.append("Kid-friendly and patient with children")
            else:
                fam_pts += 1
                considerations.append("Prefers an adult-only home")
        else:
            fam_pts += 5

        if assessment.has_other_pets:
            if assessment.other_pets_species:
                norm_species = [s.strip().lower() for s in assessment.other_pets_species if s and s.strip()]
                has_dogs = any(s in ["dog", "dogs", "canine", "puppy"] for s in norm_species)
                has_cats = any(s in ["cat", "cats", "feline", "kitten"] for s in norm_species)
                compatible = True
                if has_dogs and not pet.dog_friendly:
                    compatible = False
                if has_cats and not pet.cat_friendly:
                    compatible = False
                if compatible:
                    fam_pts += 5
                    reasons.append("Sociable with existing household pets")
                else:
                    fam_pts += 1
                    considerations.append("May require careful introduction to existing household pets")
            else:
                if pet.dog_friendly and pet.cat_friendly:
                    fam_pts += 4
                    reasons.append("Sociable with other animals")
                else:
                    fam_pts += 1
                    considerations.append("Compatibility with existing pets is unconfirmed")
        else:
            fam_pts += 5

        score += fam_pts

        # 7. Care Capacity (10 pts)
        care_pts = 0
        if pet.special_needs:
            if assessment.special_needs_willingness:
                care_pts += 10
                reasons.append("You are open to special-needs care")
            else:
                care_pts += 2
                considerations.append("Has special medical/care needs")
        else:
            care_pts += 10

        score += care_pts

        if not is_known_ex:
            considerations.append(f"Exercise requirement '{pet.exercise_requirement}' is unconfirmed; conservative care capacity applied")

        # Cap score between 0 and 100
        final_score = max(0, min(100, score))

        # Determine classification
        if final_score >= 85:
            classification = "Excellent Match"
        elif final_score >= 70:
            classification = "Good Match"
        elif final_score >= 50:
            classification = "Fair Match"
        else:
            classification = "Poor Match"

        return MatchResultSchema(
            pet_id=pet.id,
            score=final_score,
            classification=classification,
            reasons=reasons[:10],
            considerations=considerations[:8]
        )
