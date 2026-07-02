# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Unlocodes::Registry do
  let(:sample_path) { File.join(FIXTURES_DIR, 'locode_sample.jsonld') }
  let(:registry) { described_class.load_file(sample_path) }

  describe '.load_default' do
    context 'when the bundled data file is missing' do
      before do
        allow(described_class).to receive(:default_data_path)
          .and_return('/nonexistent/unlocode/data/locode.jsonld')
      end

      it 'raises a helpful error' do
        expect { described_class.load_default }
          .to raise_error(Errno::ENOENT, /locode\.jsonld/)
      end
    end

    it 'loads the bundled dataset from the gem' do
      expect(described_class.load_default.size).to be_positive
    end
  end

  describe '.load_file' do
    it 'loads a registry from a JSON-LD file' do
      expect(registry.size).to eq(4)
      expect(registry).not_to be_empty
    end
  end

  describe '.from_entries' do
    it 'builds a registry from a list of entries' do
      entries = [Unlocodes::Entry.new(code: 'XXXXX')]
      registry = described_class.from_entries(entries)
      expect(registry.size).to eq(1)
      expect(registry.find('XXXXX')).to be_a(Unlocodes::Entry)
    end
  end

  describe '#find' do
    it 'looks up entries by 5-char code' do
      entry = registry.find('CNSHA')
      expect(entry).to be_a(Unlocodes::Entry)
      expect(entry.name).to eq('Shanghai')
    end

    it 'is case-insensitive' do
      expect(registry.find('cnsha').code).to eq('CNSHA')
    end

    it 'returns nil for unknown codes' do
      expect(registry.find('ZZZZZ')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(registry.find(nil)).to be_nil
    end
  end

  describe '#[] alias' do
    it 'aliases find' do
      expect(registry['CNSHA']).to eq(registry.find('CNSHA'))
    end
  end

  describe '#where' do
    it 'filters by country' do
      cn = registry.where(country: 'CN')
      expect(cn.size).to eq(1)
      expect(cn.first.code).to eq('CNSHA')
    end

    it 'accepts multiple values as any-of' do
      entries = registry.where(country: %w[CN HK])
      expect(entries.map(&:code).sort).to eq(%w[CNSHA HKHKG])
    end

    it 'filters by function letter' do
      ports = registry.where(function: 'B')
      expect(ports.size).to eq(4) # all four in the fixture are sea ports
    end

    it 'filters by subdivision' do
      matches = registry.where(subdivision: 'CNSH')
      expect(matches.map(&:code)).to eq(%w[CNSHA])
    end

    it 'combines filters' do
      entries = registry.where(country: 'CN', function: 'A')
      expect(entries.map(&:code)).to eq(%w[CNSHA])
    end

    it 'filters by name with a Regexp' do
      matches = registry.where(name: /ang/i)
      expect(matches.map(&:code)).to eq(%w[CNSHA])
    end

    it 'filters by name with a case-insensitive string' do
      matches = registry.where(name: 'rotterdam')
      expect(matches.map(&:code)).to eq(%w[NLRTM])
    end

    it 'raises ArgumentError for unknown filter keys' do
      expect { registry.where(unknown: 'x') }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for status (not in JSON-LD vocab)' do
      expect { registry.where(status: 'AA') }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for iata (not in JSON-LD vocab)' do
      expect { registry.where(iata: 'PVG') }.to raise_error(ArgumentError)
    end
  end

  describe '#by_country, #by_function' do
    it '#by_country returns entries for one country' do
      expect(registry.by_country('CN').map(&:code)).to eq(%w[CNSHA])
    end

    it '#by_function returns entries matching one function letter' do
      expect(registry.by_function('R').map(&:code).sort).to eq(%w[NLRTM USNYC])
    end

    it 'returns an empty array for unknown keys' do
      expect(registry.by_country('ZZ')).to eq([])
      expect(registry.by_function('Z')).to eq([])
    end
  end
  describe '#countries' do
    it 'lists all distinct country codes sorted' do
      expect(registry.countries).to eq(%w[CN HK NL US])
    end
  end

  describe '#counts_by_country' do
    it 'counts entries per country' do
      expect(registry.counts_by_country).to eq('CN' => 1, 'HK' => 1, 'NL' => 1, 'US' => 1)
    end
  end

  describe '#each' do
    it 'iterates over entries' do
      codes = registry.map(&:code)
      expect(codes.sort).to eq(%w[CNSHA HKHKG NLRTM USNYC])
    end
  end
end
