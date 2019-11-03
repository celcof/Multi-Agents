;lines 5-360 are actual Netlogo code
;lines 362-683 are our UI
;lines 686-698 are the info section
;lines 932-1154 are behaviorspace settings
globals [cycles encounters nsteps]

;breed declarations
breed [ doves dove ]
breed [ hawks hawk ]
breed [ possessors possessor ]
breed [ traders trader]

;breeds and patches property assignments:
; - energy is a measure of the fitness of the agents. Since they fetch it from the environment, patches also own energy.
; - energy-time keeps track of the time passed after energy has been taken from a patch
; - xhere and yhere are the plane coordinates of an agent
; - tries is the number of attempts available for a turtle to take a step
; - property is a binary indicating an agent's status of owner (1) / intruder (0)
; - valuation is a binary indicating how a trader values either his own or his counterpart's property in a dispute over that property: "more" (value) or "less" (lessvalue)

; the functions that were adapted from the work of Rick O' Gorman (reference in the info section) are: to setup, to move, to reproduce and to perish.
; the focus of our work was the get-energy function, which is the key one because it concerns the interactions between agents choosing different strategies.

turtles-own [turtle-energy xhere yhere tries property valuation]
patches-own [energy energy-time]

;******************SETUP**************************
to setup
ca             ;clear all
set cycles 0
set encounters 0
set nsteps 0
ask patches [set pcolor green set energy-time 1]    ; all patches are initialized with full energy (green color)

; agents are created in a number specified by the user in the interface
create-doves init-doves
create-hawks init-hawks
create-possessors init-possessors
create-traders init-traders


; each breed is given a different color
ask doves
[set color black]
ask hawks
[set color red]
ask possessors
[set color yellow]
ask traders
[set color gray]

; all of the agents are scattered at random across the plane and given an initial energy that is specified by the user
; also turtles' property status and valuation parameter must be initialized (with a probabilistic approach)
ask turtles
  [setxy random world-width random world-height
   set turtle-energy init-energy
   ;let rdm random 1000
   ;    ifelse rdm <= f * 1000 [set property 1] [set property 0]
   ;let dice random-float 1
   ;    ifelse dice <= 0.5 [set valuation value] [set valuation lessvalue]        ;probability of valuing a property either more or less is fixed at 50% (stick with this?)
  ]

do-plot
reset-ticks
end


;*********************GO**************************

to go

; First off, after a certain specified amount of time has passed for a given depleted patch, energy is therein replenished.
ask patches with [energy-time >= energy-time-threshold and pcolor = green + 1]
[set pcolor green]

; Agents move. See "move" routine
ask turtles
  [move]
  ; After moving, agents potentially fight/take energy from terrain. See "get-energy" routine
get-energy

; After fighting over a spot of land, agents potentially spawn new agents or die. See "reproduce" and "perish" routines
ask turtles
[reproduce
perish]

; if there's no agent left on the ground, just plot zero and skip the subsequent lines until the end of "go" routine
if not any? turtles
[do-plot-zero
stop]

; plot population ratios at current simulation time (see "to-plot" routine)
; increment cycle (i.e. tick counter) and energy-time for every patch
do-plot
set cycles cycles + 1
ask patches
[set energy-time energy-time + 1]
tick
end


;*********************TO MOVE*************************

; Agents move. Their heading is changed at random within [-45°, 45°] rightwards and if there are 0 or 1 agents in the patch they're pointing to as a result, \\
; they're allowed to take a step. If they cannot move they have n = maxtries attempts to head elsewhere and potentially find an accessible spot.
; Agents consume one unit of energy by taking a step.
to move
set xhere xcor
set yhere ycor
set tries 1
let maxtries 10
while [xhere = xcor and yhere = ycor and tries < maxtries]
[rt random 46 - random 46
if count turtles-at dx dy < 2
[fd 1]
set tries tries + 1]
set turtle-energy turtle-energy - 1
set nsteps nsteps + 1
end


;**********************TO GET ENERGY*******************

to get-energy

; Agents that find themselves alone on an energy-provided patch increment their energy by "value" (that has to be specified upon initialization)
; Clearly, the correspondent patches lose their energy (this is represented by their color becoming lighter). Simultaneously, energy-time counter is set to zero
ask patches with [count turtles-here = 1 and pcolor = green]
  [ask turtles-here
    [set turtle-energy turtle-energy + ((value + lessvalue) / 2) ]
     set energy-time 0
     set pcolor green + 1
  ]


