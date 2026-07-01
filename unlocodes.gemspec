# frozen_string_literal: true

require_relative 'lib/unlocodes/version'

Gem::Specification.new do |spec|
  spec.name = 'unlocodes'
  spec.version = Unlocodes::VERSION
  spec.authors = ['Ribose Inc.']
  spec.email = ['open.source@ribose.com']

  spec.summary = 'UN/LOCODE dataset as a queryable Ruby registry'
  spec.description = <<~DESC
    Vendored, offline access to the UN/LOCODE (United Nations Code for Trade
    and Transport Locations) dataset published by UNECE/UNCEFACT. Provides a
    model-driven Ruby registry for looking up LOCODE entries by code, country,
    function, status, name, and other classifiers.
  DESC
  spec.homepage = 'https://github.com/metanorma/unlocodes'
  spec.license = 'BSD-2-Clause'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/metanorma/unlocodes',
    'bug_tracker_uri' => 'https://github.com/metanorma/unlocodes/issues',
    'rubygems_mfa_required' => 'true'
  }.freeze

  spec.files = Dir.chdir(__dir__) do
    Dir.glob('{lib}/**/*').reject { |f| File.directory?(f) }
  end.append('LICENSE').append('README.adoc').uniq
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'json', '~> 2.6'
  spec.add_dependency 'lutaml-model', '~> 0.8'
end
