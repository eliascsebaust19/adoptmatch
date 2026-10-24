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
    def calculate_match(assessment: AdopterAssessmentSchema, pet: PetDataSchema) -> MatchResultSchema:
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

        # 3. Energy Compatibility (15 pts)
        energy_pts = 0
        activity = assessment.activity_level.upper()
        p_energy = pet.energy_level.upper()

        if (activity in ["ACTIVE", "VERY_ACTIVE"] and p_energy in ["HIGH", "VERY HIGH"]) or \
           (activity == "MODERATE" and p_energy in ["MODERATE", "LOW"]) or \
           (activity == "SEDENTARY" and p_energy == "LOW"):
            energy_pts += 15
            reasons.append(f"Your {activity.lower()} lifestyle perfectly matches {pet.name}'s {pet.energy_level.lower()} energy level")
        elif abs(len(activity) - len(p_energy)) <= 3:
            energy_pts += 10
        else:
            energy_pts += 5
            if p_energy in ["HIGH", "VERY HIGH"] and activity == "SEDENTARY":
                considerations.append(f"High energy level requires regular active exercise")

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
        if assessment.preferred_species.lower() == pet.species.lower() or assessment.preferred_species == "Any":
            pref_pts += 5
            reasons.append(f"Matches your preference for a {pet.species}")
        if assessment.preferred_size == "Any" or assessment.preferred_size == pet.size:
            pref_pts += 5

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
            if (pet.species == "Dog" and pet.dog_friendly) or (pet.species == "Cat" and pet.cat_friendly):
                fam_pts += 5
                reasons.append("Sociable with existing household pets")
            else:
                fam_pts += 2
                considerations.append("Prefers to be the only pet in the household")
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
            reasons=reasons[:5], # top 5 reasons
            considerations=considerations[:4] # top 4 considerations
        )