; On twofold populated green patches energy contention takes place (if there happens to be energy indeed)
; To tell agents what to do we need a stratified if hierarchy since their behaviour depends on both their breed and their opponent's breed
ask patches with [count turtles-here = 2 and pcolor = green]
[set encounters encounters + 1
 without-interruption
  [
    ask one-of turtles-here                ;asking turtle 1
     ; At every step, each agent is given the status of owner/intruder with a probability of f/1-f respectively (f is user-defined)
     ; Also, every owner/intruder is assigned a valuation number (binary choice) representing how much they value the disputed property
     ; There is an equal probability for both agents in a dispute to value the property at issue more/less than their counterpart.
    [let rdm random 1000
     ifelse rdm <= f * 1000 [set property 1] [set property 0]
     let dice random-float 1
     ifelse dice <= 0.5 [set valuation value] [set valuation lessvalue]
     let my-valuation valuation            ;need to store turtle 1's valuation in a new local variable as both valuations are needed later on to determine the spoils.
     if breed = hawks
       [ask other turtles-here             ;asking turtle 2
         [ifelse rdm <= f * 1000 [set property 0] [set property 1]
          ifelse dice <= 0.5 [set valuation lessvalue] [set valuation value]
          if breed = hawks
           [set turtle-energy (turtle-energy + 0.5 * valuation - cost)
              ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation - cost)]]    ; asks the turtle who did the last asking (turtle 1)
          ; HAWK vs HAWK: both get half the value they expect the property to be worth decreased by the fighting cost
          if breed = doves
           [ask myself [set turtle-energy (turtle-energy + my-valuation)]]
            ; HAWK vs DOVE: HAWK gets full value without paying any toll, DOVE gets nothing
          if breed = possessors
            [if property = 1                                                                 ; if turtle 2 is an owner, turtle 1 is automatically an intruder (and v.v.)
               [set turtle-energy (turtle-energy + 0.5 * valuation - cost)
                ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation - cost)]]
             if property = 0
               [ask myself [set turtle-energy (turtle-energy + my-valuation)]]
            ]
            ; HAWK vs POSSESSOR:
            ; - both gelf half the value (discounted by the fighting cost) if P is an owner, as the latter behaves as a H himself
            ; - HAWK gets full value and POSSESSOR gets nothing if P is an intruder, as the latter behaves as a D
          if breed = traders
            [if property = 1
               [set turtle-energy (turtle-energy + 0.5 * valuation - cost)
                ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation - cost)]]
             if property = 0
               [ask myself [set turtle-energy (turtle-energy + my-valuation)]]
            ]
            ; HAWK vs TRADER: same as HAWK vs POSSESSOR. T can't trade with H.
         ]
       ]

     if breed = doves
       [ask other turtles-here
         [ifelse rdm <= f * 1000 [set property 0] [set property 1]
          ifelse dice <= 0.5 [set valuation lessvalue] [set valuation value]
          if breed = hawks
            [set turtle-energy (turtle-energy + valuation)]
          ; DOVE vs HAWK: HAWK gets full value without paying any toll, DOVE gets nothing
          if breed = doves
            [set turtle-energy (turtle-energy + 0.5 * valuation)
               ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation)]]
              ; DOVE vs DOVE: both get half the value without paying any toll for fighting
          if breed = possessors
            [if property = 1
               [set turtle-energy (turtle-energy + valuation)]
             if property = 0
               [set turtle-energy (turtle-energy + 0.5 * valuation)
                ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation)]]
            ]
          ; DOVE vs POSSESSOR:
          ; - P gets full value and D gets nothing if POSSESSOR is an owner, as the latter behaves as a H
          ; - both get half the value without paying any toll if P is an intruder (D vs D)
          if breed = traders
            [if property = 1
               [set turtle-energy (turtle-energy + valuation)]
             if property = 0
               [set turtle-energy (turtle-energy + 0.5 * valuation)
                ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation)]]
            ]
          ; DOVE vs TRADER: same as DOVE vs POSSESSOR. T can't trade with D.
         ]
       ]

      if breed = possessors
        [ask other turtles-here
           [ifelse rdm <= f * 1000 [set property 0] [set property 1]
            ifelse dice <= 0.5 [set valuation lessvalue] [set valuation value]
            if breed = hawks
              [if property = 1
                 [set turtle-energy (turtle-energy + valuation)]
               if property = 0
                 [set turtle-energy (turtle-energy + 0.5 * valuation - cost)
                  ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation - cost)]]
              ]
            ; POSSESSOR vs HAWK: see above
            if breed = doves
              [if property = 1
                 [set turtle-energy (turtle-energy + 0.5 * valuation)
                  ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation)]]
               if property = 0
                 [ask myself [set turtle-energy (turtle-energy + my-valuation)]]

              ]
            ; POSSESSOR vs DOVE: see above
            if breed = possessors
             [if property = 1
                [set turtle-energy (turtle-energy + valuation)]
              if property = 0
                [ask myself [set turtle-energy (turtle-energy + my-valuation)]]
             ]
            ; POSSESSOR vs POSSESSOR
            ; P vs P always plays out as H vs D, roles depending on who's the owner and who's the intruder.
            if breed = traders
             [if property = 1
                [set turtle-energy (turtle-energy + valuation)]
              if property = 0
                [ask myself [set turtle-energy (turtle-energy + my-valuation)]]
             ]
           ; POSSESSOR vs TRADER: same as POSSESSOR vs POSSESSOR. T can't trade with P.
          ]
        ]

      if breed = traders
        [ask other turtles-here
          [ifelse rdm <= f * 1000 [set property 0] [set property 1]
           ifelse dice <= 0.5 [set valuation lessvalue] [set valuation value]
           if breed = hawks
            [if property = 1
               [set turtle-energy (turtle-energy + valuation)]
             if property = 0
               [set turtle-energy (turtle-energy + 0.5 * valuation - cost)
                ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation - cost)]]
            ]
           ; TRADER vs HAWK: like POSSESSOR vs HAWK. T behaves as a P whenever its counterpart is not a T aswell.
           if breed = doves
             [if property = 1
               [set turtle-energy (turtle-energy + 0.5 * valuation)
                ask myself [set turtle-energy (turtle-energy + 0.5 * my-valuation)]]
              if property = 0
               [ask myself [set turtle-energy (turtle-energy + my-valuation)]]
             ]
           ; TRADER vs DOVE: like POSSESSOR vs DOVE. T behaves as a P whenever its counterpart is not a T aswell.
           if breed = possessors
             [if property = 1
                [set turtle-energy (turtle-energy + valuation)]
              if property = 0
                [ask myself [set turtle-energy (turtle-energy + my-valuation)]]
             ]
           ; TRADER vs POSSESSOR: like POSSESSOR vs POSSESSOR. T behaves as a P whenever its counterpart is not a T aswell.
           if breed = traders
             [if property = 1                      ;counterpart is an owner
                [if valuation = value              ;counterpart values its property more: no trade can take place
                   [set turtle-energy (turtle-energy + valuation)]
                 if valuation = lessvalue          ;counterpart values its property less i.e. wants to sell it to the intruder
                   [set turtle-energy (turtle-energy + x - valuation)
                    ask myself[set turtle-energy (turtle-energy + my-valuation - x)]]
                ]
              if property = 0                      ;counterpart is an intruder
                [if valuation = value              ;counterpart values the intruded property more i.e. wants to buy it
                   [set turtle-energy (turtle-energy + valuation - x)]
                    ask myself[set turtle-energy(turtle-energy + x - my-valuation)]]
                 if valuation = lessvalue          ;counterpart values the intruded property less: no trade can take place
                   [ask myself[set turtle-energy(turtle-energy + my-valuation)]]
             ]
           ; TRADER vs TRADER:
           ; Intruders that happen to value an intruded property more than its owner will buy it for the price of x.
           ; If this condition is not matched, T vs T will play out as a P vs P i.e. H vs D
          ]
        ]
      ]
