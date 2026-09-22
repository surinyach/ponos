from datetime import date
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.work_totals import aggregate_day


@pytest.mark.asyncio
async def test_daily_aggregation_uses_mixed_timer_and_manual_rows_for_totals_and_progress():
    db = AsyncMock()
    result_rows = MagicMock()
    result_rows.all.return_value = [
        # Grouped timer + manual rows for the same Focus Area.
        (1, None, 1800, 360),
        (2, None, 0, 120),
        # Grouped timer + manual rows for a Special Activity.
        (None, 3, 600, 300),
    ]
    db.execute.return_value = result_rows

    result = await aggregate_day(db, date(2026, 9, 7))

    assert (result.focused_seconds, result.rest_seconds) == (2400, 780)
    assert result.focused_by_area == {1: 1800, 2: 0}
    assert result.time_by_special_activity == {3: (600, 300)}
    db.execute.assert_awaited_once()
