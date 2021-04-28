# Distributed Systems Observability Notes

## To Read:
https://copyconstruct.medium.com/testing-in-production-the-safe-way-18ca102d0ef1

## Failure Modes

There are at least three types of failure modes:

1. Tolerated: Sometimes a failure can be tolerated due to things like relaxed consistency guarentees (eventual consistency - if the replica fails it will be updated when it comes back online) and even queues (in non time-critical scenarios. So long as messages are being queued they will be delayed, but eventually processed.)

2. Alleviated: ("*graceful degredation*") For example, a failed service instance can be dropped out of a load balanced pool, circuit breakers or retry patterns can be used or you can control back pressure (tell the producer to slow down).

3. Triggered: Sometimes it's necessary to trigger a failure mode, the best example is load shedding to avoid a cascading failure under load.

It should be a common design goal to build systems whose failure modes fall into one the above catagories. By doing so, your systems become fault tolerant and a lot of the alerts become redundant, as the system is designed to handle the failure without intervention.

## Alerting Signals

Different schools of thought:

1. SRE BOOK: Saturation, Latency, Errors, Traffic
2. USE: Utilisation, Saturation, Errors of primary system resources for monitoring performance.
3. RED: Request rate, error rate, duration of request. (Request driven systems).

> USE is more infrastructure-focused, and RED is more focused on the end-user satisfaction.

https://thenewstack.io/monitoring-microservices-red-method/

^ Need to look into more.

## Coding and testing for observability.

It's ingrained in devs from the start of ther careers that all testing should be done pre-production. We code and test for success (meaning, we try to eliminate all possible failure modes - I think people have realised that this can't be done, especially in a world where time to market is key.) It is therefore better to code and test for failure. This means that we should assume something will break and have solid release engineering practices, such as canary deployments and quick roll-backs.

## Pillars of Observability

1. Logs
2. Metrics
3. Tracing

Logs should be used for discrete events and debugging purposes. Whilst it is possible to gather metrics from logs (especially web server logs), the downside is the costs to store the data are a LOT higher and there is a computational cost to every dashboard load that metrics simply don't incur.

Logs have a linear pattern to cost that correlates to user load, metrics have a static cost.

Metrics usually consists of four parts:

1. Metric Name
2. Timestamp
3. Labels (E.G. Environment, service name, etc)
4. Value

The downside of both logs and metrics is they are scoped to a system, they cannot give you information about indivudal requests.

Service meshes are a great way of gettin tracing "for free", as they implement the trace at the proxy level.

## Conclusion

An observability teams job is not to collect logs, metrics or traces, instead, it is their job to build an data-driven engineering culture based on facts and feedback.

The value of any observability system isn't the data that goes into it, but rather that insights and conclusions you can get out of it. Many organisations don't need full blown logs, metrics and tracing, they just need good alert based monitoring and logs.

## Further reading / thoughts:

1. Need to look at prometheus for metrics
2. How do you build a culture / evangalise effectively?