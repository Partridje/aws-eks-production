"""Application configuration using Pydantic Settings"""

import os
from typing import List
from pydantic_settings import BaseSettings
from pydantic import Field

class Settings(BaseSettings):
    """Application settings"""

    # Environment
    environment: str = Field(default="production", env="ENVIRONMENT")

    # Database
    database_url: str = Field(..., env="DATABASE_URL")

    # CORS
    cors_origins: List[str] = Field(
        default=["*"],
        env="CORS_ORIGINS"
    )

    # AWS
    aws_region: str = Field(default="eu-west-1", env="AWS_REGION")
    aws_xray_daemon_address: str = Field(
        default="xray-daemon.amazon-cloudwatch.svc.cluster.local:2000",
        env="AWS_XRAY_DAEMON_ADDRESS"
    )

    # CloudWatch Logs
    cloudwatch_log_group: str = Field(
        default="/aws/eks/eks-prod-dev/application",
        env="CLOUDWATCH_LOG_GROUP"
    )
    cloudwatch_log_stream: str = Field(
        default="demo-backend",
        env="CLOUDWATCH_LOG_STREAM"
    )

    # Application
    service_name: str = Field(default="demo-backend", env="SERVICE_NAME")

    class Config:
        env_file = ".env"
        case_sensitive = False

settings = Settings()
