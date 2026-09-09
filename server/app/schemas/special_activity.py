from datetime import date

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SpecialActivityCreate(ContractModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = None
    work_date: date

    @field_validator("name")
    @classmethod
    def name_must_contain_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("name must contain non-whitespace characters")
        return value


class SpecialActivityUpdate(ContractModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = None
    work_date: date | None = None

    @field_validator("name")
    @classmethod
    def name_must_contain_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("name must contain non-whitespace characters")
        return value

    @model_validator(mode="after")
    def validate_updated_fields(self) -> "SpecialActivityUpdate":
        if not self.model_fields_set:
            raise ValueError("at least one field must be provided")
        for field_name in {"name", "work_date"}.intersection(
            self.model_fields_set
        ):
            if getattr(self, field_name) is None:
                raise ValueError(f"{field_name} may not be null")
        return self


class SpecialActivityResponse(ContractModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    name: str
    description: str | None
    work_date: date
    is_archived: bool
