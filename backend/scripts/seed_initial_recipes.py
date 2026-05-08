import logging

from sqlalchemy.exc import ProgrammingError, SQLAlchemyError
from sqlmodel import Session

from app.core.db import engine
from app.core.recipe_seed import seed_recipes_if_empty


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main() -> int:
    logger.info("Seeding starter recipes if table is empty")
    try:
        with Session(engine) as session:
            seed_recipes_if_empty(session)
        logger.info("Recipe seed completed")
        return 0
    except ProgrammingError as exc:
        sqlstate = getattr(getattr(exc, "orig", None), "sqlstate", None)
        # 42P01 = undefined_table in Postgres; occurs when migrations are not yet applied.
        if sqlstate == "42P01":
            logger.warning(
                "Skipping starter recipe seed because the recipe table is missing. "
                "Run 'alembic upgrade head' to apply schema migrations."
            )
            return 0
        logger.exception("Failed to seed starter recipes")
        return 1
    except SQLAlchemyError:
        logger.exception("Failed to seed starter recipes")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
