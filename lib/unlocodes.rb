# frozen_string_literal: true

require 'forwardable'
require 'lutaml/model'
require 'json'

require_relative 'unlocodes/version'

# Vendored UN/LOCODE dataset as a queryable Ruby registry.
#
# The dataset is sourced from the UNECE/UNCEFACT LOCODE vocabulary published at
# https://opensource.unicc.org/un/unece/uncefact/vocab-locode and distributed
# by this gem as a bundled, offline JSON-LD representation.
#
# Each caller should construct and hold its own {Unlocodes::Registry}:
#
#   registry = Unlocodes::Registry.load_default
#   registry.find('CNSHA')
#
# The module-level `Unlocodes.find` / `Unlocodes.where` / etc. shortcuts are
# deprecated since 0.2.0 (they rely on a process-wide singleton). They still
# work today but emit a `Kernel#warn` deprecation and will be removed in
# 0.3.0.
#
# Which edition is bundled? See {.data_tag} (read from
# `lib/unlocodes/data/SOURCE_TAG`).
module Unlocodes
  DEPRECATION_SUGGESTION = 'Use Unlocodes::Registry.load_default instead ' \
                           '(or construct from a custom data source). ' \
                           'Removal targeted for 0.3.0.'

  SOURCE_TAG_PATH = File.expand_path('unlocodes/data/SOURCE_TAG', __dir__)

  # The upstream UNCEFACT vocabulary tag bundled with this gem version
  # (e.g. "2025-1"). Read from `lib/unlocodes/data/SOURCE_TAG` at runtime.
  # Pure function over a known file location — does not touch the registry.
  # @return [String, nil]
  def self.data_tag
    return @data_tag if defined?(@data_tag)

    @data_tag = File.read(SOURCE_TAG_PATH, encoding: 'UTF-8').strip
  rescue Errno::ENOENT
    nil
  end

  class << self
    # @deprecated Use `Unlocodes::Registry.load_default` and hold the
    #   instance yourself. Removal targeted for 0.3.0.
    def registry
      warn "Unlocodes.registry is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      default_registry
    end

    # @deprecated Tests that swap the global registry should construct a
    #   `Unlocodes::Registry` directly and inject it. Removal targeted for 0.3.0.
    def reset_registry!
      warn "Unlocodes.reset_registry! is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      @registry = nil
    end

    # @deprecated Forwarded to the global registry; construct your own and
    #   call `registry.find(code)`. Removal targeted for 0.3.0.
    def find(code)
      warn "Unlocodes.find is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      default_registry.find(code)
    end

    # @deprecated Construct your own registry and call `registry.where(filters)`.
    #   Removal targeted for 0.3.0.
    def where(filters)
      warn "Unlocodes.where is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      default_registry.where(filters)
    end

    # @deprecated Construct your own registry and call `registry.each`.
    #   Removal targeted for 0.3.0.
    def each(&)
      warn "Unlocodes.each is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      default_registry.each(&)
    end

    # @deprecated Construct your own registry and call `registry.size`.
    #   Removal targeted for 0.3.0.
    def size
      warn "Unlocodes.size is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      default_registry.size
    end

    # @deprecated Construct your own registry and call `registry.count`.
    #   Removal targeted for 0.3.0.
    def count
      warn "Unlocodes.count is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      default_registry.count
    end

    # @deprecated Construct your own registry and call `registry.countries`.
    #   Removal targeted for 0.3.0.
    def countries
      warn "Unlocodes.countries is deprecated. #{DEPRECATION_SUGGESTION}", category: :deprecated, uplevel: 1
      default_registry.countries
    end

    private

    # Internal memoised default registry. Used by the deprecated module-level
    # shortcuts. Direct callers should construct their own Registry instead.
    def default_registry
      @default_registry ||= Registry.load_default
    end
  end

  autoload :Coordinates, 'unlocodes/coordinates'
  autoload :Entry, 'unlocodes/entry'
  autoload :Registry, 'unlocodes/registry'
  autoload :Data, 'unlocodes/data'
end
