from datetime import date

from pydantic import Field

from app.schemas.focus_area import ContractModel, FocusAreaResponse
from app.schemas.special_activity import SpecialActivityResponse
from app.schemas.work_totals import OverallTotalsResponse, WeekTotalsResponse


class FocusAreaTodayProgress(ContractModel):
    focus_area: FocusAreaResponse
    target_seconds: int | None = Field(default=None, ge=0)
    focused_seconds: int = Field(ge=0)
    completed: bool


class SpecialActivityTodayProgress(ContractModel):
    special_activity: SpecialActivityResponse
    focused_seconds: int = Field(ge=0)
    rest_seconds: int = Field(ge=0)


class TodayOverviewResponse(ContractModel):
    date: date
    expected_focus_seconds: int = Field(ge=0)
    actual_focused_seconds: int = Field(ge=0)
    actual_rest_seconds: int = Field(ge=0)
    actual_tracked_seconds: int = Field(ge=0)
    completed_focus_areas: int = Field(ge=0)
    targeted_focus_areas: int = Field(ge=0)
    areas: list[FocusAreaTodayProgress]
    special_activities: list[SpecialActivityTodayProgress]
    week: WeekTotalsResponse
    overall: OverallTotalsResponse
