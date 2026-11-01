import datetime
import os
import uuid

from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import ManagedIdentityCredential

CONTAINER_PKS = {"households": "/id", "chronicles": "/householdId", "contributors": "/householdId"}


def _db():
    endpoint = os.environ.get("COSMOS_ENDPOINT") or os.environ.get(
        "CosmosDBConnection__accountEndpoint"
    )
    database = os.environ.get("COSMOS_DATABASE") or "memorywell"
    if not endpoint:
        return None
    client_id = os.environ.get("CosmosDBConnection__clientId")
    cred = (
        ManagedIdentityCredential(client_id=client_id) if client_id else ManagedIdentityCredential()
    )
    return CosmosClient(endpoint, credential=cred).get_database_client(database)


def container(db, name):
    pk = CONTAINER_PKS[name]
    if name not in {c["id"] for c in db.list_containers()}:
        db.create_container_if_not_exists(id=name, partition_key=PartitionKey(path=pk))
    return db.get_container_client(name)


def now():
    return datetime.datetime.now(datetime.UTC).isoformat()


def new_id():
    return str(uuid.uuid4())
