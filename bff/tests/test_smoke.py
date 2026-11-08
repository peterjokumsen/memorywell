import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import function_app


def test_app_exists():
    assert function_app.app is not None
