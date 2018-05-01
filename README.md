# rabbitmq-graph

[![Dependency Status](https://gemnasium.com/badges/github.com/sldblog/rabbitmq-graph.svg)](https://gemnasium.com/github.com/sldblog/rabbitmq-graph)
[![CircleCI](https://circleci.com/gh/sldblog/rabbitmq-graph.svg?style=svg&circle-token=68531f42debaa4ff5b3bddb62a4672ca2eaabaf4)](https://circleci.com/gh/sldblog/rabbitmq-graph)

Discover RabbitMQ topology.

## Assumptions

- Routing keys are segmented with dots (`.`).
    - The first segment is assumed to be the source application.  
      Example: `splitter.experiment.something.assigned` &rarr; `splitter` is the application publishing the message.
    - The second segment is assumed to be the entity.  
      Example: `splitter.experiment.something.assigned` &rarr; `experiment` is the entity being actioned.
    - The rest of the segments is assumed to be the action.  
      Example: `splitter.experiment.something.assigned` &rarr; `something.assigned` is the action.
- [Consumer tags][hutch-consumer-tag-pr] are configured to contain the name of the consuming application.

## How to run?

Without arguments `bin/run` will connect to `localhost:5672` and `localhost:15672` with the default guest user.

### Configuration

| Setting | Environment variable | Effect | Default |
| ------- | -------------------- | ------ | ------- |
| Graph level | `LEVEL` | Sets the complexity level of the graph. | 2 |
| Edge level | `EDGE_LEVEL` | Sets the complexity level of edges. | 2 |
| RabbitMQ URL | `RABBITMQ_URI` | Specifies the connection URL to RabbitMQ | `amqp://guest:guest@localhost:5672/` |
| RabbitMQ management URL | `RABBITMQ_API_URI` | Specifies the connection URL to RabbitMQ management API | `http://localhost:15672/` |

### Graph level

- **1**: will only show application to application relations. Edge labels will display the rest of the routing key beyond application part.
- **2**: will show application to entity to application relations. Edge labels will display the routing key beyond entity part.

### Edge level

Affects the complexity of edges:

- **0**: displays the full routing key per edge
- **1**: displays `entity.[rest.]*.action` as label per edge
- **2**: displays `[rest.]*.action` as label per edge
- _high number_: does not display labels. Effectively means it reduces number of edges to 1 between nodes.

### Example

Running the discovery against a dockerised `rabbitmq:3.6-management`:

```
$ docker run --detach --publish 5672:5672 --publish 15672:15672 rabbitmq:3.6-management

$ RABBITMQ_URI=amqp://guest:guest@localhost:5672/ \
  RABBITMQ_API_URI=http://localhost:15672/ \
  bin/run > test.dot
I, [2018-04-30T13:05:29.717291 #90042]  INFO -- : connecting to rabbitmq (amqp://guest@127.0.0.1:5672/)
I, [2018-04-30T13:05:29.728500 #90042]  INFO -- : connected to RabbitMQ at 127.0.0.1 as guest
I, [2018-04-30T13:05:29.728589 #90042]  INFO -- : opening rabbitmq channel with pool size 1, abort on exception false
I, [2018-04-30T13:05:29.731250 #90042]  INFO -- : using topic exchange 'hutch'
I, [2018-04-30T13:05:29.734912 #90042]  INFO -- : HTTP API use is enabled
I, [2018-04-30T13:05:29.735060 #90042]  INFO -- : connecting to rabbitmq HTTP API (http://guest@127.0.0.1:15672/)
I, [2018-04-30T13:05:29.739998 #90042]  INFO -- : tracing is disabled
Discovering bindings: |================================================================================================|
Discovering queues: |==================================================================================================|

$ fdp -O -Tpng test.dot   # assumes "graphviz" is installed
$ open test.dot.png
```

## How to configure consumer tags?

### hutch

Hutch supports consumer tag prefixes since [0.24][hutch-0.24].

[hutch-consumer-tag-pr]: https://github.com/gocardless/hutch/pull/265
[hutch-0.24]: https://github.com/gocardless/hutch/blob/master/CHANGELOG.md#0240--february-1st-2017