; thereafter patches lose energy and counter is set to zero
set energy-time 0
set pcolor green + 1
]
]
end


;***************TO REPRODUCE**********************

; As soon as agents reach a certain user-defined threshold they reproduce asexually. As a result, their energy is halved and a new \\
; Agent of the same breed spawns on the same patch. Thus, it gets a completely random heading and it enters the "move" routine
to reproduce
if turtle-energy > reproduce-threshold
[set turtle-energy turtle-energy / 2
hatch 1
[rt random 360
  move]]
end


;****************T0 PERISH**********************

; If a turtle's energy becomes negative, the turtle will die. When all turtles of a certain breed die because they run out of energy, the breed/strategy is considered extinct.
to perish
if turtle-energy < 0
[die]
end


;******************PLOTS**************************

; Plot current fractions of each breed with respect to the total environment population.
to do-plot
set-current-plot "Proportions"
set-current-plot-pen "Doves"
plot count doves / count turtles
set-current-plot-pen "Hawks"
plot count hawks / count turtles
set-current-plot-pen "Possessors"
plot count possessors / count turtles
set-current-plot-pen "Traders"
plot count traders / count turtles
end


to do-plot-zero
set-current-plot "Proportions"
set-current-plot-pen "Doves"
plot 0
set-current-plot-pen "Hawks"
plot 0
set-current-plot-pen "Possessors"
plot 0
set-current-plot-pen "Traders"
plot 0


