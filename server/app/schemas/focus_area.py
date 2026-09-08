from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class WeekdayTargetCreate(ContractModel):
    weekday: int = Field(ge=1, le=7)
    target_minutes: int = Field(ge=0)
    valid_from: date = Field(
        description="First local calendar date on which this target applies.",
    )


class WeekdayTargetResponse(ContractModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    weekday: int = Field(ge=1, le=7)
    target_minutes: int = Field(ge=0)
    valid_from: date
    valid_until: date | None


class FocusAreaCreate(ContractModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = None
    priority: int
    target_end_date: date | None = None
    targets: list[WeekdayTargetCreate] = Field(min_length=1, max_length=7)

    @field_validator("name")
    @classmethod
    def name_must_contain_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("name must contain non-whitespace characters")
        return value

    @field_validator("targets")
    @classmethod
    def target_weekdays_must_be_unique(
        cls,
        value: list[WeekdayTargetCreate],
    ) -> list[WeekdayTargetCreate]:
        weekdays = [target.weekday for target in value]
        if len(weekdays) != len(set(weekdays)):
            raise ValueError("targets must contain each weekday at most once")
        return value


class FocusAreaUpdate(ContractModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = None
    priority: int | None = None
    target_end_date: date | None = None
    targets: list[WeekdayTargetCreate] | None = Field(
        default=None,
        min_length=1,
        max_length=7,
        description=(
            "New weekday target versions. Existing versions must be closed, "
            "never overwritten."
        ),
    )

    @field_validator("name")
    @classmethod
    def name_must_contain_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("name must contain non-whitespace characters")
        return value

    @field_validator("targets")
    @classmethod
    def target_weekdays_must_be_unique(
        cls,
        value: list[WeekdayTargetCreate] | None,
    ) -> list[WeekdayTargetCreate] | None:
        if value is None:
            return None
        weekdays = [target.weekday for target in value]
        if len(weekdays) != len(set(weekdays)):
            raise ValueError("targets must contain each weekday at most once")
        return value

    @model_validator(mode="after")
    def validate_updated_fields(self) -> "FocusAreaUpdate":
        if not self.model_fields_set:
            raise ValueError("at least one field must be provided")

        non_nullable_fields = {"name", "priority", "targets"}
        explicit_nulls = {
            field_name
            for field_name in non_nullable_fields.intersection(self.model_fields_set)
            if getattr(self, field_name) is None
        }
        if explicit_nulls:
            fields = ", ".join(sorted(explicit_nulls))
            raise ValueError(f"fields may not be null: {fields}")
        return self


class FocusAreaResponse(ContractModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    name: str
    description: str | None
    priority: int
    target_end_date: date | None
    archived_at: datetime | None
    created_at: datetime
    updated_at: datetime
    targets: list[WeekdayTargetResponse]


class FocusAreaPriorityUpdate(ContractModel):
    id: int = Field(gt=0)
    priority: int


class FocusAreaPrioritiesUpdate(ContractModel):
    items: list[FocusAreaPriorityUpdate] = Field(min_length=1)

    @field_validator("items")
    @classmethod
    def focus_area_ids_must_be_unique(
        cls,
        value: list[FocusAreaPriorityUpdate],
    ) -> list[FocusAreaPriorityUpdate]:
        identifiers = [item.id for item in value]
        if len(identifiers) != len(set(identifiers)):
            raise ValueError("each Focus Area may appear at most once")
        return value