from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ManualWorkEntryCreate(ContractModel):
    focus_area_id: int | None = Field(default=None, gt=0)
    special_activity_id: int | None = Field(default=None, gt=0)
    work_date: date
    focused_seconds: int = Field(ge=0)
    rest_seconds: int = Field(ge=0)

    @model_validator(mode="after")
    def validate_entry(self) -> "ManualWorkEntryCreate":
        if (self.focus_area_id is None) == (self.special_activity_id is None):
            raise ValueError(
                "exactly one of focus_area_id or special_activity_id is required"
            )
        if self.focused_seconds == 0 and self.rest_seconds == 0:
            raise ValueError("focused_seconds and rest_seconds cannot both be 0")
        return self


class ManualWorkEntryUpdate(ContractModel):
    focus_area_id: int | None = Field(default=None, gt=0)
    special_activity_id: int | None = Field(default=None, gt=0)
    work_date: date | None = None
    focused_seconds: int | None = Field(default=None, ge=0)
    rest_seconds: int | None = Field(default=None, ge=0)

    @model_validator(mode="after")
    def validate_updated_fields(self) -> "ManualWorkEntryUpdate":
        fields = self.model_fields_set
        if not fields:
            raise ValueError("at least one field must be provided")
        for field_name in {
            "work_date",
            "focused_seconds",
            "rest_seconds",
        }.intersection(fields):
            if getattr(self, field_name) is None:
                raise ValueError(f"{field_name} may not be null")

        owner_fields = {"focus_area_id", "special_activity_id"}
        if fields.intersection(owner_fields):
            if not owner_fields.issubset(fields):
                raise ValueError(
                    "both owner fields are required when changing ownership"
                )
            if (self.focus_area_id is None) == (
                self.special_activity_id is None
            ):
                raise ValueError(
                    "exactly one of focus_area_id or special_activity_id is required"
                )

        if {"focused_seconds", "rest_seconds"}.issubset(fields):
            if self.focused_seconds == 0 and self.rest_seconds == 0:
                raise ValueError(
                    "focused_seconds and rest_seconds cannot both be 0"
                )
        return self


class ManualWorkEntryResponse(ContractModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    focus_area_id: int | None
    special_activity_id: int | None
    work_date: date
    focused_seconds: int = Field(ge=0)
    rest_seconds: int = Field(ge=0)
