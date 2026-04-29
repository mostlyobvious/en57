# frozen_string_literal: true

require "bundler/gem_tasks"
require "fileutils"
require "minitest/test_task"
require "uri"

Minitest::TestTask.create

def pg_regress_bin
  candidates = [
    ENV["PG_REGRESS"],
    `command -v pg_regress`.strip,
    "/opt/homebrew/lib/postgresql@18/pgxs/src/test/regress/pg_regress",
  ]

  candidates.find do |candidate|
    candidate && !candidate.empty? && File.executable?(candidate)
  end
end

task :format do
  system("stree write **/*.rb")
  system("pg_format -i db/**/*.sql")
end

task :mutate do
  system("bin/mutant run")
end

task :mutate_since do
  system("bin/mutant run --since #{ENV.fetch("MUTANT_SINCE")}")
end

desc "Run pg_regress tests against a pg-ephemeral instance"
task :pg_regress do
  require "pg_ephemeral"

  pg_regress = pg_regress_bin
  unless pg_regress
    abort("pg_regress not found. Set PG_REGRESS=/path/to/pg_regress")
  end

  server = PgEphemeral.start
  uri = URI(server.url)

  host = uri.host
  port = uri.port
  user = uri.user
  dbname = uri.path.delete_prefix("/")
  bindir = ENV["PG_BINDIR"] || `pg_config --bindir`.strip
  schedule = ENV["PG_REGRESS_SCHEDULE"] || "test/pg_regress/schedule_existing"

  FileUtils.rm_rf("test/pg_regress/results")
  FileUtils.mkdir_p("test/pg_regress/results")

  success =
    system(
      { "PGPASSWORD" => uri.password },
      pg_regress,
      "--use-existing",
      "--host=#{host}",
      "--port=#{port}",
      "--user=#{user}",
      "--dbname=#{dbname}",
      "--inputdir=test/pg_regress",
      "--outputdir=test/pg_regress/results",
      "--expecteddir=test/pg_regress",
      "--bindir=#{bindir}",
      "--schedule=#{schedule}",
    )

  abort("pg_regress failed") unless success
ensure
  server&.shutdown
end

task default: %i[test mutate_since]
