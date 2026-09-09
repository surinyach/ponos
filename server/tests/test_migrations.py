from pathlib import Path

import pytest
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory

from app.db.session import engine


@pytest.mark.asyncio
async def test_database_was_upgraded_to_alembic_head() -> None:
    config = Config(Path(__file__).parents[1] / "alembic.ini")
    expected_head = ScriptDirectory.from_config(config).get_current_head()

    async with engine.connect() as connection:
        current_revision = await connection.run_sync(
            lambda sync_connection: MigrationContext.configure(
                sync_connection
            ).get_current_revision()
        )

    assert expected_head == "0004"
    assert current_revision == expected_head
