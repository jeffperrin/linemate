# Linemate

A SQLite-specific object-relational mapper for Ruby. A linemate skates alongside you — this gem pairs each Ruby object with its row.

Linemate follows the [Active Record pattern](https://martinfowler.com/eaaCatalog/activeRecord.html) with an API in the spirit of Rails' ActiveRecord, but it only ever talks to SQLite and it keeps the surface small. Attributes are declared on the model, in the style of [Literal](https://literal.fun/docs/properties.html) properties, rather than read from the database schema.

## What works today

- One global configuration, one SQLite handle per thread, reopened after `fork`. Safe under threaded or forking job queues.
- `col` declarations with typed attributes: `Int`, `Float`, `String`, `Boolean`, `Date`, `DateTime`, `Blob`, `JSON`, plus your own types.
- Lazy, chainable, immutable relations: `where`, `where.not`, `order`, `limit`, `offset`, `select`, `find`, `find_by`, `first`, `last`, `count`, `pluck`, `sum`, `minimum`, `maximum`, `exists?`.
- Read-only associations: `belongs_to`, `has_many`, `has_one`.
- Persistence: `save`, `create`, `update`, `destroy`, `reload`, with dirty tracking and callbacks.
- `create_table` generated from the model's declarations, foreign keys included.
- Every value is a bound parameter. Nothing is interpolated into SQL.

Not yet: validations. Preloading is deliberately out of scope: with an in-process database the extra queries cost a function call each, not a network round trip.

## Installation

Not yet released to RubyGems. Install from git:

```ruby
gem "linemate", git: "https://github.com/jeffperrin/linemate"
```

Requires Ruby 3.4 or newer.

## Usage

### Connecting

```ruby
Linemate.connect("league.sqlite3")   # or ":memory:"
```

`connect` stores configuration only. Each thread opens its own handle on first use and keeps it. A handle inherited across a `fork` is discarded and reopened in the child. Every handle enables WAL journaling, a five second busy timeout and foreign key enforcement. Call `Linemate.disconnect` from a thread that is finishing to close its handle.

### Defining models

```ruby
class League < Linemate::Model
  col :id, Int
  col :name, String
  col :created_at, DateTime
  has_many :divisions, "Division"
end

class Division < Linemate::Model
  col :id, Int
  col :name, String
  col :league_id, Int
  belongs_to League
  has_many :teams, "Team"
end

class Team < Linemate::Model
  col :id, Int
  col :name, String
  col :active, Boolean, default: true
  col :division_id, Int
  belongs_to Division
  has_many :players, "Player"
  has_many :home_games, "Game", foreign_key: :home_team_id
end

class Player < Linemate::Model
  table "roster"                       # overrides the inferred "players"
  col :id, Int
  col :name, String
  col :position, String
  col :goals, Int, default: 0
  col :born_on, Date, null: true
  col :team_id, Int, null: true
  belongs_to Team
end

class Game < Linemate::Model
  col :id, Int
  col :played_at, DateTime
  col :home_team_id, Int
  col :away_team_id, Int
  belongs_to Team, as: :home_team      # reader :home_team, key :home_team_id
  belongs_to Team, as: :away_team
end
```

The table name is inferred from the class name unless you call `table`. A column named `id` is the primary key unless another column is declared with `primary: true`. Columns are `null: false` by default; assigning `nil` to one raises `Linemate::NotNullViolation`.

Type constants resolve inside a model body because `Linemate::Model` includes `Linemate::Types`. That means `String`, `Float` and `Date` inside a model body name the Linemate types, not the core classes. Write `::String` if you need the core class there.

A custom type is any object that responds to `cast`, `serialize`, `deserialize` and `sql_type`.

### Fetching

```ruby
Team.find(1)                          # raises Linemate::RecordNotFound if missing
Team.find_by(name: "Leafs")           # Team or nil
Team.all                              # a lazy Relation
Team.count
Team.first / Team.last                # ordered by primary key when no order is given

Player.where(position: "C")
      .where("goals > ?", 20)
      .order(goals: :desc)
      .limit(5)
      .to_a

Player.where(id: [1, 2, 3])           # IN
Player.where(team_id: nil)            # IS NULL
Player.where(goals: 20..40)           # BETWEEN
Player.where.not(position: "G")

Player.where(team_id: 1).pluck(:name)
Player.pluck(:id, :name)              # => [[1, "..."], ...]
Player.sum(:goals)
Player.maximum(:born_on)              # => Date
```

Hash conditions are cast through the column's type before binding, so `where(active: true)` binds `1` and `where(born_on: Date.new(2000, 1, 1))` binds ISO 8601 text. SQL fragments take positional `?` binds and pass their values through untouched.

### Associations

```ruby
Team.find(1).players                  # a Relation, scoped to the team
Team.find(1).players.where(position: "G").count
Player.find(7).team                   # a Team, cached on the instance
Player.find(7).team.division.league.name
Game.find(3).home_team
```

`belongs_to` infers the reader name and foreign key from the target class (`belongs_to League` gives `league` and `league_id`). The foreign key column must be declared with `col` before the association or the class raises when it loads. `has_many` and `has_one` take the reader name first and the target second. The target may be a class or a string; a string is resolved on first use, which lets you reference a class defined later in the file.

`Model.reflections` and `Model.reflect_on_association(:players)` expose the metadata.

### Saving

```ruby
team = Team.new(name: "Leafs", city: "Toronto", division_id: 1, league_id: 1)
team.save                             # INSERT; team.id is now set
Team.create(name: "Bruins", city: "Boston", division_id: 1, league_id: 1)

team.update(active: false)            # assign and UPDATE
team.reload                           # re-read from the database
team.destroy                          # DELETE; team.destroyed? is true
```

A `null: false` column that is still nil when you save raises `Linemate::NotNullViolation` before any SQL runs. There are no validations yet.

### Dirty tracking

```ruby
team = Team.find(1)
team.name = "Maple Leafs"
team.changed?            # => true
team.changes             # => {name: ["Leafs", "Maple Leafs"]}
team.name_was            # => "Leafs"
team.save
team.saved_changes       # => {name: ["Leafs", "Maple Leafs"]}
```

`save` on a persisted record writes only the changed columns and runs no SQL when nothing changed.

### Callbacks

```ruby
class Team < Linemate::Model
  before_save :slugify
  after_create { puts "welcome, #{name}" }
  before_destroy { throw :abort if players.exists? }

  def slugify
    self.slug = name.downcase.tr(" ", "-")
  end
end
```

Available: `before_save`, `after_save`, `before_create`, `after_create`, `before_update`, `after_update`, `before_destroy`, `after_destroy`. Each takes a method name or a block. `throw :abort` in a before callback halts the operation; `save` and `destroy` then return false. Order on save is `before_save`, `before_create` or `before_update`, the SQL, then the matching after callbacks.

### Creating tables

```ruby
League.create_table
Team.create_table(if_not_exists: true)
Team.table_exists?
Team.drop_table
puts Team.create_table_sql
```

The generated DDL uses each column's SQLite type, `NOT NULL` unless `null: true`, the serialized default, and a `FOREIGN KEY` for every `belongs_to`. Create parent tables before children.

### Introspection

```ruby
Player.table          # => "roster"
Player.primary_key    # => :id
Player.column_names   # => [:id, :name, :position, ...]
Player.column(:born_on).sql_type   # => "TEXT"
Player.where(position: "C").to_sql # => SELECT * FROM "roster" WHERE ("position" = ?)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

`rake` runs the tests and standardrb. CI runs both on every pull request.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jeffperrin/linemate.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
