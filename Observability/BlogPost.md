# Implementing Observability

This blog post is a reflection of the lessons I've learnt in the past couple of years as an SRE, where my team has a constant focus on systems observability. 

I hope this serves as a guide to others about the kind of things you need to think about when designing and implementing a monitoring solution.

## What do you want to achieve?

So you've been building a new service that you're almost ready to push to production, but something is missing, it's the dashboards. Every system needs a dashboard or twelve right?

Well, before you go and slap 

- Performance & Reliability (Is the system even up? Is the system fast?)
- Capacity Planning (When do I need to scale up? When will I need to buy more storage?)


## Difference between montitoring and observability






## How to start?

 - A good place to start is to think about your past incidents and the information you needed to resolve them.
 - How did you know you had fixed the issue? How did you know the system was healthy again?

## Lessons

### Dashboards aren't requirements.

I'm sure many of us have had our boss ask us to put together a dashboard for something, maybe it's a brand new service or even your database. You quickly scramble together a few visualations and it looks stunning. You've even defined some thresholds for alerts. You go to lunch proud of the great job you've done. And the dashboard is never look at again.

I've done this many times, and every single time, it's because our requirement was "build a dashboard".

Building a dashboard is never a requirement. A dashboard satisfies a requirement and it's your job to figure out what that requirement is and scope it out. The worst offenders here are always "system overview" dashboards, usually because somebody just slapped a bunch of metrics together that they thought were useful. The key to a "good" system overview dashboard is to build something that you can act on. That usually entails monitoring from the users perspective, for example: has the system just gone down? Has latency just sky rocketed? Have we suddenly had a bunch of errors? It's not "CPU is high".

**Rule:** If you can't act on it, bin it.

# TODO: Not clear here. Think about a dashboard you've built that hasn't been used and why?
Is there something else that's already in use?
Can you replace it with an alert?
Are the metrics you display and the way you display them useful? (E.G. Capacity planning is hard if you know the disk is 90% full but don't know how long it took to get there.)
If you just slap a load of metrics together and put it on a TV in the office (remember those days?)

### Monitoring Patterns
- Golden Signals
- USE
- RED

### Defining Availability

Shrodingers Service - It it up? Is it broken? Does anybody care?

### Focus on the user

### Latency

### Logs or metrics?