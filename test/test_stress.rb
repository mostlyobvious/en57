# frozen_string_literal: true

require "test_helper"

module En57
  class TestStress < IntegrationTest
    def test_only_one_writer_can_consume_account_credits
      with_event_store do |event_store|
        event_store.append(
          [
            Event.new(
              type: "CreditsToppedUp",
              data: {
                amount: 100,
              },
              tags: [account_tag],
            ),
          ],
        )

        barrier = Concurrent::CyclicBarrier.new(concurrency)
        threads =
          Array.new(concurrency) do
            Thread.new do
              with_event_store do |event_store_|
                barrier.wait
                account_scope = event_store_.read.with_tag(account_tag)

                if account_balance(account_scope) >= 100
                  event_store_.append(
                    [
                      Event.new(
                        type: "CreditsUsed",
                        data: {
                          amount: 100,
                        },
                        tags: [account_tag],
                      ),
                    ],
                    fail_if: account_scope.of_type("CreditsUsed"),
                  )
                end
              end
            rescue AppendConditionViolated, PG::TRSerializationFailure
            end
          end
        threads.each(&:join)

        account_scope = event_store.read.with_tag(account_tag)

        assert_equal 1, account_scope.of_type("CreditsUsed").each.count
        assert_equal 0, account_balance(account_scope)
      end
    end

    private

    def with_event_store =
      yield(
        EventStore.new(
          Repository.new(PgAdapter.new(SERVER.url), JsonSerializer.new),
        )
      )

    def concurrency = 8

    def account_tag = "account:x"

    def account_balance(scope)
      scope.each.sum do |event|
        amount = event.data.fetch(:amount)

        case event.type
        when "CreditsToppedUp"
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
