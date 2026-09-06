# frozen_string_literal: true

module Hockey
  SEED = <<~SQL
    INSERT INTO leagues VALUES (1, 'NHL', '1917-11-26', '2020-01-01T00:00:00.000000Z');
    INSERT INTO leagues VALUES (2, 'PWHL', '2023-08-29', '2023-08-29T12:00:00.000000Z');

    INSERT INTO divisions VALUES (1, 'Atlantic', 1), (2, 'Metropolitan', 1), (3, 'Central', 1);

    INSERT INTO teams VALUES (1, 'Maple Leafs', 'Toronto', 1, 1, 1, 'Scotiabank Arena');
    INSERT INTO teams VALUES (2, 'Bruins', 'Boston', 1, 1, 1, 'TD Garden');
    INSERT INTO teams VALUES (3, 'Penguins', 'Pittsburgh', 1, 2, 1, NULL);
    INSERT INTO teams VALUES (4, 'Whalers', 'Hartford', 0, 2, 1, NULL);
    INSERT INTO teams VALUES (5, 'Avalanche', 'Denver', 1, 3, 1, 'Ball Arena');

    INSERT INTO roster VALUES (1, 'Auston Matthews', 'C', 69, 38, '1997-09-17', 1, 1);
    INSERT INTO roster VALUES (2, 'Mitch Marner', 'RW', 26, 59, '1997-05-05', 1, NULL);
    INSERT INTO roster VALUES (3, 'Morgan Rielly', 'D', 7, 51, '1994-03-09', 1, NULL);
    INSERT INTO roster VALUES (4, 'David Pastrnak', 'RW', 47, 63, '1996-05-25', 2, NULL);
    INSERT INTO roster VALUES (5, 'Brad Marchand', 'LW', 29, 38, '1988-05-11', 2, 2);
    INSERT INTO roster VALUES (6, 'Sidney Crosby', 'C', 42, 52, '1987-08-07', 3, 3);
    INSERT INTO roster VALUES (7, 'Evgeni Malkin', 'C', 27, 40, '1986-07-31', 3, NULL);
    INSERT INTO roster VALUES (8, 'Nathan MacKinnon', 'C', 51, 89, '1995-09-01', 5, 5);
    INSERT INTO roster VALUES (9, 'Cale Makar', 'D', 21, 69, '1998-10-30', 5, NULL);
    INSERT INTO roster VALUES (10, 'Free Agent', 'G', 0, 0, NULL, NULL, NULL);

    INSERT INTO games VALUES (1, '2024-10-09T23:00:00.000000Z', 1, 2, 3, 2, 1);
    INSERT INTO games VALUES (2, '2024-10-12T23:00:00.000000Z', 2, 1, 4, 1, 0);
    INSERT INTO games VALUES (3, '2024-10-15T23:00:00.000000Z', 3, 1, 2, 5, 0);
    INSERT INTO games VALUES (4, '2024-10-20T01:00:00.000000Z', 5, 3, 6, 3, 0);
  SQL

  def self.seed
    Linemate.connection.database.execute_batch(SEED)
  end

  def self.setup!
    Linemate.connect(":memory:")
    create_schema
    seed
  end
end
