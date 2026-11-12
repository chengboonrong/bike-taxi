"""Embed the checked-in JSON for device tests, without production Flutter assets."""
from pathlib import Path

source = Path('test/fixtures/compute.json').read_text()
assert "'''" not in source
Path('test/fixtures/compute_fixture.dart').write_text(
    '// Generated from compute.json by tool/update_fixture_dart.py.\n'
    "const computeFixtureJson = r'''\n" + source + "''';\n"
)
