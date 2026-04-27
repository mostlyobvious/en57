# frozen_string_literal: true

require "test_helper"

module En57
  class TestStress < IntegrationTest
    ADAPTERS.each do |adapter_name, factory|
      define_method(
        "test_only_one_writer_can_consume_account_credits_with_#{adapter_name}",
      ) do
        with_event_store(factory) do |event_store|
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
                  Thread.current.report_on_exception = false

                  account_scope = event_store.read.with_tag(account_tag)
                  barrier.wait

                  if account_balance(account_scope) >= 100
                    event_store.append(
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
                rescue AppendConditionViolated => e
                  e
                end
              end

            assert_equal(
              (concurrency - 1),
              threads
                .map(&:value)
                .select { AppendConditionViolated === it }
                .size,
            )
            account_scope = event_store.read.with_tag(account_tag)
            assert_equal(1, account_scope.of_type("CreditsUsed").each.count)
            assert_equal(0, account_balance(account_scope))
          end
        end
      end

    private

    def with_event_store(factory)
      yield EventStore.new(Repository.new(factory.call, JsonSerializer.new))
    end

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
