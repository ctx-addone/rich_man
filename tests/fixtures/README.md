# Save migration fixtures

`round8-v1.rms` is the genuine round8 v1 binary save produced by `tests/save_test.gd`, retained before the round9 schema changes. It was copied from `.godot/save-test.rms`; it is not regenerated with the current serializer.

- Source baseline: commit `1340b2c0a869484a5175bc93ffa192c229196b0c`.
- SHA-256: `C09990DEE6711A615FAD37423964B26A65196BBE8037E240BE1414E23A5598CD`.
- `tests/round9_save_test.gd` verifies this hash, loads the file, compares every original state field, preserves the original map, and rejects missing old-schema fields instead of silently filling them.

Do not replace this fixture during ordinary test runs. Future schema migrations should add separate historical fixtures.
