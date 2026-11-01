import azure.functions as func
from http_chronicles import bp as chronicles_bp
from http_contributors import bp as contributors_bp
from http_households import bp as households_bp

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)
app.register_blueprint(households_bp)
app.register_blueprint(chronicles_bp)
app.register_blueprint(contributors_bp)
