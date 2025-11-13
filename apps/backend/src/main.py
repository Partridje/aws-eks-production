"""
FastAPI Backend Application with full observability:
- CloudWatch Logs integration via watchtower
- AWS X-Ray distributed tracing
- Prometheus metrics
- Health checks
- PostgreSQL integration
"""

import os
import logging
from contextlib import asynccontextmanager
from typing import List

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import uvicorn

# AWS X-Ray
from aws_xray_sdk.core import xray_recorder, patch_all
from aws_xray_sdk.ext.fastapi.middleware import XRayMiddleware

# Local imports
from .config import settings
from .database import engine, get_db, Item, Base
from .logging_config import setup_logging

# Setup logging with CloudWatch integration
logger = setup_logging()

# Patch AWS SDK and other libraries for X-Ray tracing
patch_all()

# Configure X-Ray
xray_recorder.configure(
    service='demo-backend',
    plugins=('EKSPlugin',),
    context_missing='LOG_ERROR',
    daemon_address=os.getenv('AWS_XRAY_DAEMON_ADDRESS', 'xray-daemon.amazon-cloudwatch.svc.cluster.local:2000')
)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

ITEMS_CREATED = Counter(
    'items_created_total',
    'Total items created'
)

DB_CONNECTION_POOL = Gauge(
    'db_connection_pool_size',
    'Database connection pool size'
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    logger.info("Starting application", extra={
        "environment": settings.environment,
        "service": "demo-backend"
    })

    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    logger.info("Database tables created")

    yield

    logger.info("Shutting down application")
    await engine.dispose()

# Create FastAPI app
app = FastAPI(
    title="Demo Backend API",
    description="Production-ready FastAPI backend with full observability",
    version="1.0.0",
    lifespan=lifespan
)

# Add X-Ray middleware
app.add_middleware(XRayMiddleware, recorder=xray_recorder)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware for Prometheus metrics
@app.middleware("http")
async def prometheus_middleware(request, call_next):
    method = request.method
    endpoint = request.url.path

    with REQUEST_DURATION.labels(method=method, endpoint=endpoint).time():
        response = await call_next(request)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=response.status_code).inc()

    return response

################################################################################
# Health Checks
################################################################################

@app.get("/health")
async def health_check():
    """Liveness probe - is the application running?"""
    return {"status": "healthy", "service": "demo-backend"}

@app.get("/health/ready")
async def readiness_check(db: AsyncSession = Depends(get_db)):
    """Readiness probe - can the application accept traffic?"""
    try:
        # Test database connection
        await db.execute(select(1))

        return {
            "status": "ready",
            "checks": {
                "database": "ok"
            }
        }
    except Exception as e:
        logger.error(f"Readiness check failed: {str(e)}")
        raise HTTPException(status_code=503, detail="Service not ready")

@app.get("/health/startup")
async def startup_check():
    """Startup probe - has the application finished starting?"""
    return {"status": "started"}

################################################################################
# Metrics Endpoint
################################################################################

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

################################################################################
# API Endpoints
################################################################################

@app.get("/")
async def root():
    """Root endpoint"""
    logger.info("Root endpoint accessed")
    return {
        "message": "Demo Backend API",
        "version": "1.0.0",
        "environment": settings.environment
    }

@app.get("/api/items", response_model=List[dict])
async def list_items(db: AsyncSession = Depends(get_db)):
    """List all items"""
    logger.info("Listing items")

    with xray_recorder.capture('list_items'):
        result = await db.execute(select(Item))
        items = result.scalars().all()

        return [
            {
                "id": item.id,
                "name": item.name,
                "description": item.description,
                "created_at": item.created_at.isoformat() if item.created_at else None
            }
            for item in items
        ]

@app.post("/api/items", response_model=dict, status_code=201)
async def create_item(
    name: str,
    description: str = None,
    db: AsyncSession = Depends(get_db)
):
    """Create a new item"""
    logger.info(f"Creating item: {name}")

    with xray_recorder.capture('create_item'):
        item = Item(name=name, description=description)
        db.add(item)
        await db.commit()
        await db.refresh(item)

        # Increment custom metric
        ITEMS_CREATED.inc()

        logger.info(f"Item created with ID: {item.id}")

        return {
            "id": item.id,
            "name": item.name,
            "description": item.description,
            "created_at": item.created_at.isoformat() if item.created_at else None
        }

@app.get("/api/items/{item_id}", response_model=dict)
async def get_item(item_id: int, db: AsyncSession = Depends(get_db)):
    """Get a specific item"""
    logger.info(f"Getting item {item_id}")

    with xray_recorder.capture('get_item'):
        result = await db.execute(select(Item).where(Item.id == item_id))
        item = result.scalar_one_or_none()

        if not item:
            logger.warning(f"Item {item_id} not found")
            raise HTTPException(status_code=404, detail="Item not found")

        return {
            "id": item.id,
            "name": item.name,
            "description": item.description,
            "created_at": item.created_at.isoformat() if item.created_at else None
        }

@app.delete("/api/items/{item_id}", status_code=204)
async def delete_item(item_id: int, db: AsyncSession = Depends(get_db)):
    """Delete an item"""
    logger.info(f"Deleting item {item_id}")

    with xray_recorder.capture('delete_item'):
        result = await db.execute(select(Item).where(Item.id == item_id))
        item = result.scalar_one_or_none()

        if not item:
            raise HTTPException(status_code=404, detail="Item not found")

        await db.delete(item)
        await db.commit()

        logger.info(f"Item {item_id} deleted")

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.environment == "development"
    )
