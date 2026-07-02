# frozen_string_literal: true

require 'forwardable'
require 'lutaml/model'
require 'json'

require_relative 'unlocodes/version'

# Vendored UN/LOCODE dataset as a queryable Ruby registry.
#
# The dataset is sourced from the UNECE/UNCEFACT LOCODE vocabulary published at
# https://opensource.unicc.org/un/unece/uncefact/vocab-locode and distributed
# by this gem as a bundled, offline JSON-LD representation. The registry loads
# once per process and exposes a typed query API over `Unlocodes::Entry`
# instances.
#
# Which edition is bundled? See {Unlocodes.data_tag} (read from
# `lib/unlocodes/data/SOURCE_TAG`).
module Unlocodes
  extend SingleForwardable

  SOURCE_TAG_PATH = File.expand_path('unlocodes/data/SOURCE_TAG', __dir__)

  class << self
    # @return [Unlocodes::Registry] the process-wide registry, loaded lazily
    def registry
      @registry ||= Registry.load_default
    end

    # Reset the process-wide registry. Used by specs to swap fixtures.
    def reset_registry!
      @registry = nil
    end

    # The upstream UNCEFACT vocabulary tag bundled with this gem version
    # (e.g. "2025-1"). Read from `lib/unlocodes/data/SOURCE_TAG` at runtime.
    # @return [String, nil]
    def data_tag
      return @data_tag if defined?(@data_tag)

      @data_tag = File.read(SOURCE_TAG_PATH, encoding: 'UTF-8').strip
    rescue Errno::ENOENT
      nil
    end
  end

  def_delegators :registry, :find, :where, :each, :size, :count, :countries

  autoload :Status, 'unlocodes/status'
  autoload :Function, 'unlocodes/function'
  autoload :Coordinates, 'unlocodes/coordinates'
  autoload :Entry, 'unlocodes/entry'
  autoload :Loader, 'unlocodes/loader'
  autoload :Registry, 'unlocodes/registry'
  autoload :Data, 'unlocodes/data'
end
