# frozen_string_literal: true

require 'forwardable'
require_relative 'loader'

module Unlocodes
  # In-memory, lazily-indexed registry over a set of {Entry} instances.
  #
  # The default registry is loaded from the vendored dataset bundled with the
  # gem (see {.load_default}). Callers can also construct a registry from any
  # other source via {.from_entries} or {.load_file}.
  class Registry
    include Enumerable
    extend Forwardable

    attr_reader :entries

    def_delegators :@entries, :size, :count, :to_a, :empty?

    # Map of `#where` filter keys to the Entry attribute they read.
    # Limited to attributes the JSON-LD vocabulary actually populates —
    # status / iata / name_without_diacritics are NOT in the vocab, so
    # they're intentionally absent here.
    SCALAR_FILTERS = {
      code: :code,
      country: :country,
      subdivision: :subdivision
    }.freeze

    def initialize(entries = [])
      @entries = entries.freeze
    end

    def each(&)
      @entries.each(&)
    end

    class << self
      # Load the bundled dataset shipped inside the gem.
      # @return [Registry]
      def load_default
        from_entries(Loader.load_file(default_data_path))
      end

      # Load a specific JSON-LD file from disk.
      # @param path [String]
      # @return [Registry]
      def load_file(path)
        from_entries(Loader.load_file(path))
      end

      # Build a registry from an existing list of entries.
      # @param entries [Array<Unlocodes::Entry>]
      # @return [Registry]
      def from_entries(entries)
        new(entries)
      end

      private

      def default_data_path
        File.expand_path('data/locode.jsonld', __dir__)
      end
    end

    # Exact-code lookup.
    # @param code [String] 5-char LOCODE (case-insensitive)
    # @return [Unlocodes::Entry, nil]
    def find(code)
      return nil if code.nil?

      by_code[code.to_s.upcase]
    end

    alias [] find

    # Filter entries by one or more predicates. Scalar filters accept either
    # a single value or an array (any-of). `name` accepts a String
    # (case-insensitive equality) or a Regexp.
    #
    # @example
    #   registry.where(country: 'CN')
    #   registry.where(country: %w[CN HK], function: 'B')
    #   registry.where(name: /shanghai/i)
    #
    # @return [Array<Unlocodes::Entry>]
    def where(filters)
      filters.reduce(entries) { |scope, (key, value)| apply_filter(scope, key, value) }
    end

    # All distinct country codes present in the registry, sorted.
    # @return [Array<String>]
    def countries
      entries.map(&:country).compact.uniq.sort
    end

    # Count of entries per country code.
    # @return [Hash{String=>Integer}]
    def counts_by_country
      entries.each_with_object(Hash.new(0)) { |e, h| h[e.country] += 1 if e.country }
    end

    def by_country(country_code)
      by_country_index[country_code.to_s.upcase] || []
    end

    def by_function(letter)
      by_function_index[letter.to_s.upcase] || []
    end

    private

    def by_code
      @by_code ||= entries.each_with_object({}) do |e, h|
        h[e.code.to_s.upcase] = e if e.code
      end
    end

    def by_country_index
      @by_country_index ||= entries.each_with_object({}) do |e, h|
        (h[e.country.to_s.upcase] ||= []) << e if e.country
      end
    end

    def by_function_index
      @by_function_index ||= entries.each_with_object({}) do |e, h|
        (e.function_codes || []).each { |c| (h[c.to_s.upcase] ||= []) << e }
      end
    end

    def apply_filter(scope, key, value)
      if SCALAR_FILTERS.key?(key)
        filter_scalar(scope, SCALAR_FILTERS.fetch(key), value)
      elsif %i[function function_code].include?(key)
        filter_function(scope, value)
      elsif key == :name
        filter_name(scope, value)
      else
        raise ArgumentError, "unknown filter: #{key.inspect}"
      end
    end

    def filter_scalar(scope, attr_name, value)
      candidates = Array(value).map { |v| v.to_s.upcase }
      scope.select do |e|
        attr_val = e.public_send(attr_name)
        attr_val && candidates.include?(attr_val.to_s.upcase)
      end
    end

    def filter_function(scope, value)
      letters = Array(value).map { |v| v.to_s.upcase }
      scope.select { |e| (e.function_codes || []).any? { |c| letters.include?(c.upcase) } }
    end

    def filter_name(scope, value)
      scope.select { |e| e.name && name_matches?(e.name, value) }
    end

    def name_matches?(string, value)
      value.is_a?(Regexp) ? string.match?(value) : string.casecmp?(value.to_s)
    end
  end
end
