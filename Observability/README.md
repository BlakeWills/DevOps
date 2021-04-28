# Observability vs Monitoring

https://copyconstruct.medium.com/monitoring-and-observability-8417d1952e1c

Monitoring covers a set of known or predictable failures, observability is how well you can deal with unknown or unpredicatable failures.

Testing also plays a key role in monitoring, for a given set of predictable failures you should be able to surface the conditions for failure during testing, to verify the system fails in the correct (expected) way. Monitoring is then about being able to capture those known failure modes when the system is running.

A good question to ask during technical reviews would be: "What are your known failure modes? Have they been tested and how are they monitored?"

## Monitoring

> Monitoring is for symptom based alerting.

Two questions:
1. **What** is broken?
2. **Why** is it broken?

Black-box monitoring is useful for the **what**, this includes things like:
- Up / Down Checks ("The whole system is down")
- Latency metrics ("The system is slow")
- Error rates, etc.

White-box monitoring is useful for the **why**, but only in the case of known failure modes. An example of white-box monitoring would be collecting connection pool metrics to monitor pool exhaustion.

To build a monitorable system, you need to understand it's failure modes *proactively*, to make a system "more monitorable", you need to think carefully about as many failure modes as possible.

When we talk about failure modes, that doesn't mean understanding the root cause of the failure, it means being able to identify the ways in which the system may break, not necessarily the underlying fault. For example, with a system that takes messages off a queue, one failure mode would be queues building up.

For monitoring to be effective you need to have a set of core metrics that acurately describes the systems health status (**what**) or have monitoring around a set of failure modes. ("Monitoring a set of failure modes" is an interesting but not surprising approach, this is the **why**.)

You want high signal, low noise monitoring. Don't collect stuff you don't need. This seems counter intuative to the earlier advice about thinking of all possible failure modes. (Is this a problem that monitoring vs observability solves? - Yes!)

Further to this point, monitoring data should be actionable, either by being used in an alert or by being used in a system health overview. 

Think about context when visualising monitoring data. For example saying the disk is 90% full is useless (90% may be the correct utilisation), it would be better to display a graph showing disk usage trends to approximate when we need to clear own space or increase capacity (actionable!).

> Monitoring should be able to show the impact of a failure and the impact of any mitigation attempt or proposed fix.

> Monitoring should be dumb.

## Observability

> Observability is everything that monitoring isn't.

Monitoring should be simple. It should provide alerts for known failures and a high level overview of system health.

Since monitoring can't cover every failure mode, we need something "more". That *something*, is observability. It covers everything else such as log collection and analysis, profiling and traces.

> To increase the observability of a system is to increase it's "debugability".

Increasing monitoring of a system does not increase "debugability", instead it tells us sooner that there is a problem with the system (reduce MTTD), and if we have added monitoring for a new failure mode, tells us **what** the failure is.

Observability is all about the unknown failure modes.

> An observable system furnishes ample context about the systems inner working, unlocking the ability to uncover deeper, systemic issues.

## Things to think about

### Questions to ask

1. What is the goal?
What do you want to achieve with the monitoring? Is it purely a performance and reliability endevour or do you want to be able to look at trends (capacity planning), product usage / adoption, etc?

2. Latency overviews are meaningless.

Users interact with systems in many different ways, for example a webite has a mix of static and dynamic content, sometimes the static content is served by a CDN. Also some parts of a system are more "intensive" than others, e.g. serving a logon page vs loading a users data.

Because of this it becomes necessary to split out latency and know what we are actually measuring. E.G. Do we include requests for static content? Do we break latency down by system "area"?

Also, are our failures failing fast or slow? Could we improve validation to make things fail faster (and even return a client error instead of a server error?)
