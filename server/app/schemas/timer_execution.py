from datetime import date, datetime

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator


class TimerExecutionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    focus_area_id: int = Field(gt=0)
    work_date: date
    started_at: AwareDatetime
    ended_at: AwareDatetime
    focused_seconds: int = Field(ge=0)
    rest_seconds: int = Field(ge=0)

    @model_validator(mode="after")
    def validate_execution(self) -> "TimerExecutionCreate":
        if self.ended_at < self.started_at:
            raise ValueError("ended_at must be on or after started_at")
        if self.work_date != self.started_at.date():
            raise ValueError(
                "work_date must match the local date represented by started_at"
            )
        elapsed_seconds = (self.ended_at - self.started_at).total_seconds()
        if self.focused_seconds + self.rest_seconds > elapsed_seconds:
            raise ValueError(
                "focused_seconds plus rest_seconds cannot exceed elapsed time"
            )
        return self


class TimerExecutionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    focus_area_id: int
    work_date: date
    started_at: datetime
    ended_at: datetime
    focused_seconds: int = Field(ge=0)
    rest_seconds: int = Field(ge=0)
