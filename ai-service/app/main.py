from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.models.schemas import MatchRequestSchema, MatchResponseSchema
from app.services.matching_engine import TransparentMatchingEngine
import uvicorn

app = FastAPI(
    title="AdoptMatch AI Matching Microservice",
    description="Decoupled AI recommendation service for pet-adopter compatibility scoring.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {
        "service": "AdoptMatch AI Microservice",
        "status": "online",
        "version": "1.0.0"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/api/v1/match", response_model=MatchResponseSchema)
def calculate_matches(payload: MatchRequestSchema):
    try:
        results = []
        for pet in payload.pets:
            match_res = TransparentMatchingEngine.calculate_match(payload.assessment, pet)
            results.append(match_res)
        
        # Sort results descending by score
        results.sort(key=lambda x: x.score, reverse=True)

        return MatchResponseSchema(
            status="success",
            total_evaluated=len(results),
            results=results
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
