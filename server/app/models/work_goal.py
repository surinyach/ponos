from datetime import date

from sqlalchemy import BigInteger, CheckConstraint, Date, Identity, Integer, SmallInteger, func
from sqlalchemy.dialects.postgresql import ExcludeConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class DailyWorkGoal(Base):
    __tablename__ = "daily_work_goals"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    weekday: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    target_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    valid_from: Mapped[date] = mapped_column(Date, nullable=False)
    valid_until: Mapped[date | None] = mapped_column(Date, nullable=True)

    __table_args__ = (
        CheckConstraint("weekday BETWEEN 1 AND 7", name="ck_daily_work_goals_weekday"),
        CheckConstraint("target_minutes >= 0", name="ck_daily_work_goals_minutes"),
        CheckConstraint(
            "valid_until IS NULL OR valid_until >= valid_from",
            name="ck_daily_work_goals_valid_period",
        ),
        ExcludeConstraint(
            ("weekday", "="),
            (func.daterange(valid_from, valid_until, "[]"), "&&"),
            using="gist",
            name="excl_daily_work_goals_no_overlap",
        ),
    )


class WeeklyWorkGoal(Base):
    __tablename__ = "weekly_work_goals"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    target_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    valid_from: Mapped[date] = mapped_column(Date, nullable=False)
    valid_until: Mapped[date | None] = mapped_column(Date, nullable=True)

    __table_args__ = (
        CheckConstraint("target_minutes >= 0", name="ck_weekly_work_goals_minutes"),
        CheckConstraint(
            "valid_until IS NULL OR valid_until >= valid_from",
            name="ck_weekly_work_goals_valid_period",
        ),
        ExcludeConstraint(
            (func.daterange(valid_from, valid_until, "[]"), "&&"),
            using="gist",
            name="excl_weekly_work_goals_no_overlap",
        ),
    )
