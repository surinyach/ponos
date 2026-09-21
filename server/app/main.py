from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.focus_areas import router as focus_areas_router
from app.api.health import router as health_router
from app.api.manual_work_entries import router as manual_work_entries_router
from app.api.special_activities import router as special_activities_router
from app.api.timer_executions import router as timer_executions_router
from app.api.today_overview import router as today_overview_router
from app.core.config import get_settings
from app.db.session import engine


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    yield
    await engine.dispose()


settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allowed_origins,
    allow_origin_regex=settings.cors_allow_origin_regex,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Accept", "Content-Type"],
)
app.include_router(health_router)
app.include_router(focus_areas_router)
app.include_router(special_activities_router)
app.include_router(manual_work_entries_router)
app.include_router(timer_executions_router)
app.include_router(today_overview_router)
