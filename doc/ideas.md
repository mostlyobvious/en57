# Ideas

Random list of ideas, but not rules. These give some hint about the direction, but eventually may be discarded.

* releases follow semantic versioning

* changelog lists only changes interesting from the user perspective

* each release includes a benchmark result

* only newest released Ruby version, no backwards compatibility

* 100% mutation coverage with `mutant`

* Ruby code formatting and linting with `standard`

* depend on last released PostgreSQL version, no backwards compatibility

* no ORM, use plain `pg` driver with Ruby, but allow working with different connection pools (`activerecord`, `sequel`)

* favour PostgreSQL types, functions and stored procedures

* internal pub-sub like `ActiveSupport::Notifications`, without external dependencies:

    * enables logger

    * enables test-framework integration

    * enables instrumentation and telemetry

    * internal code as pubsub consumers

    * listening to event and handler registrations

* external pubsub via outbox mechanism

    * support Kafka

    * support Rabbitmq

    * support NATS

    * see if atom-feed consumer fits this usecase as well (as described in the IDDD book)

* persistent projections as external process or in-process threads

    * simplicity in local setup

    * reliability in production use

    * no need for external system to enable asynchronous event handlers

    * first-class support for read models — catchup, rebuild

* concurrent synchronous handlers

    * perform `Thread.join` or `Pool.wait_for_termination`

    * simillar to asynchronous in lack of handler ordering, however ordering to be achieved by reducing concurrency to 1

* unit tests stubbed at database driver layer, that is `pg`, integration test suite as a safety net

* release automation

    * prepare release notes automatically

    * build and push releases in CI

* benchmarking on a reasonable data set

    * releases dont introduce performance regressions

* handling large volumes of events

    * deleting events as a valid operation

    * partitioning

    * tiering — phasing out events to different storage

* correlation, causation, by_type, by_some_attribute out of the box and without leaking implementation detauils to the end user

    * start as queries
    
    * optimize further (to some form of indexes)

* any-temporal — have as many indexed timestamps as you wish

* validate with non-Ruby implementation at some point

* expect framework implemented on top of it some day, don't be one

    * there are per-project frameworks anyway and one size does not fit all

    * propose a frawework, though

* CLI diagnostic interface

    * includes environment and setup information

    * useful for bug reports

