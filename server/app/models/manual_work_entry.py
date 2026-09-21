from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    ForeignKey,
    Identity,
    Index,
    Integer,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.focus_area import FocusArea
    from app.models.special_activity import SpecialActivity


class ManualWorkEntry(Base):
    __tablename__ = "manual_work_entries"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    focus_area_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("focus_areas.id", ondelete="RESTRICT"),
        nullable=True,
    )
    special_activity_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("special_activities.id", ondelete="RESTRICT"),
        nullable=True,
    )
    work_date: Mapped[date] = mapped_column(Date, nullable=False)
    focused_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    rest_seconds: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        CheckConstraint(
            "(focus_area_id IS NOT NULL) <> "
            "(special_activity_id IS NOT NULL)",
            name="ck_manual_work_entries_exactly_one_subject",
        ),
        CheckConstraint(
            "focused_seconds >= 0",
            name="ck_manual_work_entries_focused_nonnegative",
        ),
        CheckConstraint(
            "rest_seconds >= 0",
            name="ck_manual_work_entries_rest_nonnegative",
        ),
        CheckConstraint(
            "focused_seconds > 0 OR rest_seconds > 0",
            name="ck_manual_work_entries_duration_nonzero",
        ),
        Index("ix_manual_work_entries_focus_area_id", "focus_area_id"),
        Index(
            "ix_manual_work_entries_special_activity_id",
            "special_activity_id",
        ),
        Index("ix_manual_work_entries_work_date", "work_date"),
    )

    focus_area: Mapped["FocusArea | None"] = relationship(
        back_populates="manual_work_entries",
    )
    special_activity: Mapped["SpecialActivity | None"] = relationship(
        back_populates="manual_work_entries",
    )
