from contextlib import asynccontextmanager

from fastapi import FastAPI

from routers import auth, stops, risk_zones
from services.firebase_admin_init import FirebaseAdminInit


@asynccontextmanager
async def lifespan(app: FastAPI):
    FirebaseAdminInit.initialize()
    yield


app = FastAPI(title="UBISAFE API", lifespan=lifespan)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(stops.router, prefix="/stops", tags=["stops"])
app.include_router(risk_zones.router, prefix="/risk-zones", tags=["risk-zones"])
