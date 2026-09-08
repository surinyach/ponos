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
    SmallInteger,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import ExcludeConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.timer_execution import TimerExecution


class FocusArea(Base):
    __tablename__ = "focus_areas"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    priority: Mapped[int] = mapped_column(Integer, nullable=False)
    target_end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    targets: Mapped[list["FocusAreaTarget"]] = relationship(
        back_populates="focus_area",
    )
    timer_executions: Mapped[list["TimerExecution"]] = relationship(
        back_populates="focus_area",
    )


class FocusAreaTarget(Base):
    __tablename__ = "focus_area_targets"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    focus_area_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("focus_areas.id", ondelete="RESTRICT"),
        nullable=False,
    )
    weekday: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    target_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    valid_from: Mapped[date] = mapped_column(Date, nullable=False)
    valid_until: Mapped[date | None] = mapped_column(Date, nullable=True)

    __table_args__ = (
        CheckConstraint(
            "weekday BETWEEN 1 AND 7",
            name="ck_focus_area_targets_weekday",
        ),
        CheckConstraint(
            "target_minutes >= 0",
            name="ck_focus_area_targets_minutes_nonnegative",
        ),
        CheckConstraint(
            "valid_until IS NULL OR valid_until >= valid_from",
            name="ck_focus_area_targets_valid_period",
        ),
        ExcludeConstraint(
            ("focus_area_id", "="),
            ("weekday", "="),
            (func.daterange(valid_from, valid_until, "[]"), "&&"),
            using="gist",
            name="excl_focus_area_targets_no_overlap",
        ),
        Index("ix_focus_area_targets_focus_area_id", "focus_area_id"),
    )

    focus_area: Mapped[FocusArea] = relationship(back_populates="targets")