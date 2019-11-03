# Design of Multi-Agent Systems

## How to run

1. Download and install the latest version of NetLogo (6.1.1) [here](https://ccl.northwestern.edu/netlogo/6.1.1/)
2. Run NetLogo and open the .nlogo file found in this repo.
3. Fiddle with the parameters at your leisure --> setup --> go


## UI and parameters documentation

###Sliders
- "init-(breed name)": initializes the number of agents of the correspondent breed
- "f": probability that any given agent is given the status of owner at any given time step
- "x": price traders will potentially exchange their asset for
- "value": bigger value of the asset (any given agent is equally likely to value an asset "value" or "lessvalue")
- "lessvalue": smaller value of the asset, see above
- "cost": fighting penalty
- "reproduce-threshold": amount of energy required for an agent to asexually reproduce
- "init-energy": initial amount of energy given to every agent
- "energy-time-thershold": number of timesteps required for an energy-depleted patch to have its energy replenished.

###Further UI info
- Arrows spread in the square box after the setup are agents; colors correspond to breeds according to the legend inside the plot.
- Dark green patches are provided with energy, whereas light green patches are not.
- The bottom-left plot is showing the evolution of relative agent count for each breed in real time: frequency = 0 means that a breed has undergone extinction, whereas frequency = 1 means that a breed has established itself as ESS for the current simulation.
