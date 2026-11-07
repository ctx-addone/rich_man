# Save migration fixtures

`round8-v1.rms` is the genuine round8 v1 binary save produced by `tests/save_test.gd`, retained before the round9 schema changes. It was copied from `.godot/save-test.rms`; it is not regenerated with the current serializer.

- Source baseline: commit `1340b2c0a869484a5175bc93ffa192c229196b0c`.
- SHA-256: `C09990DEE6711A615FAD37423964B26A65196BBE8037E240BE1414E23A5598CD`.
- `tests/round9_save_test.gd` verifies this hash, loads the file, compares every original state field, preserves the original map, and rejects missing old-schema fields instead of silently filling them.

Do not replace this fixture during ordinary test runs. Future schema migrations should add separate historical fixtures.

`round9-v2.rms` is the genuine round9 v2 lottery service save copied from `.godot/round9-lottery.rms` before v3 changes. It retains an unfinished movement, a purchased ticket, and the service-enabled road layout.

- SHA-256: `4BF053671BF73A0F0B962C72CEEBFEE0E716A6A25147F38332187CE7A7AACB9F`.
- `tests/round10_save_test.gd` verifies both fixture hashes and their encoded versions, restores their original fields and random states, and resumes the pending lottery movement.
- v3 migration adds independent teams to legacy players with missing/null/negative integer/empty string/`"-1"` team metadata. Other legacy integer or string labels are normalized by relationship, with integer and string identifiers kept distinct. It does not merge players merely because their labels are absent.
- After validating original winner indices and uniqueness, completed v1/v2 games are explicitly rescored using the normalized team relationships. This can expand an old individual winner to their teammates; completed v3 games instead reject inconsistent winner lists. This is a schema migration policy, not a newly verified original-game rule.
- In v3 the only fields eligible for filling were the eight v2 service fields when reading v1, plus per-player team metadata when reading v1/v2. Missing required fields from an existing schema remain errors.

`round10-v3.rms` is the genuine round10 v3 team save copied from `.godot/round10-team-save.rms` before the v4 map-schema change.

- Source baseline: commit `12f8d08640df93cf40fa3ae7f7c438a041201f16`.
- SHA-256: `B037992F9F3F6B2B2AAE5997DC6138F7F745344AEEEE5724FE9C15CF0372EBFD`.
- v4 explicitly adds `map_id`, canonical `map_metadata`, `start_road`, and `start_bonus` when reading v1/v2/v3. Historical saves are bound to the integration map and retain their original service toggles. Existing fields are not silently overwritten.
- `tests/round11_save_test.gd` verifies historical field/RNG preservation and rejects altered map identities and static layouts.
