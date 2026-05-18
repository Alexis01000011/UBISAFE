from pydantic import BaseModel


class Subscription(BaseModel):
    id: str
    buyer_uid: str
    vendor_uid: str
    active: bool
    created_at: str | None = None
    cancelled_at: str | None = None
    cancellation_reason: str | None = None


class CreateSubscriptionBody(BaseModel):
    vendor_uid: str
