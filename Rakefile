# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

task :mutate do
  system("bin/mutant run")
end

task default: %i[test standard mutate]
