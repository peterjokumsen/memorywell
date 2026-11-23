"""Cosmos change feed stub for the ``memories`` container.

Every new or updated memory document lands here. Phase 4b turns this into
embedding generation + cache refresh; for now it only proves the change-feed
processor is wired to the container and its lease container.

Registered as a blueprint in ``function_app.py``: a trigger module that is not
registered there never reaches the host's route table.

Notes:
- ``start_from_beginning=False`` starts a fresh lease container at "now" rather
  than replaying every existing memory.
- The decorator keeps the legacy argument names: ``collection_name`` is the
  container and ``connection_string_setting`` is the app-setting **prefix**
  (``CosmosDBConnection__*``), not a connection string.
- ``database_name`` is a literal because decorators run at import time; it must
  match ``COSMOS_DATABASE`` (``memorywell``, not env-suffixed).
"""

import logging

import azure.functions as func

bp = func.Blueprint()


@bp.cosmos_db_trigger(
    arg_name="documents",
    connection="CosmosDBConnection",
    database_name="memorywell",
    container_name="memories",
    lease_container_name="leases",
    lease_database_name="memorywell",
    create_lease_container_if_not_exists=False,
    start_from_beginning=False,
)
def cosmos_changefeed(documents: func.DocumentList) -> None:
    for document in documents:
        logging.info(
            "change feed: id=%s chronicleId=%s",
            document.get("id"),
            document.get("chronicleId"),
        )
