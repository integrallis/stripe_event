require 'rubygems'
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

if ENV['CI']
  task default: :spec
else
  require 'appraisal'
  task :default do
    system('bundle exec rake appraisal spec')
  end
end
