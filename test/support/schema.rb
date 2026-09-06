# frozen_string_literal: true

module Hockey
  MODELS = [League, Division, Team, Player, Game].freeze

  def self.create_schema
    MODELS.each(&:create_table)
    Linemate.connection.execute("ALTER TABLE teams ADD COLUMN arena TEXT")
  end
end
