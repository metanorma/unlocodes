# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Unlocodes do
  describe 'VERSION' do
    it 'exposes a version string' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+/)
    end
  end

  describe '.data_tag' do
    after do
      described_class.remove_instance_variable(:@data_tag) if described_class.instance_variable_defined?(:@data_tag)
    end

    it 'returns the bundled source tag' do
      expect(described_class.data_tag).to eq('2025-1')
    end

    it 'is memoized' do
      expect(described_class.data_tag).to equal(described_class.data_tag)
    end

    it 'returns nil when the SOURCE_TAG file is missing' do
      stub_const('Unlocodes::SOURCE_TAG_PATH', '/nonexistent/SOURCE_TAG')
      described_class.remove_instance_variable(:@data_tag) if described_class.instance_variable_defined?(:@data_tag)
      expect(described_class.data_tag).to be_nil
    end
  end

  describe 'module-level singleton methods (removed in 0.3.0)' do
    it 'does not define Unlocodes.find' do
      expect(Unlocodes).not_to respond_to(:find)
    end

    it 'does not define Unlocodes.where' do
      expect(Unlocodes).not_to respond_to(:where)
    end

    it 'does not define Unlocodes.each' do
      expect(Unlocodes).not_to respond_to(:each)
    end

    it 'does not define Unlocodes.size' do
      expect(Unlocodes).not_to respond_to(:size)
    end

    it 'does not define Unlocodes.count' do
      expect(Unlocodes).not_to respond_to(:count)
    end

    it 'does not define Unlocodes.countries' do
      expect(Unlocodes).not_to respond_to(:countries)
    end

    it 'does not define Unlocodes.registry' do
      expect(Unlocodes).not_to respond_to(:registry)
    end

    it 'does not define Unlocodes.reset_registry!' do
      expect(Unlocodes).not_to respond_to(:reset_registry!)
    end
  end

  describe 'recommended usage' do
    it 'constructs a Registry directly from the bundled data' do
      registry = Unlocodes::Registry.load_default
      expect(registry).to be_a(Unlocodes::Registry)
      expect(registry.size).to be_positive
    end

    it 'constructs a Registry from a custom file' do
      path = File.join(FIXTURES_DIR, 'locode_sample.jsonld')
      registry = Unlocodes::Registry.load_file(path)
      expect(registry.map(&:code).sort).to eq(%w[CNSHA HKHKG NLRTM USNYC])
    end

    it 'constructs a Registry from in-memory entries' do
      registry = Unlocodes::Registry.from_entries([
                                                    Unlocodes::Entry.new(code: 'XXXXX', country: 'XX', name: 'Custom')
                                                  ])
      expect(registry.find('XXXXX').name).to eq('Custom')
    end
  end
end
