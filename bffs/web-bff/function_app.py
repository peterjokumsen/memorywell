import azure.functions as func
from crud import make_blueprint
from http_openapi import bp as openapi_bp

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

entities = [
    ("households", "id", ["name"], {}),
    ("chronicles", "householdId", ["name", "householdId"], {}),
    ("contributors", "householdId", ["name", "householdId"], {}),
    ("invites", "householdId", ["householdId"], {}),
    ("prompts", "chronicleId", ["chronicleId"], {}),
    ("memories", "chronicleId", ["chronicleId"], {}),
    ("transcripts", "chronicleId", ["chronicleId"], {}),
    ("flags", "chronicleId", ["chronicleId"], {}),
    ("aliasHistory", "chronicleId", ["chronicleId"], {}),
]

for name, _pk, required, defaults in entities:
    bp = make_blueprint(name, _pk, required_fields=required, defaults=defaults)
    app.register_blueprint(bp)

app.register_blueprint(openapi_bp)
