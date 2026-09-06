# frozen_string_literal: true

module Hockey
  class League < Linemate::Model
    col :id, Int
    col :name, String
    col :founded_on, Date
    col :created_at, DateTime
    has_many :divisions, "Hockey::Division"
    has_many :teams, "Hockey::Team"
  end

  class Division < Linemate::Model
    col :id, Int
    col :name, String
    col :league_id, Int
    belongs_to League
    has_many :teams, "Hockey::Team"
  end

  class Team < Linemate::Model
    col :id, Int
    col :name, String
    col :city, String
    col :active, Boolean, default: true
    col :division_id, Int
    col :league_id, Int
    belongs_to Division
    belongs_to League
    has_many :players, "Hockey::Player"
    has_one :captain, "Hockey::Player", foreign_key: :captain_of_id
    has_many :home_games, "Hockey::Game", foreign_key: :home_team_id
    has_many :away_games, "Hockey::Game", foreign_key: :away_team_id
  end

  class Player < Linemate::Model
    table "roster"
    col :id, Int
    col :name, String
    col :position, String
    col :goals, Int, default: 0
    col :assists, Int, default: 0
    col :born_on, Date, null: true
    col :team_id, Int, null: true
    col :captain_of_id, Int, null: true
    belongs_to Team

    def points
      goals + assists
    end
  end

  class Game < Linemate::Model
    col :id, Int
    col :played_at, DateTime
    col :home_team_id, Int
    col :away_team_id, Int
    col :home_score, Int
    col :away_score, Int
    col :overtime, Boolean, default: false
    belongs_to Team, as: :home_team
    belongs_to Team, as: :away_team
  end
end