end
@#$#@#$#@
GRAPHICS-WINDOW
463
10
750
298
-1
-1
13.3
1
10
1
1
1
0
1
1
1
-10
10
-10
10
0
0
1
ticks
30.0

BUTTON
20
50
87
83
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
105
50
168
83
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
21
95
193
128
init-doves
init-doves
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
20
137
193
170
init-hawks
init-hawks
0
100
30.0
1
1
NIL
HORIZONTAL

PLOT
21
369
434
590
proportions
Time
Frequency
0.0
100.0
0.0
1.0
true
true
"" ""
PENS
"Hawks" 1.0 0 -65536 true "" ""
"Doves" 1.0 0 -16777216 true "" ""
"Possessors" 1.0 0 -1184463 true "" ""
"Traders" 1.0 0 -7500403 true "" ""

SLIDER
223
279
406
312
init-energy
init-energy
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
224
232
406
265
reproduce-threshold
reproduce-threshold
0
100
29.0
1
1
NIL
HORIZONTAL

SLIDER
226
94
407
127
value
value
0
10
7.0
1
1
NIL
HORIZONTAL

SLIDER
225
189
405
222
cost
cost
0
10
1.4
0.1
1
NIL
HORIZONTAL

MONITOR
22
269
79
314
NIL
cycles
3
1
11

SLIDER
222
325
406
358
energy-time-threshold
energy-time-threshold
0
100
18.0
1
1
NIL
HORIZONTAL

MONITOR
96
269
188
314
NIL
count turtles
0
1
11

BUTTON
105
14
186
47
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
21
175
193
208
init-possessors
init-possessors
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
225
11
406
44
f
f
0
0.5
0.25
0.01
1
NIL
HORIZONTAL

SLIDER
21
218
193
251
init-traders
init-traders
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
226
50
407
83
x
x
lessvalue + 0.1
value - 0.1
3.0
0.1
1
NIL
HORIZONTAL

SLIDER
226
139
406
172
lessvalue
lessvalue
0
value
2.0
0.1
1
NIL
HORIZONTAL

MONITOR
97
323
191
368
NIL
encounters
1
1
11

MONITOR
26
321
84
366
NIL
nsteps
1
1
11

@#$#@#$#@
# Game

