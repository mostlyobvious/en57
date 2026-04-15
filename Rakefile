# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

task :mutate do
  system("bin/mutant run")
end

task :mutate_since do
  system("bin/mutant run --since #{ENV.fetch("MUTANT_SINCE", "HEAD")}")
end

task default: %i[test mutate_since]
