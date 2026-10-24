from pydantic import BaseModel, Field
from typing import List, Optional

class AdopterAssessmentSchema(BaseModel):
    user_id: Optional[int] = None
    daily_free_time_hours: int = Field(default=4, description="Daily free time in hours")
    working_schedule: str = Field(default="HYBRID", description="REMOTE, HYBRID, OFFICE, FLEXIBLE")
    activity_level: str = Field(default="MODERATE", description="SEDENTARY, MODERATE, ACTIVE, VERY_ACTIVE")
    travel_frequency: str = Field(default="SELDOM", description="NEVER, SELDOM, MONTHLY, FREQUENT")
    pet_experience: str = Field(default="INTERMEDIATE", description="BEGINNER, INTERMEDIATE, EXPERIENCED")
    housing_type: str = Field(default="HOUSE", description="APARTMENT, HOUSE, CONDO, TOWNHOUSE")
    has_yard: bool = Field(default=True)
    yard_fenced: bool = Field(default=True)
    living_space_sqft: int = Field(default=1200)
    landlord_allows_pets: bool = Field(default=True)
    has_children: bool = Field(default=False)
    has_elderly: bool = Field(default=False)
    has_other_pets: bool = Field(default=False)
    preferred_species: str = Field(default="Dog")
    preferred_age_min: int = Field(default=0)
    preferred_age_max: int = Field(default=180)
    preferred_size: str = Field(default="Medium")
    preferred_gender: str = Field(default="Any")
    training_willingness: str = Field(default="MODERATE")
    grooming_willingness: str = Field(default="MODERATE")
    special_needs_willingness: bool = Field(default=False)

class PetDataSchema(BaseModel):
    id: int
    name: str
    species: str
    breed: str
    age_months: int
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

class MatchResponseSchema(BaseModel):
    status: str = "success"
    total_evaluated: int
    results: List[MatchResultSchema]
