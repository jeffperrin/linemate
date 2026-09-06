## [Unreleased]

- Dirty tracking: `changed?`, `changes`, `saved_changes`, `name_changed?`, `name_was`; updates write only changed columns.
- Callbacks: before/after save, create, update and destroy; `throw :abort` halts.

- Connection layer: global configuration, one SQLite handle per thread, reopened after fork, with WAL, busy timeout and foreign keys enabled.
- `Linemate::Model` with `col` declarations, `table` override and a hand-rolled inflector.
- Column types `Int`, `Float`, `String`, `Boolean`, `Date`, `DateTime`, `Blob`, `JSON`; custom types via `cast`/`serialize`/`deserialize`/`sql_type`.
- Lazy, immutable `Relation` with `where`, `where.not`, `order`, `limit`, `offset`, `select`, `find`, `find_by`, `first`, `last`, `count`, `pluck`, `sum`, `minimum`, `maximum`, `exists?`.
- Read-only `belongs_to`, `has_many` and `has_one` associations with reflections.
- Persistence: `save`, `create`, `update`, `destroy`, `reload`.
- `create_table`, `drop_table`, `table_exists?` and `create_table_sql` generated from model declarations.
- CI runs tests, standardrb and a coverage check on every pull request.

## [0.1.0] - 2026-08-25

- Initial release
