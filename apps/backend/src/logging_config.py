"""Logging configuration with CloudWatch integration"""

import logging
import sys
import os
from pythonjsonlogger import jsonlogger

def setup_logging():
    """Setup structured logging with optional CloudWatch integration"""

    # Create logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # Create JSON formatter
    formatter = jsonlogger.JsonFormatter(
        '%(asctime)s %(name)s %(levelname)s %(message)s',
        timestamp=True
    )

    # Console handler (for stdout)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # CloudWatch handler (if in AWS environment)
    if os.getenv('AWS_REGION'):
        try:
            import watchtower

            cloudwatch_handler = watchtower.CloudWatchLogHandler(
                log_group=os.getenv('CLOUDWATCH_LOG_GROUP', '/aws/eks/eks-prod-dev/application'),
                stream_name=os.getenv('HOSTNAME', 'demo-backend'),
                use_queues=True,
                create_log_group=False
            )
            cloudwatch_handler.setFormatter(formatter)
            logger.addHandler(cloudwatch_handler)

            logger.info("CloudWatch logging enabled")
        except Exception as e:
            logger.warning(f"Failed to setup CloudWatch logging: {e}")

    return logger
