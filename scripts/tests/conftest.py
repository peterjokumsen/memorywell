"""Shared pytest setup for scripts/tests.

Puts scripts/ on sys.path so `import seed` and `from fakes import ...` resolve
however pytest is invoked — from scripts/, from the repo root, or with a
rootdir above both.

api/tests/test_main.py does this per file with a sys.path insert plus a
`# noqa: E402` on the import that follows. With one test module that is fine;
with three it is noise, and the noqa markers are pure overhead.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
