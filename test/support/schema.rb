# frozen_string_literal: true

# Tables matching test/support/models.rb. Built by hand for now; a future
# Model.create_table will derive the same thing from the declarations.
module Hockey
  SCHEMA = <<~SQL
    CREATE TABLE leagues (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      founded_on TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE TABLE divisions (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      league_id INTEGER NOT NULL REFERENCES leagues(id)
    );
    CREATE TABLE teams (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      city TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      division_id INTEGER NOT NULL REFERENCES divisions(id),
      league_id INTEGER NOT NULL REFERENCES leagues(id),
      arena TEXT -- deliberately not declared on the model
    );
    CREATE TABLE roster (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      position TEXT NOT NULL,
      goals INTEGER NOT NULL DEFAULT 0,
      assists INTEGER NOT NULL DEFAULT 0,
      born_on TEXT,
      team_id INTEGER REFERENCES teams(id),
      captain_of_id INTEGER REFERENCES teams(id)
    );
    CREATE TABLE games (
      id INTEGER PRIMARY KEY,
      played_at TEXT NOT NULL,
      home_team_id INTEGER NOT NULL REFERENCES teams(id),
      away_team_id INTEGER NOT NULL REFERENCES teams(id),
      home_score INTEGER NOT NULL,
      away_score INTEGER NOT NULL,
      overtime INTEGER NOT NULL DEFAULT 0
    );
  SQL

  def self.create_schema(connection = Linemate.connection)
    connection.database.execute_batch(SCHEMA)
  end
end
