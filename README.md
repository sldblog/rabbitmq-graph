# rabbitmq-graph

Discover RabbitMQ topology.

## Assumptions

- Routing keys are in the format of `application.entity.<snip>`.
- Consumer tags are configured to contain the name of the consuming application.

## How to configure consumer tags?

### hutch

Hutch supports consumer tag prefixes since [0.24][hutch-0.24].

[hutch-0.24]: https://github.com/gocardless/hutch/blob/master/CHANGELOG.md#0240--february-1st-2017
