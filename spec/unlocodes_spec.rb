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

  describe 'deprecated module-level shortcuts' do
    let(:registry) do
      Unlocodes::Registry.from_entries([
                                         Unlocodes::Entry.new(code: 'CNSHA', country: 'CN', name: 'Shanghai'),
                                         Unlocodes::Entry.new(code: 'USNYC', country: 'US', name: 'New York')
                                       ])
    end

    before do
      allow(Unlocodes).to receive(:default_registry).and_return(registry)
      allow(Unlocodes).to receive(:warn)
    end

    it 'still delegates find to the global registry' do
      expect(Unlocodes.find('CNSHA').name).to eq('Shanghai')
    end

    it 'still delegates where to the global registry' do
      expect(Unlocodes.where(country: 'CN').map(&:code)).to eq(%w[CNSHA])
    end

    it 'still delegates countries to the global registry' do
      expect(Unlocodes.countries).to eq(%w[CN US])
    end

    it 'still delegates count to the global registry' do
      expect(Unlocodes.count).to eq(2)
    end

    it 'warns on deprecated find' do
      Unlocodes.find('CNSHA')
      expect(Unlocodes).to have_received(:warn).with(/Unlocodes.find is deprecated/, anything)
    end

    it 'warns on deprecated registry access' do
      Unlocodes.registry
      expect(Unlocodes).to have_received(:warn).with(/Unlocodes.registry is deprecated/, anything)
    end

    it 'reset_registry! clears the memoized default' do
      Unlocodes.reset_registry!
      expect(Unlocodes.instance_variable_get(:@registry)).to be_nil
    end
  end

  describe 'recommended usage (no singleton)' do
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
