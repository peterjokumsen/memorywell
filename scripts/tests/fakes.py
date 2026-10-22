"""Doubles for the live clients scripts/seed.py talks to.

Stand-ins only — no Azure SDK behaviour is reproduced. Each records what the
seed asked for so a test can assert on it, which is all a unit test needs:

    fake = FakeCosmosDb()
    seed.seed_cosmos(fake)
    assert fake.docs_in("memories")

The alternative, unittest.mock, would assert on call syntax and break every
time the implementation legitimately changes shape. These mirror the SDK's real
method names (upsert_item, create_container_if_not_exists, ping) so a swap to
mocks later is mechanical.
"""

from __future__ import annotations

from typing import Any


class FakeSecret:
    """Minimal stand-in for a Key Vault secret."""

    def __init__(self, value: str) -> None:
        self.value = value


class FakeSecretClient:
    """Records the vault URL it was built with, returns fixed secrets."""

    def __init__(self, vault_url: str, secrets: dict[str, str]) -> None:
        self.vault_url = vault_url
        self.requested: list[str] = []
        self._secrets = secrets

    def get_secret(self, name: str) -> FakeSecret:
        self.requested.append(name)
        return FakeSecret(self._secrets[name])


class FakeCosmosContainer:
    """An in-memory container. The important method is upsert_item."""

    def __init__(self, name: str) -> None:
        self.name = name
        self.items: dict[str, dict[str, Any]] = {}
        self.upsert_calls: list[dict[str, Any]] = []
        # Present so a test can assert create_item is never used: the seed must
        # upsert, because the verify check runs it twice and create_item 409s.
        self.create_calls: list[dict[str, Any]] = []

    def upsert_item(self, body: dict[str, Any]) -> None:
        self.upsert_calls.append(body)
        self.items[body["id"]] = body

    def create_item(self, body: dict[str, Any]) -> None:
        self.create_calls.append(body)
        if body["id"] in self.items:
            raise RuntimeError(f"create_item called on existing id {body['id']!r} in {self.name}")
        self.items[body["id"]] = body

    def read_all_items(self, max_item_count: int | None = None) -> list[dict[str, Any]]:
        items = list(self.items.values())
        return items[:max_item_count] if max_item_count else items

    def query_items(self, query: str, **kwargs: Any) -> list[Any]:
        """Answers the one aggregate query the seed runs: VALUE COUNT(1).

        Returns bare numbers, like the SDK does for a VALUE aggregate, so a
        caller reading rows[0] works against both. Any other query is a bug in
        the seed, not something to emulate — assert rather than silently return
        something plausible.
        """
        assert "COUNT(1)" in query, f"fake only answers COUNT queries, got: {query!r}"
        return [len(self.items)]


class FakeCosmosDb:
    """A database whose containers already exist, as they do after provision-env.sh."""

    def __init__(self, container_names: tuple[str, ...] = ()) -> None:
        self.containers = {name: FakeCosmosContainer(name) for name in container_names}
        self.create_container_calls: list[dict[str, Any]] = []
        # id -> PartitionKey, so a test can assert the partition key that was
        # used. Mirrors the SDK: PartitionKey.path, not a dict.
        self.partition_keys: dict[str, Any] = {}

    def create_container_if_not_exists(self, id: str, partition_key: Any, **kwargs: Any) -> None:
        self.create_container_calls.append({"id": id, "partition_key": partition_key, **kwargs})
        self.partition_keys[id] = partition_key
        self.containers.setdefault(id, FakeCosmosContainer(id))

    def list_containers(self) -> list[dict[str, Any]]:
        """Mirrors the SDK: yields dicts with an 'id' key, not container objects.

        This is how container() decides whether a container already exists, so
        the fake has to answer it the same way the SDK does.
        """
        return [{"id": name} for name in self.containers]

    def get_container_client(self, container: str) -> FakeCosmosContainer:
        return self.containers[container]

    def docs_in(self, container_name: str) -> list[dict[str, Any]]:
        return list(self.containers[container_name].items.values())

    def count_in(self, container_name: str) -> int:
        return len(self.containers[container_name].items)


class FakeCosmosClient:
    """Stands in for CosmosClient; get_client_database hands back the fake db."""

    def __init__(self, endpoint: str, credential: Any = None, **kwargs: Any) -> None:
        self.endpoint = endpoint
        self.credential = credential
        self.requested_databases: list[str] = []
        self.db = FakeCosmosDb()

    def get_client_database(self, database: str) -> FakeCosmosDb:
        self.requested_databases.append(database)
        return self.db


class FakePartitionKey:
    """Cosmos PartitionKey(path=...). Standalone so tests need no Azure import."""

    def __init__(self, path: str) -> None:
        self.path = path

    def __eq__(self, other: object) -> bool:
        return isinstance(other, FakePartitionKey) and other.path == self.path

    def __repr__(self) -> str:
        return f"FakePartitionKey(path={self.path!r})"


class FakeSqlConn:
    """Records executed SQL so tests can assert on the DDL shape."""

    def __init__(self, rows: tuple[Any, ...] = (0,)) -> None:
        self.statements: list[str] = []
        # What fetchone() hands back. main() reads a count out of the database,
        # so the fake needs to answer something row-shaped.
        self.rows: tuple[Any, ...] = rows

    def execute(self, sql: str, params: Any = None) -> FakeSqlConn:
        # Returns something row-shaped, because psycopg's Connection.execute
        # returns a Cursor, not the connection. seed.py chains
        # .execute(...).fetchone() and the fake has to allow that.
        self.statements.append(sql)
        return self

    def fetchone(self) -> tuple[Any, ...]:
        return self.rows

    def cursor(self) -> FakeSqlConn:
        return self

    def commit(self) -> None:
        pass

    def close(self) -> None:
        pass

    def __enter__(self) -> FakeSqlConn:
        return self

    def __exit__(self, *exc: Any) -> None:
        return None

    @property
    def sql(self) -> str:
        return "\n".join(self.statements)


class FakeRedis:
    """ping() returns True and set() records keys, values and any TTL."""

    def __init__(self, pong: bool = True) -> None:
        self._pong = pong
        self.store: dict[str, Any] = {}
        self.set_calls: list[tuple[str, Any, int | None]] = []
        self.ping_calls = 0

    def ping(self) -> bool:
        self.ping_calls += 1
        return self._pong

    def set(self, key: str, value: Any, ex: int | None = None) -> bool:
        self.set_calls.append((key, value, ex))
        self.store[key] = value
        return True

    def get(self, key: str) -> Any:
        return self.store.get(key)
