from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from schemas.risk_zone import CreateRiskZoneBody, RiskZone
from services.firestore_service import FirestoreService

router = APIRouter()


@router.get("/", response_model=list[RiskZone])
async def list_risk_zones(current_user: dict = Depends(get_current_user)):
    return await FirestoreService.list_risk_zones()


@router.post("/", response_model=RiskZone, status_code=status.HTTP_201_CREATED)
async def create_risk_zone(
    body: CreateRiskZoneBody,
    current_user: dict = Depends(get_current_user),
):
    return await FirestoreService.create_risk_zone(current_user["uid"], body)
