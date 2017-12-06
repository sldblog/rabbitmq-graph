# rabbitmq-graph

[![Dependency Status](https://gemnasium.com/badges/github.com/sldblog/rabbitmq-graph.svg)](https://gemnasium.com/github.com/sldblog/rabbitmq-graph)

Discover RabbitMQ topology.

## Assumptions

- Routing keys are in the format of `application.entity.event_verb` or `application.entity.postfix1.postfix2`. Any number of postfixes are possible, separated by dots.
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

Running the discovery against a dockerised `rabbitmq:3.4-management` with dynamic ports:

```
$ RABBITMQ_API_URI=http://localhost:32888/ RABBITMQ_URI=amqp://guest:guest@localhost:32889/test bin/run | tee test.dot
I, [2017-03-16T19:59:32.492886 #42089]  INFO -- : connecting to rabbitmq (amqp://guest@localhost:32889/test)
I, [2017-03-16T19:59:32.501677 #42089]  INFO -- : connected to RabbitMQ at localhost as guest
I, [2017-03-16T19:59:32.501727 #42089]  INFO -- : opening rabbitmq channel with pool size 1, abort on exception false
I, [2017-03-16T19:59:32.504461 #42089]  INFO -- : using topic exchange 'hutch'
I, [2017-03-16T19:59:32.505797 #42089]  INFO -- : HTTP API use is enabled
I, [2017-03-16T19:59:32.505962 #42089]  INFO -- : connecting to rabbitmq HTTP API (http://guest@localhost:32888/)
I, [2017-03-16T19:59:32.512098 #42089]  INFO -- : tracing is disabled
...............................................................digraph G {
  subgraph Apps {
    node [shape=hexagon fillcolor=yellow style=filled]
<snip>

$ dot -O -Tpng test.dot
$ open test.dot.png
```

## How to configure consumer tags?

### hutch

Hutch supports consumer tag prefixes since [0.24][hutch-0.24].

[hutch-consumer-tag-pr]: https://github.com/gocardless/hutch/pull/265
[hutch-0.24]: https://github.com/gocardless/hutch/blob/master/CHANGELOG.md#0240--february-1st-2017