Each simulation run starts with a setup routine, as a user-defined number of agents, each with its own strategy - referred to as a breed in the Netlogo jargon - are randomly scattered across a flat square environment consisting of 225 patches. Agents start with a fixed amount of energy and, as they lose a unit of it at each time step, they need to move in order to find some more. Energy can thus be fetched from free patches or, in the event that two agents end up on the same one, through a contention. Patches that recently got their energy taken away need a fixed amount of time to have it replenished. Another key feature of the simulation is the reproduction/death mechanism: when they reach a certain amount of energy agents can reproduce asexually at the cost of half of their energy and will generate an agent of the same breed as a result; on the other hand, agents that got no residual energy are bound to instantly be removed from the environment. Clearly, a breed whose agents eventually all die is considered to be extinct.
It is noteworthy that all of these enviroment/initialization parameters need to be fixed before exploring the very payoff parameter space. In particular, we sought for a configuration in which the ratio between encounters of two agents and total steps taken (i.e. the density of agents) wasn't too small, the total population of agents was roughly constant (or at least not likely to snowball or be decimated too quickly) and the time needed for a single strategy to lock in as ESS not too long. 
To simulate contentions over a patch we need to set up several parameters that appear in the payoff matrices:
    - value is the asset value V i.e. the amount of energy contained in every patch.
    - cost is the toll h hawks pay for figthing.
    - f is the fraction of confrontations wherein any given agent expects to be an owner (and 1-f is the frequency with which it expects to be an intruder). We make use of a PRNG to actually interpret f as a probability and thus, as soon as they meet on the same patch, assign a binary parameter to both agents. Although every contending agent has this ownership status assigned at any given time, only Possessors and, if they're present, Traders, will change their behaviour accordingly.
    - lessvalue. In the Hawk-Dove-Possessor-Trader game only, each agent fighting over a patch has an equal probability to value it value or lessvalue, the latter being smaller than the former. This binary parameter actually affects all the breeds as agents winning a dispute will gain an amount of energy that depends on how they value the asset. On top of that, traders that meet with each other have the chance of trading the asset if they judge it being convenient.
    - x is the price, bounded in [lessvalue, value] that intruding traders that value their counterpart's property more than them will pay to buy it. This way, both traders making a deal over a patch will both benefit from that - i.e. they will both gain a positive amount of energy - which is the very reason why we expect to see their strategy as evolutionarily preferred.

