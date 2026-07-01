# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

namespace :unlocodes do
  desc 'Fetch the UNCEFACT UN/LOCODE vocabulary (default tag: 2025-1)'
  task :fetch, [:tag] do |_t, args|
    tag = args[:tag] || ENV.fetch('UNLOCODE_TAG', '2025-1')
    require_relative 'lib/unlocodes/data/fetcher'
    Unlocodes::Data::Fetcher.call(tag: tag)
  end
end
