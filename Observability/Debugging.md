# Debugging under pressure 

https://www.youtube.com/watch?v=30jNsCVLpAE

- Too many alerts during an outage diverts attention away from the real cause.
- A system isn't highly available just because it's running on multiple computers. There are many things that can take multiple computers offline.
- Whilst microservices make life easier during development, they make life much, much harder in production. A monolith just became a complicated distributed system.
- It's crucial to understand why an instance of a service went down. It's not good enough to assume that the other instances will handle it. What if the instance went down because of load?

Debugging is the process of understanding a system, a.k.a, science.
It is about asking questions and answering them, not guessing.

Debugging must be viewed as the process by which systems are improved and understood, not just by making problems disappear (without root causing them!)


Overemphasising recovery will empede debugging and prevent root cause. You can't just restart it!

The idea that software is always broken is wrong. The culture needs fixing.

Systems shouldn't just recover, they should fail! Uncaught exceptions should cause the process to die and the internal state that lead to failure be presented.

Systems should verify input, they should also verify the correctness of their state.

You write a post-mortem to complete the understanding.