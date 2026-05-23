import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from modules.community.lot_router import router as community_lot_router
from modules.community.report_router import router as community_reports_router
from modules.community.validation_router import router as community_validations_router
from modules.dispatching.group_stay_router import router as group_stays_router
from modules.dispatching.ride_router import router as rides_router
from modules.dispatching.router import router as stops_router
from modules.identity.router import router as auth_router
from modules.safety.dismiss_router import router as risk_zones_dismiss_router
from modules.safety.router import router as risk_zones_router
from modules.shared.firebase_admin_init import FirebaseAdminInit
from modules.shared.subscription_router import router as subscriptions_router

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

_allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=_allowed_origins != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(stops_router, prefix="/stops", tags=["stops"])
app.include_router(rides_router, prefix="/rides", tags=["rides"])
app.include_router(risk_zones_router, prefix="/risk-zones", tags=["risk-zones"])
app.include_router(risk_zones_dismiss_router, prefix="/risk-zones", tags=["risk-zones"])
app.include_router(
    community_reports_router, prefix="/community-reports", tags=["community-reports"]
)
app.include_router(
    community_validations_router, prefix="/community-reports", tags=["community-reports"]
)
app.include_router(
    community_lot_router, prefix="/community-reports", tags=["vacant-lots"]
)
app.include_router(subscriptions_router, prefix="/subscriptions", tags=["subscriptions"])
app.include_router(group_stays_router, prefix="/group-stays", tags=["group-stays"])
