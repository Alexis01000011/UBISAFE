import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import auth, risk_zones, stops
from services.firebase_admin_init import FirebaseAdminInit

logging.basicConfig(
    level=logging.getLevelName(os.getenv("LOG_LEVEL", "INFO")),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("ubisafe")


@asynccontextmanager
async def lifespan(app: FastAPI):
    FirebaseAdminInit.initialize()
    logger.info("Firebase Admin SDK initialized")
    yield
    logger.info("UBISAFE API shutting down")


app = FastAPI(title="UBISAFE API", lifespan=lifespan)

# CORS — allow localhost origins in development.
_dev_origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8080",
    "http://10.0.2.2",  # Android emulator host
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_dev_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(stops.router, prefix="/stops", tags=["stops"])
app.include_router(risk_zones.router, prefix="/risk-zones", tags=["risk-zones"])
