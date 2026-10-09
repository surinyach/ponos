from datetime import date

from pydantic import Field, model_validator

from app.schemas.focus_area import ContractModel


class DailyGoalValue(ContractModel):
    weekday: int = Field(ge=1, le=7)
    target_minutes: int = Field(ge=0)


class WorkGoalsUpdate(ContractModel):
    daily_goals: list[DailyGoalValue]
    weekly_goal_minutes: int = Field(ge=0)

    @model_validator(mode="after")
    def require_every_weekday(self) -> "WorkGoalsUpdate":
        weekdays = [goal.weekday for goal in self.daily_goals]
        if sorted(weekdays) != list(range(1, 8)):
            raise ValueError("daily_goals must contain each weekday exactly once")
        return self


class WorkGoalsResponse(ContractModel):
    date: date
    daily_goals: list[DailyGoalValue]
    weekly_goal_minutes: int
    weekly_goal_effective_from: date | None
