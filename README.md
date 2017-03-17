# rabbitmq-graph

Discover RabbitMQ topology.

## Assumptions

- Routing keys are in the format of `application.entity.<snip>`.
- Consumer tags are configured to contain the name of the consuming application.

## How to run?

Without arguments `bin/run` will connect to `localhost:5672` and `localhost:15672` with the default guest user.

It's possible to configure both URIs with `RABBITMQ_URI` and `RABBITMQ_API_URI`. Below is an example of connecting to a
dockerised RabbitMQ.

`MAX_LEVEL` can also be used to control the level of depth in the graph:

- `1` will only show application to application relations. Edge labels will display the rest of the routing key beyond application part.
- `2` will show application to entity to application relations. Edge labels will display the routing key beyond entity part.

### Example

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

[hutch-0.24]: https://github.com/gocardless/hutch/blob/master/CHANGELOG.md#0240--february-1st-2017
