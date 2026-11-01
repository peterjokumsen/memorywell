import azure.functions as func
from http_admin import bp as http_admin_bp

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)
app.register_blueprint(http_admin_bp)
