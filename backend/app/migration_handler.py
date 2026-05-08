import logging
import subprocess


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handler(event, context):
    """Run Alembic migrations to head.

    This handler is invoked by Terraform during backend deployments so schema
    upgrades are tied to infrastructure rollout.
    """
    logger.info("Starting database migration run")
    try:
        result = subprocess.run(
            ["alembic", "upgrade", "head"],
            check=True,
            capture_output=True,
            text=True,
        )
        stdout = (result.stdout or "").strip()
        stderr = (result.stderr or "").strip()

        if stdout:
            logger.info("Alembic stdout: %s", stdout)
        if stderr:
            logger.warning("Alembic stderr: %s", stderr)

        logger.info("Database migration completed successfully")
        return {
            "statusCode": 200,
            "body": {
                "message": "alembic upgrade head succeeded",
                "stdout": stdout,
                "stderr": stderr,
            },
        }
    except subprocess.CalledProcessError as exc:
        stdout = (exc.stdout or "").strip()
        stderr = (exc.stderr or "").strip()
        logger.error("Alembic migration failed with exit code %s", exc.returncode)
        if stdout:
            logger.error("Alembic stdout: %s", stdout)
        if stderr:
            logger.error("Alembic stderr: %s", stderr)
        logger.exception("Migration command raised CalledProcessError")
        return {
            "statusCode": 500,
            "body": {
                "message": "alembic upgrade head failed",
                "exit_code": exc.returncode,
                "stdout": stdout,
                "stderr": stderr,
            },
        }
    except Exception as exc:
        logger.exception("Unexpected migration handler error")
        return {
            "statusCode": 500,
            "body": {
                "message": "unexpected migration handler error",
                "error": str(exc),
            },
        }
