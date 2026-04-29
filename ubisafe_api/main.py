import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from modules.community.report_router import router as community_reports_router
from modules.dispatching.ride_router import router as rides_router
from modules.dispatching.router import router as stops_router
from modules.identity.router import router as auth_router
from modules.safety.router import router as risk_zones_router
from modules.shared.firebase_admin_init import FirebaseAdminInit

logging.basicConfig(
    level=logging.getLevelName(os.getenv("LOG_LEVEL", "INFO")),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("ubisafe")


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_dotenv()
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

app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(stops_router, prefix="/stops", tags=["stops"])
app.include_router(rides_router, prefix="/rides", tags=["rides"])
app.include_router(risk_zones_router, prefix="/risk-zones", tags=["risk-zones"])
app.include_router(community_reports_router, prefix="/community-reports", tags=["community-reports"])
