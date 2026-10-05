from datetime import date

from app.models.focus_area import FocusArea, FocusAreaTarget


def target_for(area: FocusArea, work_date: date) -> FocusAreaTarget | None:
    if area.target_end_date is not None and work_date > area.target_end_date:
        return None
    return next(
        (
            target
            for target in area.targets
            if target.weekday == work_date.isoweekday()
            and target.valid_from <= work_date
            and (target.valid_until is None or target.valid_until >= work_date)
        ),
        None,
    )
