# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'fileutils'

module Unlocodes
  module Data
    # Downloads the UNCEFACT UN/LOCODE vocabulary from the upstream GitLab
    # repository and stores it as `lib/unlocodes/data/locode.jsonld`.
    #
    # The upstream tag (e.g. "2025-1") points at a snapshot of the
    # `vocab-locode` project whose `vocab/unlocode.jsonld` is the canonical
    # full dataset. Override the source URL with the `UNLOCODE_PATH` env
    # variable if a different edition's path layout applies.
    #
    # After a successful fetch, the tag is written to `SOURCE_TAG` next to
    # the data file so the gem (and the check-upstream workflow) always
    # knows which edition is bundled.
    module Fetcher
      UPSTREAM_HOST = 'opensource.unicc.org'
      UPSTREAM_TAG_PATH = '/un/unece/uncefact/vocab-locode/-/raw/%<tag>s'
      DATA_DIR = File.expand_path(__dir__)
      OUTPUT_PATH = File.join(DATA_DIR, 'locode.jsonld')
      SOURCE_TAG_PATH = File.join(DATA_DIR, 'SOURCE_TAG')

      CANDIDATE_PATHS = [
        'vocab/unlocode.jsonld',
        'vocab/unlocode-vocab.jsonld',
        'unlocode.jsonld',
        'locodes.jsonld'
      ].freeze

      class << self
        # @param tag [String] the upstream Git tag (e.g. "2025-1")
        # @return [String] the path written
        def call(tag:)
          uri = resolve_uri(tag)
          data = download(uri)
          write(data, tag: tag)
          warn "Fetched UN/LOCODE #{tag} (#{data.bytesize} bytes) -> #{OUTPUT_PATH}"
          OUTPUT_PATH
        end

        def resolve_uri(tag)
          return URI(ENV.fetch('UNLOCODE_PATH')) if ENV.key?('UNLOCODE_PATH')

          CANDIDATE_PATHS.each do |candidate|
            path = format("#{UPSTREAM_TAG_PATH}/#{candidate}", tag: tag)
            uri = URI::HTTPS.build(host: UPSTREAM_HOST, path: path)
            return uri if exists?(uri)
          end
          raise "Could not find UN/LOCODE data under tag #{tag.inspect}. " \
                'Set UNLOCODE_PATH to the full JSON-LD URL and retry.'
        end

        def exists?(uri)
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            response = http.head(uri.request_uri)
            response.is_a?(Net::HTTPSuccess)
          end
        rescue StandardError
          false
        end

        def download(uri)
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            response = http.get(uri.request_uri)
            raise "Download failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

            response.body
          end
        end

        def write(data, tag:)
          FileUtils.mkdir_p(DATA_DIR)
          File.write(OUTPUT_PATH, data)
          File.write(SOURCE_TAG_PATH, "#{tag}\n")
        end
      end
    end
  end
end
