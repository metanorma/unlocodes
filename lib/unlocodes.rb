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
# Each caller constructs and holds its own {Unlocodes::Registry}:
#
#   registry = Unlocodes::Registry.load_default
#   registry.find('CNSHA')
#
# Which edition is bundled? See {.data_tag} (read from
# `lib/unlocodes/data/SOURCE_TAG`).
module Unlocodes
  SOURCE_TAG_PATH = File.expand_path('unlocodes/data/SOURCE_TAG', __dir__)

  # The upstream UNCEFACT vocabulary tag bundled with this gem version
  # (e.g. "2025-1"). Read from `lib/unlocodes/data/SOURCE_TAG` at runtime.
  # Pure function over a known file location — does not touch any registry.
  # @return [String, nil]
  def self.data_tag
    return @data_tag if defined?(@data_tag)

    @data_tag = File.read(SOURCE_TAG_PATH, encoding: 'UTF-8').strip
  rescue Errno::ENOENT
    nil
  end

  autoload :Coordinates, 'unlocodes/coordinates'
  autoload :Entry, 'unlocodes/entry'
  autoload :Registry, 'unlocodes/registry'
  autoload :Data, 'unlocodes/data'
end
