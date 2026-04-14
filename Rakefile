# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

task :mutate do
  system("bin/mutant run")
end

task :mutate_since_head do
  system("bin/mutant run --since HEAD")
end

task default: %i[test mutate_since_head standard]
