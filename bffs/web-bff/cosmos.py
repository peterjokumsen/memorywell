import datetime
import os
import uuid

from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import ManagedIdentityCredential

CONTAINER_PKS = {
    "households": "/id",
    "chronicles": "/householdId",
    "contributors": "/householdId",
    "invites": "/householdId",
    "prompts": "/chronicleId",
    "memories": "/chronicleId",
    "transcripts": "/chronicleId",
    "flags": "/chronicleId",
    "aliasHistory": "/chronicleId",
}


def _db():
    endpoint = os.environ.get("COSMOS_ENDPOINT") or os.environ.get(
        "CosmosDBConnection__accountEndpoint"
    )
    database = os.environ.get("COSMOS_DATABASE") or "memorywell"
    if not endpoint:
        return None
    key = os.environ.get("COSMOS_KEY")
    verify = not ("localhost" in endpoint or os.environ.get("COSMOS_DISABLE_SSL_VERIFY") == "1")
    if key:
        client = CosmosClient(endpoint, credential=key, connection_verify=verify)
    else:
        client_id = os.environ.get("CosmosDBConnection__clientId")
        cred = (
            ManagedIdentityCredential(client_id=client_id)
            if client_id
            else ManagedIdentityCredential()
        )
        client = CosmosClient(endpoint, credential=cred, connection_verify=verify)
    return client.create_database_if_not_exists(id=database)


def container(db, name):
    pk = CONTAINER_PKS[name]
    if name not in {c["id"] for c in db.list_containers()}:
        db.create_container_if_not_exists(id=name, partition_key=PartitionKey(path=pk))
    return db.get_container_client(name)


def now():
    return datetime.datetime.now(datetime.UTC).isoformat()


def new_id():
    return str(uuid.uuid4())


def soft_delete(doc):
    doc["deletedAt"] = now()
    doc["isDeleted"] = True
    return doc


def is_deleted(doc):
    return bool(doc.get("isDeleted")) or doc.get("deletedAt")
