from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    DateTime,
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


class TimerExecution(Base):
    __tablename__ = "timer_executions"

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
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    ended_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    focused_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    rest_seconds: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        CheckConstraint(
            "(focus_area_id IS NOT NULL) <> (special_activity_id IS NOT NULL)",
            name="ck_timer_executions_exactly_one_owner",
        ),
        CheckConstraint(
            "focused_seconds >= 0",
            name="ck_timer_executions_focused_nonnegative",
        ),
        CheckConstraint(
            "rest_seconds >= 0",
            name="ck_timer_executions_rest_nonnegative",
        ),
        CheckConstraint(
            "ended_at >= started_at",
            name="ck_timer_executions_valid_period",
        ),
        Index("ix_timer_executions_focus_area_id", "focus_area_id"),
        Index("ix_timer_executions_special_activity_id", "special_activity_id"),
        Index("ix_timer_executions_work_date", "work_date"),
        Index("ix_timer_executions_started_at", "started_at"),
    )

    focus_area: Mapped["FocusArea | None"] = relationship(
        back_populates="timer_executions",
    )
    special_activity: Mapped["SpecialActivity | None"] = relationship()
