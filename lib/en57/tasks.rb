# frozen_string_literal: true

require "rake"
require_relative "migrator"

namespace :en57 do
  desc "Apply pending En57 schema migrations"
  task :migrate do
    En57::Migrator.new(ENV.fetch("DATABASE_URL")).migrate!
  end

  desc "List En57 schema migration status"
  task :status do
    status = En57::Migrator.new(ENV.fetch("DATABASE_URL")).status

    puts "Current : #{status.current}"
    puts "Target  : #{status.target}"
    puts "Status  : #{status.state}"
    puts "Method  : #{status.method}"
    unless status.pending.empty?
      puts "Pending :"
      status.pending.each { |item| puts "  #{item}" }
    end
    puts "WARNING : #{status.warning}" if status.warning
  end
end
