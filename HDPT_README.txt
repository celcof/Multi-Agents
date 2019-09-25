- Every breed now has an additional parameter "property", indicating the current status of owner/intruder.
  Indeed, each breed can be either, although only possessors will change their behaviour accordingly.
- Agents keep moving, regardless of their ownership status. A further necessary assumption I made is that, in order to find themselves
  on the same patch, two agents must have different ownership statuses, so that in a contention there's always an owner and an intruder.
- The status is chosen at random according to the user-defined parameter "f": each agent is, at any given time, an owner with probability f
  and an intruder with probability 1-f; f should lie within [0, 0.5].