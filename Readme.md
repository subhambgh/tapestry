#  Project 3 - Tapestry Algorithm
-------

Tapestry is a peer-to-peer overlay network routing algorithm. It uses a distributed hash table for each node to make routing faster. Tapestry is efficient, scalable, and self-repairing.

#### Group Members
------------
Subham Agrawal | UFID - 79497379
Pranav Puranik | UFID - 72038540

#### What is working
-------------
- We implemented the complete project as described by the problem statement.
-  Node ids are generated using sha1 hasing algorithm. The hash value has 8 digits and we are using the hexadecimal naming scheme.
-  For each node, we are storing the closest nodes in the routing table.
- Each cell of the routing table stores multiple (c = 3) references where the first one is the closest node and other are for backup in case of failure.
- Therefore, the size of routing table will be c x 8 x 16 (backup nodes x hash length x base-value).
- In addition to routing tables, each node also stores reverse references (backpointers) to other nodes that point at it.
- The last node is added dynamically to the network.  This new node contacts its root node to perform an acknowledged multicast and does backpointer traversal in order to populate their routing tables.
- While routing the messages, next node is selected from the routing table by looking at the closest match.  This surrogate routing is used to deliver the message to its receiver.
- Each node sends "numRequests" (given as input) messages to other nodes and keeps the maximum number of hops.
- A counter node stores the maximum count of hops for the entire network. After completing all the requests, the nodes send their maximum number of hops to this process.

We have also implemented the bonus, which is working well.

#### What is the largest network you managed to deal with
---------------
8000 node. Max hops recorded were 6.

#### Steps to run
-------------
From the project directory run...

>$ mix run project3.exs numNodes numRequests failureNodes


numNodes - number of worker nodes in the network.
numRequests - number of requests each node to send.
failureNodes (optional) - number of nodes user wants to fail.

#### References
-------------
- matrix.ex is a module used to store and easily access Routing tables in the tapestry network, available on the website- https://blog.danielberkompas.com/2016/04/23/multidimensional-arrays-in-elixir/
- https://pdos.csail.mit.edu/~strib/docs/tapestry/tapestry_jsac03.pdf
- http://cs.brown.edu/courses/cs138/s17/content/projects/tapestry.pdf
