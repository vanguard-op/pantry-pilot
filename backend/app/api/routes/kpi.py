from fastapi import APIRouter, Depends

from app.models import KpiSummary
from app.services.kpi_service import KpiService

router = APIRouter(prefix="/kpi", tags=["kpi"])


@router.get("/summary", response_model=KpiSummary)
def get_kpi_summary(service: KpiService = Depends()) -> KpiSummary:
    return service.get_kpi_summary()
