from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Identity, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.manual_work_entry import ManualWorkEntry


class SpecialActivity(Base):
    __tablename__ = "special_activities"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    __table_args__ = (
        Index("uq_special_activities_name_ci", func.lower(func.btrim(name)), unique=True),
    )

    manual_work_entries: Mapped[list["ManualWorkEntry"]] = relationship(
        back_populates="special_activity",
    )
