# frozen_string_literal: true

module Linemate
  # A deliberately small inflector. Covers the common English cases needed
  # for table and association naming without pulling in ActiveSupport.
  module Inflector
    IRREGULARS = {
      "person" => "people",
      "man" => "men",
      "woman" => "women",
      "child" => "children",
      "foot" => "feet",
      "tooth" => "teeth",
      "goose" => "geese",
      "mouse" => "mice",
      "ox" => "oxen"
    }.freeze

    UNCOUNTABLES = %w[equipment information rice money species series fish sheep deer staff].freeze

    PLURAL_RULES = [
      [/(quiz)$/i, '\1zes'],
      [/(matr|vert|ind)(?:ix|ex)$/i, '\1ices'],
      [/(x|ch|ss|sh)$/i, '\1es'],
      [/([^aeiouy]|qu)y$/i, '\1ies'],
      [/([^f])fe$/i, '\1ves'],
      [/([lr]|ea)f$/i, '\1ves'],
      [/sis$/i, "ses"],
      [/([ti])um$/i, '\1a'],
      [/(alias|status)$/i, '\1es'],
      [/(octop|vir)us$/i, '\1i'],
      [/(bus)$/i, '\1es'],
      [/s$/i, "s"],
      [/$/, "s"]
    ].freeze

    SINGULAR_RULES = [
      [/(quiz)zes$/i, '\1'],
      [/(matr)ices$/i, '\1ix'],
      [/(vert|ind)ices$/i, '\1ex'],
      [/(octop|vir)i$/i, '\1us'],
      [/(alias|status|bus)es$/i, '\1'],
      [/([ti])a$/i, '\1um'],
      [/(analy|ba|diagno|parenthe|progno|synop|the)ses$/i, '\1sis'],
      [/([lr]|ea)ves$/i, '\1f'],
      [/([^f])ves$/i, '\1fe'],
      [/([^aeiouy]|qu)ies$/i, '\1y'],
      [/(x|ch|ss|sh)es$/i, '\1'],
      [/([^s])s$/i, '\1']
    ].freeze

    module_function

    def pluralize(word)
      word = word.to_s
      return word if UNCOUNTABLES.include?(word.downcase)
      return IRREGULARS[word] if IRREGULARS.key?(word)

      PLURAL_RULES.each do |rule, replacement|
        return word.sub(rule, replacement) if word.match?(rule)
      end
      word
    end

    def singularize(word)
      word = word.to_s
      return word if UNCOUNTABLES.include?(word.downcase)
      return IRREGULARS.key(word) if IRREGULARS.value?(word)

      SINGULAR_RULES.each do |rule, replacement|
        return word.sub(rule, replacement) if word.match?(rule)
      end
      word
    end

    # "HomeGame" => "home_game", "Linemate::Team" => "team"
    def underscore(word)
      word.to_s
        .split("::").last
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr("-", "_")
        .downcase
    end

    # "home_game" => "HomeGame"
    def camelize(word)
      word.to_s.split("_").map(&:capitalize).join
    end

    # "HomeGame" => "home_games"
    def tableize(class_name)
      pluralize(underscore(class_name))
    end
  end
end
