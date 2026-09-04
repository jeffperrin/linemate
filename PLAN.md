# Plan: Mapping and fetching (read side of the Active Record pattern)

Scope: everything needed to map a Ruby class to a SQLite table and fetch rows
as objects. Persistence (`save`, `create`, `update`, `destroy`), validations,
callbacks and schema generation are deliberately out of scope for this plan,
but the column model is designed so schema generation can be added later
without changing the model API.

## Target API (hockey league example)

```ruby
Linemate.connect("league.sqlite3")          # or ":memory:"

class League < Linemate::Model
  col :id, Int
  col :name, String
  col :created_at, DateTime
  has_many :divisions, "Division"           # string: resolved on first use
end

class Division < Linemate::Model
  col :id, Int
  col :name, String
  belongs_to League                         # name :league, key :league_id
  has_many :teams, "Team"
end

class Team < Linemate::Model
  col :id, Int
  col :name, String
  col :active, Boolean, default: true
  belongs_to Division
  has_many :players, "Player"
  has_many :home_games, "Game", foreign_key: :home_team_id
end

class Player < Linemate::Model
  table "roster"                            # override the inferred "players"
  col :id, Int
  col :name, String
  col :position, String
  col :goals, Int, default: 0
  col :born_on, Date, null: true
  belongs_to Team
end

class Game < Linemate::Model
  col :id, Int
  col :played_at, DateTime
  belongs_to Team, as: :home_team           # key :home_team_id
  belongs_to Team, as: :away_team
end

Team.find(1)                                # => #<Team id: 1, name: "Leafs", ...>
Team.find_by(name: "Leafs")                 # => Team or nil
Team.all                                    # => Relation (lazy)
Player.where(position: "C").where("goals > ?", 20).order(goals: :desc).limit(5).to_a
Team.count
Team.first / Team.last
Team.find(1).players                        # => Relation
Player.find(7).team                         # => Team
Player.find(7).team.division.league.name
Player.where(team_id: 1).pluck(:name)
Team.columns                                # => [#<Column id Int primary>, ...]
```

Design principles, in priority order:

1. SQLite only. Use its features (WAL, `rowid`, `busy_timeout`, `typeof`)
   rather than abstracting over dialects.
2. Attributes are declared on the model with `col`, never read from the
   database schema. The model is the source of truth, so a fresh database
   can later be created from the model definitions alone.
3. Relations are lazy, immutable and chainable. Every chain method returns a
   new `Relation`; SQL runs on `to_a`, `each`, `first`, `count`, etc.
4. Every SQL statement uses bound parameters. No string interpolation of
   values, ever.
5. Small surface. Ship the handful of methods above well before adding more.

## Work breakdown

Each step is one PR-sized change with its own tests. Order matters: each step
builds on the previous one.

### 1. Dependency and connection

- Add `sqlite3 ~> 2.0` as a runtime dependency in `linemate.gemspec`.
- `Linemate.connect(path, **opts)` stores the *configuration* globally. It
  does not hold a single shared database handle.
- `Linemate.connection` returns a connection that is local to the current
  thread (stored in a `Thread#thread_variable`, which is per thread rather
  than per fiber). It is opened lazily on first use and cached. This is
  what makes a job queue like Benchwarmer safe: each worker thread gets its
  own SQLite handle, so transactions and cursors never interleave across
  threads, while the API stays global and needs no connection passing.
- Fork safety: the cached connection records the pid that opened it. If
  `Process.pid` differs on access, the stale handle is discarded and a new
  one opened. Forked workers therefore never share a handle with the parent.
- Concurrency pragmas on every open: `journal_mode = WAL` so readers do not
  block writers, `busy_timeout = 5000` so concurrent workers wait instead of
  raising `SQLITE_BUSY`, and `foreign_keys = ON`.
- `Linemate.disconnect` closes the current thread's handle;
  `Linemate.disconnect_all` is not attempted since other threads own their
  handles. Document that long-lived worker pools should call `disconnect`
  when a thread exits.
- `Linemate::Connection` wraps the raw database: `execute(sql, binds)`,
  `select_all`, `select_one`, `select_value`, `transaction { }`.
  Everything else in the gem talks to this wrapper, never to `SQLite3`
  directly, so the raw gem can be swapped or stubbed in tests.
- Raise `Linemate::ConnectionNotEstablished` when used before `connect`.
- Test: two threads open connections and assert they are distinct objects;
  a forked child (skipped on platforms without fork) gets a fresh handle.

Files: `lib/linemate.rb`, `lib/linemate/connection.rb`,
`lib/linemate/errors.rb`, `test/connection_test.rb`.

### 2. Model class, `col`, and table mapping

- `Linemate::Model` with class-level `table "name"` (settable) and
  inference from the class name: `Team` → `teams`, `HomeGame` →
  `home_games`. Write a tiny inflector (`underscore`, `pluralize` with a
  short irregulars list, `singularize`, `camelize`). No ActiveSupport.
