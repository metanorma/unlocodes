# frozen_string_literal: true

require 'lutaml/model'
require_relative 'coordinates'

module Unlocodes
  # A single UN/LOCODE entry.
  #
  # Stores wire-level fields as `lutaml-model` attributes and exposes typed
  # helpers (#coordinates, .function_description) for ergonomic queries. The
  # LOCODE itself is the 5-character composite of `country` (ISO 3166-1
  # alpha-2) + the 3-character location alpha. The `code` attribute is the
  # canonical 5-char string.
  #
  # `latitude` and `longitude` are decimal degrees (WGS-84), populated when
  # the source vocabulary provides `geo:lat` / `geo:long`.
  class Entry < Lutaml::Model::Serializable
    # UN/LOCODE manual function classifier letters and their human-readable
    # descriptions. Source: UN/LOCODE manual, "Code list for function".
    FUNCTION_DESCRIPTIONS = {
      'B' => 'Port (sea)',
      'R' => 'Rail terminal',
      'T' => 'Road terminal',
      'A' => 'Airport',
      'P' => 'Postal exchange office',
      'I' => 'Inland water transport (river)',
      'F' => 'Ferry port',
      'V' => 'Pipeline',
      'O' => 'Other (border crossing, etc.)',
      '0' => 'Function not known',
      '1' => 'Not provided'
    }.freeze

    attribute :code, :string
    attribute :country, :string
    attribute :subdivision, :string
    attribute :name, :string
    attribute :function_codes, :string, collection: true
    attribute :latitude, :float
    attribute :longitude, :float

    # Look up the human-readable description for a function letter.
    # @param letter [String] single-letter function code (case-insensitive)
    # @return [String, nil] description, or nil if the letter is unknown
    def self.function_description(letter)
      FUNCTION_DESCRIPTIONS[letter.to_s.upcase]
    end

    def function?(letter)
      function_codes&.include?(letter.to_s.upcase)
    end

    def coordinates
      return Coordinates.new(latitude: nil, longitude: nil) if latitude.nil? && longitude.nil?

      Coordinates.new(latitude: latitude, longitude: longitude)
    end

    def port?
      function?('B')
    end

    def airport?
      function?('A')
    end

    def rail_terminal?
      function?('R')
    end

    def road_terminal?
      function?('T')
    end

    def ==(other)
      other.is_a?(Entry) && code == other.code
    end

    def hash
      code&.hash || super
    end

    def eql?(other)
      self == other
    end

    def to_s
      "#{code} #{name}".strip
    end
  end
end
