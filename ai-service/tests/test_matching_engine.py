"""Regression tests for the transparent matching engine (audit finding AM-16).

Run from the ai-service directory:
    python -m pytest tests -q
or without pytest:
    python tests/test_matching_engine.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.models.schemas import AdopterAssessmentSchema, PetDataSchema
from app.services.matching_engine import TransparentMatchingEngine


def make_pet(energy_level="High", **overrides):
    data = dict(
        id=1,
        name="Luna",
        species="Dog",
        breed="Lab Mix",
        age_months=24,
        gender="Female",
        size="Medium",
        energy_level=energy_level,
        temperament="Gentle, Playful",
    )
    data.update(overrides)
    return PetDataSchema(**data)


def score_for(activity, energy):
    assessment = AdopterAssessmentSchema(activity_level=activity)
    return TransparentMatchingEngine.calculate_match(assessment, make_pet(energy))


def test_every_activity_energy_pair_scores_without_error():
    """The engine previously raised NameError because activity/p_energy were undefined."""
    for activity in ["SEDENTARY", "MODERATE", "ACTIVE", "VERY_ACTIVE"]:
        for energy in ["Low", "Moderate", "High", "Very High"]:
            result = score_for(activity, energy)
            assert 0 <= result.score <= 100, (activity, energy, result.score)
            assert result.classification


def test_matching_energy_beats_mismatched_energy():
    """Ordered distance must rank a genuine match above a mismatch."""
    matched = score_for("ACTIVE", "High").score
    mismatched = score_for("SEDENTARY", "High").score
    assert matched > mismatched, (matched, mismatched)

    matched_low = score_for("SEDENTARY", "Low").score
    mismatched_low = score_for("VERY_ACTIVE", "Low").score
    assert matched_low > mismatched_low, (matched_low, mismatched_low)


def test_label_length_does_not_drive_the_score():
    """'MODERATE' and 'Low' differ in length but are two levels apart."""
    sedentary_moderate = score_for("SEDENTARY", "Moderate").score
    sedentary_low = score_for("SEDENTARY", "Low").score
    assert sedentary_low > sedentary_moderate


def test_high_energy_pet_flags_an_exercise_consideration():
    result = score_for("SEDENTARY", "Very High")
    assert any("exercise" in c.lower() for c in result.considerations)


def test_daily_free_time_is_bounded():
    for invalid in [-1, 25, 999]:
        try:
            AdopterAssessmentSchema(daily_free_time_hours=invalid)
        except Exception:
            continue
        raise AssertionError(f"daily_free_time_hours={invalid} should be rejected")

    for valid in [0, 4, 24]:
        assert AdopterAssessmentSchema(daily_free_time_hours=valid).daily_free_time_hours == valid


def test_hard_constraints_cannot_be_outweighed():
    assessment = AdopterAssessmentSchema(activity_level="ACTIVE", landlord_allows_pets=False,
        special_needs_willingness=False, has_children=True)
    pet = make_pet("High", special_needs=True, child_friendly=False)
    result = TransparentMatchingEngine.calculate_match(assessment, pet)
    assert result.score == 0 and not result.eligible
    assert len(result.blocking_reasons) >= 3
    assert result.classification == "Not Recommended"


def test_apartment_and_existing_pet_constraints():
    assessment = AdopterAssessmentSchema(housing_type="APARTMENT", has_other_pets=True)
    result = TransparentMatchingEngine.calculate_match(assessment,
        make_pet(apartment_friendly=False, dog_friendly=False))
    assert not result.eligible and result.score == 0
    assert any("only dog" in reason for reason in result.blocking_reasons)


def test_required_care_time_is_enforced():
    result = TransparentMatchingEngine.calculate_match(
        AdopterAssessmentSchema(daily_free_time_hours=1), make_pet(exercise_requirement="High"))
    assert not result.eligible
    assert any("4 daily" in reason for reason in result.blocking_reasons)


def test_invalid_labels_and_age_ranges_are_rejected():
    for kwargs in [{"activity_level": "UNKNOWN"}, {"preferred_age_min": 99, "preferred_age_max": 10},
                   {"living_space_sqft": -1}]:
        try: AdopterAssessmentSchema(**kwargs)
        except Exception: continue
        raise AssertionError(f"Invalid assessment accepted: {kwargs}")


def test_pet_compatibility_with_existing_household_species():
    """Validates compatibility against actual household pet species, failing closed when species is omitted."""
    # 1. Household has a dog: adopting a cat that is not dog-friendly must be blocked
    cat_pet = make_pet(species="Cat", dog_friendly=False, cat_friendly=True)
    assessment_with_dog = AdopterAssessmentSchema(has_other_pets=True, other_pets_species=["Dog"])
    res1 = TransparentMatchingEngine.calculate_match(assessment_with_dog, cat_pet)
    assert not res1.eligible and res1.score == 0
    assert any("dogs in the household" in r for r in res1.blocking_reasons)

    # 2. Household has a dog: adopting a cat that IS dog-friendly must pass
    friendly_cat = make_pet(species="Cat", dog_friendly=True, cat_friendly=True)
    res2 = TransparentMatchingEngine.calculate_match(assessment_with_dog, friendly_cat)
    assert res2.eligible and res2.score > 0

    # 3. Household has a cat: adopting a dog that is not cat-friendly must be blocked
    dog_not_cat_friendly = make_pet(species="Dog", dog_friendly=True, cat_friendly=False)
    assessment_with_cat = AdopterAssessmentSchema(has_other_pets=True, other_pets_species=["cat"])
    res3 = TransparentMatchingEngine.calculate_match(assessment_with_cat, dog_not_cat_friendly)
    assert not res3.eligible and res3.score == 0
    assert any("cats in the household" in r for r in res3.blocking_reasons)

    # 4. Fail-closed: has_other_pets is True without species info -> pet without both friendly flags must block
    res4 = TransparentMatchingEngine.calculate_match(
        AdopterAssessmentSchema(has_other_pets=True, other_pets_species=None),
        dog_not_cat_friendly
    )
    assert not res4.eligible and res4.score == 0
    assert any("not specified" in r.lower() for r in res4.blocking_reasons)


def test_exercise_requirement_normalization_and_safe_fallback():
    """Exercise formats must normalize and unknown values must not silently downgrade to low requirement."""
    # Test normalization across case and whitespace/symbols
    norm_high, hrs_high, known_high = TransparentMatchingEngine.normalize_exercise_requirement("HIGH")
    assert hrs_high == 4 and known_high

    norm_vh, hrs_vh, known_vh = TransparentMatchingEngine.normalize_exercise_requirement("very_high")
    assert hrs_vh == 6 and known_vh

    norm_mod, hrs_mod, known_mod = TransparentMatchingEngine.normalize_exercise_requirement("  Moderate  ")
    assert hrs_mod == 2 and known_mod

    # Test safe fallback for unknown value: conservative 4 hours (High), not 1 or 2
    norm_unk, hrs_unk, known_unk = TransparentMatchingEngine.normalize_exercise_requirement("Ultra-Athletic")
    assert hrs_unk == 4 and not known_unk

    # An adopter with only 2 free hours must be blocked by unknown/extreme exercise requirement
    res_unk = TransparentMatchingEngine.calculate_match(
        AdopterAssessmentSchema(daily_free_time_hours=2),
        make_pet(exercise_requirement="Ultra-Athletic")
    )
    assert not res_unk.eligible
    assert any("4 daily" in r for r in res_unk.blocking_reasons)


def test_matching_preferences_age_and_gender():
    """Preferred age range and preferred gender must directly and transparently impact matching scores and reasons."""
    # Assessment: prefers female pet between 12 and 36 months
    assessment = AdopterAssessmentSchema(
        preferred_species="Dog",
        preferred_gender="Female",
        preferred_age_min=12,
        preferred_age_max=36,
        preferred_size="Medium"
    )

    # Perfect preference match (Luna: Dog, Female, 24m, Medium)
    matched_pet = make_pet(species="Dog", gender="Female", age_months=24, size="Medium")
    res_matched = TransparentMatchingEngine.calculate_match(assessment, matched_pet)

    # Mismatched pet (Male, 72m)
    mismatched_pet = make_pet(species="Dog", gender="Male", age_months=72, size="Medium")
    res_mismatched = TransparentMatchingEngine.calculate_match(assessment, mismatched_pet)

    assert res_matched.score > res_mismatched.score
    # Matched reasons must include age and gender confirmation
    assert any("gender preference (Female)" in r for r in res_matched.reasons)
    assert any("preferred range (12-36m)" in r for r in res_matched.reasons)

    # Mismatched considerations must point out age and gender variance
    assert any("outside your preferred range" in c for c in res_mismatched.considerations)
    assert any("differs from preferred (Female)" in c for c in res_mismatched.considerations)


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    failures = 0
    for test in tests:
        try:
            test()
            print(f"  ok  {test.__name__}")
        except AssertionError as exc:
            failures += 1
            print(f"FAIL  {test.__name__}: {exc}")
    if failures:
        print(f"\n{failures} of {len(tests)} matching tests failed.")
        sys.exit(1)
    print(f"\nAll {len(tests)} matching engine tests passed.")