- `col name, type, null: false, default: nil, primary: false` declares an
  attribute. A column named `id` is the primary key by default; `primary:
  true` on another column overrides that. Declarations are stored in order
  as `Linemate::Column` objects (`name`, `type`, `null`, `default`,
  `primary`) and exposed by `Model.columns`, `Model.column(name)`,
  `Model.primary_key`.
- Subclassing a model copies its columns, so abstract base models work.
- `Column` knows its SQLite declared type via `type.sql_type`, so a future
  `Model.create_table` can be written from `columns` alone. No such method
  in this plan, but the integration test builds the fixture schema by hand
  to match the declarations exactly.
- Raise `Linemate::UnknownColumn` when a query or attribute references a
  name that was not declared.

Files: `lib/linemate/model.rb`, `lib/linemate/inflector.rb`,
`lib/linemate/column.rb`, `test/model_test.rb`, `test/inflector_test.rb`.

### 3. Types and attributes

Types follow the shape of Literal properties: a type is an object that
knows how to check, coerce and store a value. They are constants in
`Linemate::Types`, which `Model` includes, so `Int`, `String`, `Boolean`
resolve inside a model body without polluting the top level.

- Built-in types: `Int`, `Float`, `String`, `Boolean`, `Date`, `DateTime`
  (returns `Time` in UTC), `Blob`, `JSON` (serialised to TEXT). `String`,
  `Float`, `Date` reuse the Ruby class names; the constants in
  `Linemate::Types` shadow them only inside model bodies.
- Each type responds to `cast(value)` (Ruby → canonical Ruby, e.g. `"12"`
  → `12` for `Int`), `serialize(value)` (Ruby → SQLite value),
  `deserialize(value)` (SQLite value → Ruby) and `sql_type` (`INTEGER`,
  `REAL`, `TEXT`, `BLOB`). Booleans store as 0/1, dates as ISO 8601 text,
  datetimes as UTC ISO 8601 text.
- Custom types: any object with those four methods works, so users can
  add their own (`col :status, Status`).
- Nil handling: writing nil to a `null: false` column raises
  `Linemate::NotNullViolation` at assignment time (cheap and explicit).
  `null: true` columns pass nil through untouched.
- `Model#initialize(attributes = {})` casts through the declared types and
  raises `Linemate::UnknownColumn` on undeclared keys.
  `Model.instantiate(row)` is the load path: it deserialises each declared
  column from the row hash and marks the record persisted. Columns present
  in the table but not declared are ignored.
- Reader and writer methods are defined by `col` at declaration time with
  `define_method`, so `team.name` is a real method.
- `[]`, `[]=`, `attributes`, `attribute_names`, `id`, `persisted?`,
  `new_record?`, `==` (same class and same id), `hash`, `inspect`.

Files: `lib/linemate/types.rb`, `lib/linemate/attributes.rb`,
`test/types_test.rb`, `test/attributes_test.rb`.

### 4. Query building: `Relation`

The centre of the fetch side. Keep the SQL builder and the relation as
separate objects so the builder can be tested without a database.

- `Linemate::Relation` holds `model`, and frozen `where_clauses`,
  `order_clauses`, `limit_value`, `offset_value`, `select_values`.
  Chain methods (`where`, `order`, `limit`, `offset`, `select`, `reorder`,
  `unscope`) return a new relation via `spawn`.
- `where` accepts a hash (`{position: "C"}`, `{id: [1, 2, 3]}` → `IN`,
  `{captain: nil}` → `IS NULL`, ranges → `BETWEEN`) or a SQL fragment with
  positional binds (`"goals > ?", 20`). `where.not(...)` via a small
  `WhereChain` object.
- `order(:goals)` and `order(goals: :desc)`; `order("RANDOM()")` allowed
  as a raw string.
- Terminal methods: `to_a`, `each` (`Enumerable` over `to_a`), `first`,
  `last` (reverses order, or orders by pk if none), `find(id)`, `find_by`,
  `exists?`, `count`, `pluck(*columns)`, `sum`, `minimum`, `maximum`.
- `Linemate::SQLBuilder` turns a relation into `[sql, binds]`. Identifiers
  are quoted with double quotes. Values are always binds.
- `where` hash keys are validated against `columns`, and values are cast
  through the column type before binding, so `where(active: true)` binds
  `1` and `where(born_on: Date.new(2000, 1, 1))` binds ISO text.
- `Model` delegates the class-level query API (`all`, `where`, `find`,
  `find_by`, `first`, `last`, `count`, `order`, `limit`, `pluck`,
  `exists?`) to `all`, which returns a fresh `Relation`.
- `find` raises `Linemate::RecordNotFound` with the model and id;
  `find_by` returns nil.
- Results are cached on the relation after the first load; `reload`
  clears them.