# Reference:
Credit for the original model set-up has to be given to Rick O' Gorman's evolutionary Netlogo model (downloadable at http://ccl.northwestern.edu/netlogo/models/community/GameTheory).
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bee
true
0
Polygon -1184463 true false 151 152 137 77 105 67 89 67 66 74 48 85 36 100 24 116 14 134 0 151 15 167 22 182 40 206 58 220 82 226 105 226 134 222
Polygon -16777216 true false 151 150 149 128 149 114 155 98 178 80 197 80 217 81 233 95 242 117 246 141 247 151 245 177 234 195 218 207 206 211 184 211 161 204 151 189 148 171
Polygon -7500403 true true 246 151 241 119 240 96 250 81 261 78 275 87 282 103 277 115 287 121 299 150 286 180 277 189 283 197 281 210 270 222 256 222 243 212 242 192
Polygon -16777216 true false 115 70 129 74 128 223 114 224
Polygon -16777216 true false 89 67 74 71 74 224 89 225 89 67
Polygon -16777216 true false 43 91 31 106 31 195 45 211
Line -1 false 200 144 213 70
Line -1 false 213 70 213 45
Line -1 false 214 45 203 26
Line -1 false 204 26 185 22
Line -1 false 185 22 170 25
Line -1 false 169 26 159 37
Line -1 false 159 37 156 55
Line -1 false 157 55 199 143
Line -1 false 200 141 162 227
Line -1 false 162 227 163 241
Line -1 false 163 241 171 249
Line -1 false 171 249 190 254
Line -1 false 192 253 203 248
Line -1 false 205 249 218 235
Line -1 false 218 235 200 144

bird1
false
0
Polygon -7500403 true true 2 6 2 39 270 298 297 298 299 271 187 160 279 75 276 22 100 67 31 0

bird2
false
0
Polygon -7500403 true true 2 4 33 4 298 270 298 298 272 298 155 184 117 289 61 295 61 105 0 43

boat1
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 33 230 157 182 150 169 151 157 156
Polygon -7500403 true true 149 55 88 143 103 139 111 136 117 139 126 145 130 147 139 147 146 146 149 55

boat2
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 157 54 175 79 174 96 185 102 178 112 194 124 196 131 190 139 192 146 211 151 216 154 157 154
Polygon -7500403 true true 150 74 146 91 139 99 143 114 141 123 137 126 131 129 132 139 142 136 126 142 119 147 148 147

boat3
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 37 172 45 188 59 202 79 217 109 220 130 218 147 204 156 158 156 161 142 170 123 170 102 169 88 165 62
Polygon -7500403 true true 149 66 142 78 139 96 141 111 146 139 148 147 110 147 113 131 118 106 126 71

box
true
0
Polygon -7500403 true true 45 255 255 255 255 45 45 45

butterfly1
true
0
Polygon -16777216 true false 151 76 138 91 138 284 150 296 162 286 162 91
Polygon -7500403 true true 164 106 184 79 205 61 236 48 259 53 279 86 287 119 289 158 278 177 256 182 164 181
Polygon -7500403 true true 136 110 119 82 110 71 85 61 59 48 36 56 17 88 6 115 2 147 15 178 134 178
Polygon -7500403 true true 46 181 28 227 50 255 77 273 112 283 135 274 135 180
Polygon -7500403 true true 165 185 254 184 272 224 255 251 236 267 191 283 164 276
Line -7500403 true 167 47 159 82
Line -7500403 true 136 47 145 81
Circle -7500403 true true 165 45 8
Circle -7500403 true true 134 45 6
Circle -7500403 true true 133 44 7
Circle -7500403 true true 133 43 8

circle
false
0
Circle -7500403 true true 35 35 230

person
false
0
Circle -7500403 true true 155 20 63
Rectangle -7500403 true true 158 79 217 164
Polygon -7500403 true true 158 81 110 129 131 143 158 109 165 110
Polygon -7500403 true true 216 83 267 123 248 143 215 107
Polygon -7500403 true true 167 163 145 234 183 234 183 163
Polygon -7500403 true true 195 163 195 233 227 233 206 159

sheep
false
15
Rectangle -1 true true 90 75 270 225
Circle -1 true true 15 75 150
Rectangle -16777216 true false 81 225 134 286
Rectangle -16777216 true false 180 225 238 285
Circle -16777216 true false 1 88 92

spacecraft
true
0
Polygon -7500403 true true 150 0 180 135 255 255 225 240 150 180 75 240 45 255 120 135

thin-arrow
true
0
Polygon -7500403 true true 150 0 0 150 120 150 120 293 180 293 180 150 300 150

truck-down
false
0
Polygon -7500403 true true 225 30 225 270 120 270 105 210 60 180 45 30 105 60 105 30
Polygon -8630108 true false 195 75 195 120 240 120 240 75
Polygon -8630108 true false 195 225 195 180 240 180 240 225

truck-left
false
0
Polygon -7500403 true true 120 135 225 135 225 210 75 210 75 165 105 165
Polygon -8630108 true false 90 210 105 225 120 210
Polygon -8630108 true false 180 210 195 225 210 210

truck-right
false
0
Polygon -7500403 true true 180 135 75 135 75 210 225 210 225 165 195 165
Polygon -8630108 true false 210 210 195 225 180 210
Polygon -8630108 true false 120 210 105 225 90 210

turtle
true
0
Polygon -7500403 true true 138 75 162 75 165 105 225 105 225 142 195 135 195 187 225 195 225 225 195 217 195 202 105 202 105 217 75 225 75 195 105 187 105 135 75 142 75 105 135 105

wolf
false
0
Rectangle -7500403 true true 15 105 105 165
Rectangle -7500403 true true 45 90 105 105
Polygon -7500403 true true 60 90 83 44 104 90
Polygon -16777216 true false 67 90 82 59 97 89
Rectangle -1 true false 48 93 59 105
Rectangle -16777216 true false 51 96 55 101
Rectangle -16777216 true false 0 121 15 135
Rectangle -16777216 true false 15 136 60 151
Polygon -1 true false 15 136 23 149 31 136
Polygon -1 true false 30 151 37 136 43 151
Rectangle -7500403 true true 105 120 263 195
Rectangle -7500403 true true 108 195 259 201
Rectangle -7500403 true true 114 201 252 210
Rectangle -7500403 true true 120 210 243 214
Rectangle -7500403 true true 115 114 255 120
Rectangle -7500403 true true 128 108 248 114
Rectangle -7500403 true true 150 105 225 108
Rectangle -7500403 true true 132 214 155 270
Rectangle -7500403 true true 110 260 132 270
Rectangle -7500403 true true 210 214 232 270
Rectangle -7500403 true true 189 260 210 270
Line -7500403 true 263 127 281 155
Line -7500403 true 281 155 281 192

wolf-left
false
3
Polygon -6459832 true true 117 97 91 74 66 74 60 85 36 85 38 92 44 97 62 97 81 117 84 134 92 147 109 152 136 144 174 144 174 103 143 103 134 97
Polygon -6459832 true true 87 80 79 55 76 79
Polygon -6459832 true true 81 75 70 58 73 82
Polygon -6459832 true true 99 131 76 152 76 163 96 182 104 182 109 173 102 167 99 173 87 159 104 140
Polygon -6459832 true true 107 138 107 186 98 190 99 196 112 196 115 190
Polygon -6459832 true true 116 140 114 189 105 137
Rectangle -6459832 true true 109 150 114 192
Rectangle -6459832 true true 111 143 116 191
Polygon -6459832 true true 168 106 184 98 205 98 218 115 218 137 186 164 196 176 195 194 178 195 178 183 188 183 169 164 173 144
Polygon -6459832 true true 207 140 200 163 206 175 207 192 193 189 192 177 198 176 185 150
Polygon -6459832 true true 214 134 203 168 192 148
Polygon -6459832 true true 204 151 203 176 193 148
Polygon -6459832 true true 207 103 221 98 236 101 243 115 243 128 256 142 239 143 233 133 225 115 214 114

wolf-right
false
3
Polygon -6459832 true true 170 127 200 93 231 93 237 103 262 103 261 113 253 119 231 119 215 143 213 160 208 173 189 187 169 190 154 190 126 180 106 171 72 171 73 126 122 126 144 123 159 123
Polygon -6459832 true true 201 99 214 69 215 99
Polygon -6459832 true true 207 98 223 71 220 101
Polygon -6459832 true true 184 172 189 234 203 238 203 246 187 247 180 239 171 180
Polygon -6459832 true true 197 174 204 220 218 224 219 234 201 232 195 225 179 179
Polygon -6459832 true true 78 167 95 187 95 208 79 220 92 234 98 235 100 249 81 246 76 241 61 212 65 195 52 170 45 150 44 128 55 121 69 121 81 135
Polygon -6459832 true true 48 143 58 141
Polygon -6459832 true true 46 136 68 137
Polygon -6459832 true true 45 129 35 142 37 159 53 192 47 210 62 238 80 237
Line -16777216 false 74 237 59 213
Line -16777216 false 59 213 59 212
Line -16777216 false 58 211 67 192
Polygon -6459832 true true 38 138 66 149
Polygon -6459832 true true 46 128 33 120 21 118 11 123 3 138 5 160 13 178 9 192 0 199 20 196 25 179 24 161 25 148 45 140
Polygon -6459832 true true 67 122 96 126 63 144
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="HDPT_1" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count hawks</metric>
    <metric>count doves</metric>
    <metric>count possessors</metric>
    <metric>count traders</metric>
    <enumeratedValueSet variable="f">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduce-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lessvalue">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-energy">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-time-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cost">
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
      <value value="1.25"/>
      <value value="1.5"/>
      <value value="1.75"/>
      <value value="2"/>
      <value value="2.25"/>
      <value value="2.5"/>
      <value value="2.75"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-hawks">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-possessors">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-traders">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="value">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-doves">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HDP_1" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count hawks</metric>
    <metric>count doves</metric>
    <metric>count possessors</metric>
    <enumeratedValueSet variable="f">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduce-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lessvalue">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-energy">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-time-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cost">
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
      <value value="1.25"/>
      <value value="1.5"/>
      <value value="1.75"/>
      <value value="2"/>
      <value value="2.25"/>
      <value value="2.5"/>
      <value value="2.75"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-hawks">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-possessors">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-traders">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="value">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-doves">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HDPT_2" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count hawks</metric>
    <metric>count doves</metric>
    <metric>count possessors</metric>
    <metric>count traders</metric>
    <enumeratedValueSet variable="f">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduce-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lessvalue">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-energy">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-time-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cost">
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
      <value value="1.25"/>
      <value value="1.5"/>
      <value value="1.75"/>
      <value value="2"/>
      <value value="2.25"/>
      <value value="2.5"/>
      <value value="2.75"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-hawks">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-possessors">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-traders">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="value">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-doves">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HD_1" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count hawks</metric>
    <metric>count doves</metric>
    <enumeratedValueSet variable="f">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduce-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lessvalue">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-energy">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-time-threshold">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cost">
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
      <value value="1.25"/>
      <value value="1.5"/>
      <value value="1.75"/>
      <value value="2"/>
      <value value="2.25"/>
      <value value="2.5"/>
      <value value="2.75"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-hawks">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-possessors">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-traders">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="value">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-doves">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
