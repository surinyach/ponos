from datetime import date

from pydantic import Field

from app.schemas.focus_area import ContractModel


class WeekTotalsResponse(ContractModel):
    week_start: date
    week_end: date
    focused_seconds: int = Field(ge=0)
    rest_seconds: int = Field(ge=0)
    tracked_seconds: int = Field(ge=0)


class OverallTotalsResponse(ContractModel):
    days_worked: int = Field(ge=0)
    focused_seconds: int = Field(ge=0)
    rest_seconds: int = Field(ge=0)
    tracked_seconds: int = Field(ge=0)
