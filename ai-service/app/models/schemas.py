from pydantic import BaseModel, Field
from typing import List, Optional, Literal
from pydantic import model_validator

class AdopterAssessmentSchema(BaseModel):
    user_id: Optional[int] = None
    daily_free_time_hours: int = Field(default=4, ge=0, le=24, description="Daily free time in hours (0-24)")
    working_schedule: Literal["REMOTE", "HYBRID", "OFFICE", "FLEXIBLE"] = "HYBRID"
    activity_level: Literal["SEDENTARY", "MODERATE", "ACTIVE", "VERY_ACTIVE"] = "MODERATE"
    travel_frequency: str = Field(default="SELDOM", description="NEVER, SELDOM, MONTHLY, FREQUENT")
    pet_experience: Literal["BEGINNER", "INTERMEDIATE", "EXPERIENCED"] = "INTERMEDIATE"
    housing_type: Literal["APARTMENT", "HOUSE", "CONDO", "TOWNHOUSE"] = "HOUSE"
    has_yard: bool = Field(default=True)
    yard_fenced: bool = Field(default=True)
    living_space_sqft: int = Field(default=1200, ge=50, le=100000)
    landlord_allows_pets: bool = Field(default=True)
    has_children: bool = Field(default=False)
    has_elderly: bool = Field(default=False)
    has_other_pets: bool = Field(default=False)
    preferred_species: str = Field(default="Dog")
    preferred_age_min: int = Field(default=0, ge=0, le=600)
    preferred_age_max: int = Field(default=180, ge=0, le=600)
    preferred_size: str = Field(default="Medium")
    preferred_gender: str = Field(default="Any")
    training_willingness: str = Field(default="MODERATE")
    grooming_willingness: str = Field(default="MODERATE")
    special_needs_willingness: bool = Field(default=False)

    @model_validator(mode="after")
    def valid_age_range(self):
        if self.preferred_age_min > self.preferred_age_max:
            raise ValueError("preferred_age_min cannot exceed preferred_age_max")
        return self

class PetDataSchema(BaseModel):
    id: int
    name: str
    species: str
    breed: str
    age_months: int = Field(ge=0, le=600)
    gender: str
    size: str
    energy_level: str
    temperament: Optional[str] = ""
    child_friendly: bool = True
    dog_friendly: bool = True
    cat_friendly: bool = True
    apartment_friendly: bool = True
    house_trained: bool = True
    leash_trained: bool = True
    grooming_requirement: str = "Low"
    exercise_requirement: str = "Moderate"
    special_needs: bool = False
    location: Optional[str] = ""

class MatchRequestSchema(BaseModel):
    assessment: AdopterAssessmentSchema
    pets: List[PetDataSchema]

class MatchResultSchema(BaseModel):
    pet_id: int
    score: int
    classification: str
    reasons: List[str]
    considerations: List[str]
    eligible: bool = True
    blocking_reasons: List[str] = Field(default_factory=list)

class MatchResponseSchema(BaseModel):
    status: str = "success"
    total_evaluated: int
    results: List[MatchResultSchema]
