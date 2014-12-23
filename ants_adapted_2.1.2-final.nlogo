globals [ pickups
          drops
          moves
          previous-cycle
          cycles
          general-fitness
          actual-kp
          step-counter
          ant-speed
          decimilli-ticks
          required-runs ]

patches-own [
  pheromone             ;; list of datum-pairs containing both pheromone datum and pheromone quality
]

turtles-own [
  data-value
]

breed [ants ant]
breed [data datum]

ants-own [
  logical-clock        ;; number of times the ant has been selected for an action
         ;; value of the datum the ant is carrying, 0 if the ant is carrying no datum
  ant-data-id          ;; type of datum the ant is carrying (only for color of datum-piece)
  dropzone             ;; patch where the ant drops a piece of datum he is carrying
  scout
  pheromone-source
]

data-own [
  datum-id
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-ants
  setup-data
  setup-patches
  set pickups 0
  set drops 0
  set moves 0
  set previous-cycle -1
  set cycles 0
  set actual-kp k_p
  set step-counter 0
  set ant-speed 1
  reset-ticks
end

to setup-ants
    set-default-shape ants "ant"
    create-ants population
    [ set color black
      set logical-clock 0
      set data-value list 99 99
      set ant-data-id 0
      let right-patch available-patch
      setxy [pxcor] of right-patch [pycor] of right-patch
      set heading 90
      set pheromone-source (list)]
      
      ask ants with [who < population * scout-ratio]
      [ set scout true]
      ask ants with [who >= population * scout-ratio]
      [ set scout false]
    
end

to setup-data
  let sd .15
  set-default-shape data "triangle"
  create-data data-elements-per-id
  [ set data-value list (random-normal .2 sd) (random-normal .2 sd)
    set datum-id 1 ]
  create-data data-elements-per-id
  [ set data-value list (random-normal .2 sd) (random-normal .8 sd)
    set datum-id 2 ]
  create-data data-elements-per-id
  [ set data-value list (random-normal .8 sd) (random-normal .2 sd)
    set datum-id 3 ]
  create-data data-elements-per-id
  [ set data-value list (random-normal .8 sd) (random-normal .8 sd)
    set datum-id 4 ]
  ask data
  [ setup-data-color-and-shape datum-id
    let right-patch available-patch
    setxy [pxcor] of right-patch [pycor] of right-patch ]
end

to-report available-patch
    loop
    [ let xoption random-xcor
      let yoption random-ycor
      if not any? turtles-at xoption yoption
      [ report patch xoption yoption]
    ]
end

to setup-data-color-and-shape [id]
    set color magenta - 30 * (datum-id - 1)
    if id = 1
    [set shape "triangle"]
    if id = 2
    [set shape "x"]
    if id = 3
    [set shape "circle"]
    if id = 4
    [set shape "square"]
end

to setup-patches
  ask patches
  [ setup-pheromone
    recolor-patch ]
end

to setup-pheromone  ;; patch procedure
  set pheromone (list)
end

to recolor-patch  ;; patch procedure
  ifelse empty? pheromone
  [ set pcolor white]
  [ set pcolor green + (5 - last first pheromone / (pheromone-life / 5))]
end

to degrade-pheromone
  set pheromone map [lput (last ? - 1) (butlast ?) ] pheromone
  
  while [not empty? pheromone and last first pheromone = 0]
  [ set pheromone remove-item 0 pheromone]
  
  recolor-patch
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button

  if ticks >= max-cycles [stop]
  
  while [decimilli-ticks < 10000]
  [
  ask one-of ants
  [ set logical-clock logical-clock + 1
    
    let speed-factor 1
    if scout and high-speed
    [ set speed-factor 4 ]
    while [step-counter < ant-speed * speed-factor]
    [ handle-data
      if use-pheromones and scout
      [ drop-pheromone ]
    
      choose-heading
      ifelse not beaming or empty? pheromone-source
      [ move-to patch-ahead 1 ]
      [ move-to patch first pheromone-source last pheromone-source
        set pheromone-source (list)]
      set step-counter step-counter + 1]
    set step-counter 0 ]
  
  if use-pheromones  
  [ ask patches with [not empty? pheromone]
    [ degrade-pheromone]]
   
  set decimilli-ticks decimilli-ticks + 1
  ]
   
  set decimilli-ticks 0  
  tick
  
  calculate-general-fitness
  if SACA and actual-kp > .001
  [set actual-kp actual-kp * .98]
end

to handle-data  ;; turtle procedure
  let data-environment map [[data-value] of ?] vision-area patch-here       ;; make a list of the pieces of datum around the ant
  
  ifelse ant-data-id = 0     ;; the ant is not carrying any datum

  [ let pickup-option one-of data-here    ;; select a piece of datum at the postion of the turtle
    if pickup-option != nobody            ;; check if that datum is actually there 
  
    [ let density f_i [data-value] of pickup-option data-environment   ;; calculate f(i) in a method below, giving as arguments 
                                                                         ;; the datum at the position of the ant and the datum around the ant                     
      let Ppick calculate-Ppick density               ;; calculate the Ppick in a method below
      if Ppick > random-float 1
      [ set pickups pickups + 1
        set color orange                              ;; visually reflect the ant is carrying datum
        set ant-data-id [datum-id]  of pickup-option
        set data-value [data-value] of pickup-option  ;; the ant takes the value of the datum element
        ask pickup-option [die]                           ;; the datum is removed from the grid
        ]]]
      
    [ let density f_i data-value data-environment
      let Pdrop calculate-Pdrop density                ;; calculate the Pdrop in a method below
      if Pdrop > random-float 1
      [ set drops drops + 1
        let datum-id-buffer ant-data-id
        let datum-buffer data-value                ;; buffer is needed because of netlogo
        ifelse not any? data-here
        [set dropzone patch-here]
        [set dropzone free-patch-near patch-here]
        ask dropzone [ sprout-data 1 
                       [ set data-value datum-buffer
                         set datum-id datum-id-buffer
                         setup-data-color-and-shape datum-id ]] ;; create a new datum-element with the value the ant was carrying
        set color black
        set ant-data-id 0
        set data-value list 99 99 ] ;; reflect that the ant is no longer carrying datum
      ]                          
end

to drop-pheromone
  if ant-data-id != 0
  [ let pheromone-data (list data-value pheromone-life)
    ask patch-here
    [ set pheromone lput pheromone-data pheromone ]
    ]  
end

to choose-heading
  let angle 0
  let angle-stepsize 360 / degrees-of-movement

  if ant-data-id != 0 and use-pheromones and not scout
  
  [ let best-option (list 99 0 1 (list)) ;; datum element with baselines for pheromone difference, freshness and direction
 
    while [angle < 359 ]
    [ if not empty? [pheromone] of patch-right-and-ahead angle 1
      [ set best-option best-pheromone [pheromone] of patch-right-and-ahead angle 1 data-value best-option angle ]
      
      set angle angle + angle-stepsize
    ]
            
    if last butlast best-option != 1
    [ set heading heading + last butlast best-option
      if beaming
      [ set pheromone-source locate-pheromone-source last best-option ]
      stop ]
    ]
    set heading heading + (random (degrees-of-movement - 1) * angle-stepsize)
    ;; show "puppies"
end
 
to-report best-pheromone [pheromones-at-patch datum-carried threshold direction]
  let best-option threshold
  
  foreach pheromones-at-patch
      [ let ph-difference datum-difference first ? datum-carried
        let ph-freshness last ?
        
        if ph-difference > 0 and ph-difference < ph-threshold 
        [ ifelse first best-option > ph-difference
          [ set best-option (list ph-difference ph-freshness direction first ?) ]
          [ if first best-option = ph-difference
            [ if first butfirst best-option < ph-freshness
              [ set best-option (list ph-difference ph-freshness direction first ?) ]]]]
        ]
          
  report best-option        
end

to-report locate-pheromone-source [target]
  let target-buffer turtles with [first data-value = first target and last data-value = last target]
  report list [xcor] of one-of target-buffer [ycor] of one-of target-buffer
end

to calculate-general-fitness
  let patches-with-data sort (patches with [any? data-here])
  let data-list map [one-of data-on ?] patches-with-data
  let data-values map [[data-value] of ?] data-list
  let individual-surroundings map [map [[data-value] of ?] vision-area ?] patches-with-data
  let individual-fitnesses (map [f_i ?1 ?2] data-values individual-surroundings)

  set general-fitness sum individual-fitnesses
end

to-report vision-area [area-center]
  report sort data-on patches with [ pxcor < [pxcor] of area-center + (d / 2) and 
                                     pxcor > [pxcor] of area-center - (d / 2) and
                                     pycor < [pycor] of area-center + (d / 2) and 
                                     pycor > [pycor] of area-center - (d / 2) ]
end

to-report f_i [datum-at-position data-in-area]
  let data-differences map [1 - (datum-difference datum-at-position ?) / alpha] data-in-area
  report ((sum data-differences) / (d ^ 2))
end

to-report datum-difference [datum-at-ant datum-around-ant]
  let xdifference first datum-at-ant - first datum-around-ant
  let ydifference last datum-at-ant - last datum-around-ant
  report sqrt (xdifference ^ 2 + ydifference ^ 2)
end

to-report calculate-Ppick [density]
  report (actual-kp / (actual-kp + density)) ^ 2
end

to-report calculate-Pdrop [density]
  ifelse density < k_d
  [ report 2 * density ]
  [ report 1]
end

to-report free-patch-near [origin]
  let counter 1
  let nearby-patches origin
  loop
  [ ask origin 
    [ set nearby-patches patches in-radius counter with [not any? data-here]]
    if any? nearby-patches
    [ report one-of nearby-patches] 
    set counter counter + 1]
end
@#$#@#$#@
GRAPHICS-WINDOW
420
10
838
449
25
25
8.0
1
10
1
1
1
0
1
1
1
-25
25
-25
25
0
0
1
ant selections
30.0

BUTTON
20
60
100
93
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
115
60
190
93
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
20
15
190
48
population
population
0.0
200.0
40
5
1
NIL
HORIZONTAL

MONITOR
20
110
150
155
pieces of data on grid
count data
17
1
11

INPUTBOX
20
220
110
280
d
7
1
0
Number

INPUTBOX
120
220
210
280
alpha
0.35
1
0
Number

INPUTBOX
120
285
210
345
k_d
0.05
1
0
Number

INPUTBOX
20
285
110
345
k_p
0.2
1
0
Number

MONITOR
20
165
150
210
# of ants carrying data
count ants with [ant-data-id != 0]
17
1
11

MONITOR
160
110
220
155
NIL
pickups
17
1
11

MONITOR
160
165
220
210
NIL
drops
17
1
11

MONITOR
235
135
290
180
scouts
count ants with [scout]
17
1
11

SLIDER
220
15
407
48
data-elements-per-id
data-elements-per-id
0
200
100
5
1
NIL
HORIZONTAL

MONITOR
300
220
360
265
cycles
cycles
17
1
11

INPUTBOX
220
220
290
280
max-cycles
100
1
0
Number

PLOT
215
355
415
505
general fitness
NIL
NIL
0.0
100.0
-50.0
50.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot general-fitness"

MONITOR
420
460
527
505
NIL
general-fitness
6
1
11

INPUTBOX
120
355
210
415
pheromone-life
500
1
0
Number

SWITCH
20
430
165
463
use-pheromones
use-pheromones
0
1
-1000

CHOOSER
220
60
365
105
degrees-of-movement
degrees-of-movement
4 8
0

SWITCH
220
285
310
318
SACA
SACA
0
1
-1000

INPUTBOX
20
355
110
415
ph-threshold
0.3
1
0
Number

CHOOSER
305
135
397
180
scout-ratio
scout-ratio
0.25 0.5 0.75
1

SWITCH
20
470
127
503
beaming
beaming
1
1
-1000

SWITCH
20
510
137
543
high-speed
high-speed
0
1
-1000

MONITOR
420
515
507
560
NIL
required-runs
17
1
11

@#$#@#$#@
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

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

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experimentHighSpeed" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>set required-runs cycles</final>
    <exitCondition>general-fitness &gt; 40</exitCondition>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentLowSpeed" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>set required-runs cycles</final>
    <exitCondition>general-fitness &gt; 40</exitCondition>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment2Kfactorial" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>general-fitness &gt; 40</exitCondition>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="200"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scout-ratio">
      <value value="0.25"/>
      <value value="0.75"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentSimpleComparativeExp12" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>general-fitness &gt; 40</exitCondition>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scout-ratio">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentSimpleComparativeExp3" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>general-fitness &gt; 40</exitCondition>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scout-ratio">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beaming">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentSimpleComparativeExp12Graph" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scout-ratio">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentSimpleComparativeExp3Graph" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scout-ratio">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beaming">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentHighSpeedBeam" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>general-fitness &gt; 40</exitCondition>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beaming">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scout-ratio">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentHighSpeedBeamGraph" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beaming">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scout-ratio">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experimentHighSpeedGraph" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>general-fitness</metric>
    <enumeratedValueSet variable="population">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SACA">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ph-threshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_p">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ant-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-cycles">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-life">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-elements-per-id">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="degrees-of-movement">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-pheromones">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k_d">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-speed">
      <value value="true"/>
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
1
@#$#@#$#@
