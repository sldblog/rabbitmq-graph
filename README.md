# rabbitmq-graph

[![Dependency Status](https://gemnasium.com/badges/github.com/sldblog/rabbitmq-graph.svg)](https://gemnasium.com/github.com/sldblog/rabbitmq-graph)
[![CircleCI](https://circleci.com/gh/sldblog/rabbitmq-graph.svg?style=svg&circle-token=68531f42debaa4ff5b3bddb62a4672ca2eaabaf4)](https://circleci.com/gh/sldblog/rabbitmq-graph)
[![Maintainability](https://api.codeclimate.com/v1/badges/146dab10c24b4dd7b75e/maintainability)](https://codeclimate.com/github/sldblog/rabbitmq-graph/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/146dab10c24b4dd7b75e/test_coverage)](https://codeclimate.com/github/sldblog/rabbitmq-graph/test_coverage)

Discover RabbitMQ topology.

## Assumptions

- Routing keys are segmented with dots (`.`).

  | Segment name | Routing key | Extracted | Assumed to be |
  | --- | --- | --- | --- |
  | from\_app | **splitter**.experiment.something.assigned | splitted | The name of the publishing application. |
  | entity | splitter.**experiment**.something.assigned | experiment | The entity that is participating in the action. |
  | actions | splitter.experiment.**something.assigned** | something.assigned | The action(s) describing the event. |

- [Consumer tags][hutch-consumer-tag-pr] are configured to contain the name of the consuming application.

## How to run?

Without arguments `bin/run` will connect to `localhost:15672` with the default guest user.

### Configuration

| Setting | Configuration | Effect | Default |
| ------- | ------------- | ------ | ------- |
| RabbitMQ management URL | `-uURL`<br/>`--url=URL`<br/>or environment variable<br/>`RABBITMQ_API_URI` | Specifies the connection URL to RabbitMQ management API | http://guest:guest@localhost:15672/ |
| Save topology | `--save-topology=FILE` | After discovery save the topology to the given file. | disabled |
| Read topology | `--read-topology=FILE` | Skip discovery and use a stored topology file. | disabled |
| Choose format | `--format=FORMAT` | Choose an output format. `--help` will give a list of available options. | `DotFormat` |

#### Dot format specific options

| Setting | Configuration | Effect | Default |
| ------- | ------------- | ------ | ------- |
| Show only applications | `--dot-applications-only` | Creates a graph without entity nodes. | disabled |
| Label details | `--dot-label-detail=DETAILS` | Comma separated segment names to display on labels drawn between applications and/or entities. | `'actions'` |

### Show only applications

- **enabled**: will only show application to application relations.
- **disabled** (default): will show application to entity to application relations. The edge going into the entity and coming out of the entity will have the same label.

### Label details

Affects the labeling of edges:

- `'entity,actions'`: displays the entity name and the actions on the edge.
- `'entity'`: displays the entity name on the edge.
- `'actions'`: displays the actions on the edge.
- `''` (empty string): displays no labels.

Any combination and order of the above is allowed.

### Example

Running the discovery against a dockerised `rabbitmq:3.6-management`:

```
$ docker run --detach --publish 5672:5672 --publish 15672:15672 rabbitmq:3.6-management

$ RABBITMQ_API_URI=http://localhost:15672/ bin/run > test.dot
I, [2018-04-30T13:05:29.735060 #90042]  INFO -- : connecting to rabbitmq HTTP API (http://guest@127.0.0.1:15672/)
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
