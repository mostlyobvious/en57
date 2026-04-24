# frozen_string_literal: true

require "concurrent-ruby"
require "pg_ephemeral"
require "test_helper"

module En57
  class TestStress < Minitest::Test
    SERVER = PgEphemeral.start
    CONNECTION = PG.connect(SERVER.url)

    Minitest.after_run do
      CONNECTION.close
      SERVER.shutdown
    end

    def setup
      CONNECTION.exec("TRUNCATE TABLE tags, events RESTART IDENTITY CASCADE")
    end

    def test_only_one_writer_can_consume_account_credits
      account_tag = "account:x"
      event_store.append(
        [
          Event.new(
            id: SecureRandom.uuid,
            type: "CredditToppedUp",
            data: {
              amount: 100,
            },
            tags: [account_tag],
          ),
        ],
      )

      worker_count = 8
      barrier = Concurrent::CyclicBarrier.new(worker_count)
      successes = Queue.new

      threads =
        Array.new(worker_count) do
          Thread.new do
            connection = PG.connect(SERVER.url)
            begin
              store =
                EventStore.new(PgRepository.new(connection, JsonSerializer.new))
              barrier.wait
              account_scope = store.read.with_tag(account_tag)

              if account_balance(account_scope) >= 100
                store.append(
                  [
                    Event.new(
                      id: SecureRandom.uuid,
                      type: "CreditsUsed",
                      data: {
                        amount: 100,
                      },
                      tags: [account_tag],
                    ),
                  ],
                  fail_if: account_scope.of_type("CreditsUsed").query,
                )
                successes << true
              end
            rescue AppendConditionViolated, PG::TRSerializationFailure
            ensure
              connection.close
            end
          end
        end

      threads.each(&:join)

      account_scope = event_store.read.with_tag(account_tag)

      assert_equal(1, account_scope.of_type("CreditsUsed").each.count)
      assert_equal(1, successes.size)
      assert_equal(0, account_balance(account_scope))
    end

    private

    def event_store
      @event_store ||=
        EventStore.new(PgRepository.new(CONNECTION, JsonSerializer.new))
    end

    def account_balance(scope)
      scope.each.sum do |event|
        amount = event.data.fetch(:amount)

        case event.type
        when "CredditToppedUp"
          amount
        when "CreditsUsed"
          -amount
        else
          0
        end
      end
    end
  end
end