Files: `lib/linemate/relation.rb`, `lib/linemate/sql_builder.rb`,
`lib/linemate/querying.rb` (the class-level delegation module),
`test/relation_test.rb`, `test/sql_builder_test.rb`, `test/querying_test.rb`.

### 5. Associations (read only)

Associations take the target class as the second argument rather than a
`class_name:` option, matching the `col` style.

- `belongs_to Target, as: nil, foreign_key: nil, primary_key: nil`.
  `as` defaults to the underscored target name (`League` → `:league`),
  `foreign_key` to `#{as}_id`, `primary_key` to the target's pk. Two
  `belongs_to Team` on one model must give distinct `as:` names, and the
  plan raises `Linemate::AssociationError` if they collide. The reader
  returns the record or nil and caches it on the instance.
- `has_many name, Target, foreign_key: nil, primary_key: nil`.
  `foreign_key` defaults to `#{owner_class.underscore}_id`. The reader
  returns a `Relation` scoped with `where(foreign_key => owner.id)`, so it
  chains: `team.players.where(position: "G").count`.
- `has_one name, Target, ...` as the singular form (`first` on the same
  relation).
- The target may be a class or a string. A string is resolved with
  `Object.const_get` on first use. This matters for `has_many`, where the
  target is normally defined *after* the owner: `has_many :divisions,
  Division` inside `League` raises `NameError` if `Division` is not loaded
  yet, so the string form is the documented default for `has_many` and the
  constant form for `belongs_to`, where the target usually already exists.
- Association metadata lives in `Linemate::Reflection` objects stored in
  `Model.reflections`, so `Team.reflect_on_association(:players)` works
  and later features (preloading, writes, schema foreign keys) can reuse
  them. `belongs_to` does not implicitly declare the foreign key column;
  the model must `col :league_id, Int` itself, and the plan raises at class
  load if it is missing, since that is the kind of mistake that is
  otherwise found at runtime.
- Out of scope here, note for later: `has_many :through`, `includes` /
  preloading (N+1 avoidance), `dependent:`, inverse tracking, and
  association writers (`team.players << player`).

Files: `lib/linemate/associations.rb`, `lib/linemate/reflection.rb`,
`test/associations_test.rb`.

### 6. Test fixtures and integration test

- `test/support/models.rb` defines the hockey models from the target API
  above. `test/support/schema.rb` creates the matching tables in an
  in-memory database: `leagues`, `divisions`, `teams`, `roster` (players,
  to exercise a custom table name), `games`. Include a `Boolean`, a `Date`
  and a `DateTime` column to exercise casting, and one table with an extra
  undeclared column to confirm it is ignored on load.
- `test/support/seed.rb` inserts a small dataset with raw SQL (the gem has
  no write side yet).
- `test/test_helper.rb` connects to `":memory:"` and loads schema and seed
  before each test class.
- `test/integration/hockey_test.rb` walks the full target API above
  end to end.

### 7. Documentation and housekeeping

- README: replace "Nothing to see yet" with the target API example and a
  short "what works today" list.
- `sig/linemate.rbs`: signatures for `Model`, `Relation` and `connect`.
- CHANGELOG entry under Unreleased.
- Commit the pending `Gemfile.lock` and gemspec cleanup that are already
  modified in the working tree as their own commit before starting step 1.

## Decisions made

1. **Connection**: global configuration, per-thread lazily opened handle,
   pid check for fork safety, WAL and busy timeout on open. This keeps the
   global-feeling API while remaining safe under a threaded or forking job
   queue.
2. **Attributes**: explicit `col name, Type` declarations in the style of
   Literal properties. The model is the source of truth; schema generation
   from `columns` is a planned follow-up.
3. **Inflector**: hand-rolled, short irregulars list.
4. **Time**: `DateTime` stores UTC ISO 8601 and returns `Time` in UTC.

## Open questions (plan proceeds with the first answer)

1. `has_many :divisions, "Division"` (string) versus `has_many :divisions,
   Division` (constant). The constant reads better but forces a strict
   definition order. Both are supported; docs recommend the string.
2. Should `belongs_to` auto-declare its `_id` column? Plan says no, keep
   columns explicit, and raise if it is missing.
3. Type constant naming: `Int` alongside `String` and `Float`. `Integer`
   is also accepted as an alias of `Int` for people who reach for it.

## Rough sequencing

| Step | Depends on | Size |
|------|-----------|------|
| 1 Connection | – | small |
| 2 Model, `col`, mapping | 1 | medium |
| 3 Types and attributes | 2 | medium |
| 4 Relation and SQL builder | 3 | large |
| 5 Associations | 4 | medium |
| 6 Fixtures and integration | 5 | small |
| 7 Docs | 6 | small |

Steps 3 and the pure `SQLBuilder` part of step 4 can be developed in
parallel since the builder does not need attributes.
