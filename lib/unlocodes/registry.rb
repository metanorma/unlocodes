# frozen_string_literal: true

require 'forwardable'
require 'json'
require_relative 'entry'

module Unlocodes
  # In-memory, lazily-indexed registry over a set of {Entry} instances.
  #
  # The Registry owns three concerns end-to-end:
  #
  #   1. Loading — turning the bundled JSON-LD file into Entry instances.
  #   2. Indexing — building fast lookups by code, country, function.
  #   3. Querying — the public find/where/countries surface.
  #
  # Loading and indexing are private; callers (and tests) cross the seam
  # at the query methods. The bundled dataset is parsed once per
  # Registry instance; construct a new Registry from a different source
  # via {.from_entries} or {.load_file}.
  class Registry
    include Enumerable
    extend Forwardable

    # UN/LOCODE function digit (used in `unlcdf:1`..`unlcdf:9` references
    # in the JSON-LD) → letter per the UN/LOCODE manual.
    FUNCTION_DIGIT_TO_LETTER = {
      '1' => 'B', # sea port
      '2' => 'R', # rail terminal
      '3' => 'T', # road terminal
      '4' => 'A', # airport
      '5' => 'P', # postal exchange office
      '6' => 'I', # inland water transport
      '7' => 'F', # ferry port
      '8' => 'V', # pipeline
      '9' => 'O'  # other / border crossing
    }.freeze

    UNLOCODE_TYPE_SUFFIX = 'UNLOCODE'

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
        load_file(default_data_path)
      end

      # Load a specific JSON-LD file from disk.
      # @param path [String]
      # @return [Registry]
      def load_file(path)
        from_entries(parse_json(File.read(path)))
      end

      # Build a registry from an existing list of entries.
      # @param entries [Array<Unlocodes::Entry>]
      # @return [Registry]
      def from_entries(entries)
        new(entries)
      end

      # Parse a JSON-LD string into Entry instances.
      # @param json [String]
      # @return [Array<Unlocodes::Entry>]
      def parse_json(json)
        parse_hash(JSON.parse(json, symbolize_names: false))
      end

      # Parse a pre-parsed JSON-LD hash into Entry instances.
      # @param data [Hash]
      # @return [Array<Unlocodes::Entry>]
      def parse_hash(data)
        extract_graph(data).filter_map { |node| build_entry(node) if unlocode_node?(node) }
      end

      private

      def default_data_path
        File.expand_path('data/locode.jsonld', __dir__)
      end

      def extract_graph(data)
        return [] unless data.is_a?(Hash)

        graph = data['@graph']
        if graph.is_a?(Array)
          graph
        elsif data.key?('@id') || data.key?('rdf:value')
          [data]
        else
          []
        end
      end

      def unlocode_node?(node)
        return false unless node.is_a?(Hash)

        types = Array(node['@type']).flat_map { |t| t.to_s.split(/[,\s]+/) }
        types.empty? || types.any? { |t| t.end_with?(UNLOCODE_TYPE_SUFFIX) }
      end

      def build_entry(node)
        Entry.new(
          code: strip_id(node['rdf:value']) || strip_id(node['@id']),
          country: strip_prefixed_id(node['unlcdv:countryCode']),
          subdivision: strip_prefixed_id(node['unlcdv:countrySubdivision']),
          name: pick_label(node['rdfs:label']) || pick_label(node['rdfs:seeAlso']),
          function_codes: pick_function_codes(node['unlcdv:functions']),
          latitude: pick_float(node['geo:lat']),
          longitude: pick_float(node['geo:long'])
        )
      end

      def strip_prefixed_id(value)
        return nil if value.nil?

        case value
        when Hash then strip_id(value['@id'])
        when Array then strip_id(value.first&.dig('@id'))
        when String then strip_id(value)
        end
      end

      def strip_id(value)
        return nil if value.nil? || value.to_s.empty?

        value.to_s.split(':').last
      end

      def pick_label(value)
        return value unless value.is_a?(Hash) || value.is_a?(Array)

        entries = value.is_a?(Array) ? value : [value]
        picked = entries.find { |v| v.is_a?(Hash) && v['@language'] == 'en' } || entries.first
        picked.is_a?(Hash) ? picked['@value'] : picked
      end

      def pick_function_codes(value)
        return [] if value.nil?

        entries = value.is_a?(Array) ? value : [value]
        entries.filter_map do |entry|
          id = strip_prefixed_id(entry)
          next if id.nil?

          FUNCTION_DIGIT_TO_LETTER.fetch(id, id)
        end
      end

      def pick_float(value)
        return nil if value.nil?
        return value['@value']&.to_f if value.is_a?(Hash)

        value.to_f
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
