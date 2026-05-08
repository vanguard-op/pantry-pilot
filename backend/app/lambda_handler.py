from mangum import Mangum

from app.main import app

# Lambda handler for API Gateway HTTP API events.
handler = Mangum(app, lifespan="on")
