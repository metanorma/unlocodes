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

  describe '.parse_json / .parse_hash (JSON-LD wire format)' do
    let(:sample_json) { File.read(sample_path) }

    it 'parses a JSON-LD string into Entry instances' do
      entries = described_class.parse_json(sample_json)
      expect(entries.size).to eq(4)
      expect(entries).to all(be_a(Unlocodes::Entry))
    end

    it 'builds Entry attributes from real UNCEFACT wire names' do
      entries = described_class.parse_json(sample_json)
      shanghai = entries.find { |e| e.code == 'CNSHA' }

      expect(shanghai.country).to eq('CN')
      expect(shanghai.subdivision).to eq('CNSH')
      expect(shanghai.name).to eq('Shanghai')
      expect(shanghai.function_codes).to eq(%w[B A P])
      expect(shanghai.latitude).to eq(31.2)
      expect(shanghai.longitude).to eq(121.4)
    end

    it 'maps unlcdf numeric ids to function letters (1→B, 4→A)' do
      shanghai = described_class.parse_json(sample_json).find { |e| e.code == 'CNSHA' }
      expect(shanghai.function_codes).to eq(%w[B A P]) # 1, 4, 5 → B, A, P
    end

    it 'handles rdfs:label as an array (picks the @language=en entry)' do
      parsed = { '@graph' => [{
        '@type' => 'unlcdv:UNLOCODE',
        'rdf:value' => 'ADSJL',
        'rdfs:label' => [
          { '@value' => 'Sant Julià de Lòria' },
          { '@language' => 'en', '@value' => 'Sant Julia de Loria' }
        ]
      }] }
      entry = described_class.parse_hash(parsed).first
      expect(entry.name).to eq('Sant Julia de Loria')
    end

    it 'strips prefixes from unlcdv:countryCode @id references' do
      parsed = { '@graph' => [{
        '@type' => 'unlcdv:UNLOCODE',
        'rdf:value' => 'XXXXX',
        'unlcdv:countryCode' => { '@id' => 'unlcdc:XX' }
      }] }
      expect(described_class.parse_hash(parsed).first.country).to eq('XX')
    end

    it 'falls back to @id suffix when rdf:value is missing' do
      parsed = { '@graph' => [{
        '@type' => 'unlcdv:UNLOCODE',
        '@id' => 'unlcd:CNSHA'
      }] }
      expect(described_class.parse_hash(parsed).first.code).to eq('CNSHA')
    end

    it 'skips non-UNLOCODE graph entries' do
      parsed = { '@graph' => [
        { '@type' => 'skos:ConceptScheme', '@id' => 'urn:locode' },
        { '@type' => 'unlcdv:UNLOCODE', 'rdf:value' => 'CNSHA' }
      ] }
      expect(described_class.parse_hash(parsed).map(&:code)).to eq(['CNSHA'])
    end

    it 'leaves attributes nil when the wire data is missing' do
      entry = described_class
              .parse_hash('@graph' => [{ '@type' => 'unlcdv:UNLOCODE', 'rdf:value' => 'USNYC' }])
              .first
      expect(entry.country).to be_nil
      expect(entry.function_codes).to be_empty
      expect(entry.latitude).to be_nil
      expect(entry.longitude).to be_nil
    end

    it 'handles a single function as a hash (not array)' do
      parsed = { '@graph' => [{
        '@type' => 'unlcdv:UNLOCODE',
        'rdf:value' => 'XXXXX',
        'unlcdv:functions' => { '@id' => 'unlcdf:4' }
      }] }
      expect(described_class.parse_hash(parsed).first.function_codes).to eq(['A'])
    end

    it 'preserves unknown function ids (e.g. letters) as-is' do
      parsed = { '@graph' => [{
        '@type' => 'unlcdv:UNLOCODE',
        'rdf:value' => 'XXXXX',
        'unlcdv:functions' => [{ '@id' => 'unlcdf:B' }]
      }] }
      expect(described_class.parse_hash(parsed).first.function_codes).to eq(['B'])
    end

    it 'returns empty for an empty graph' do
      expect(described_class.parse_hash('@graph' => [])).to eq([])
    end

    it 'returns empty for a document with no graph' do
      expect(described_class.parse_hash('@context' => {})).to eq([])
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
