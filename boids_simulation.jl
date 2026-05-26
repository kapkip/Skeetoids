## ------------------------------------------------------------------
#  SECTION 1: ENVIRONMENT SETUP & DEPENDENCIES
#  Initializes native high-performance graphics and utilities.
## ------------------------------------------------------------------
using Revise
using GLMakie
using Random
using LinearAlgebra
include(joinpath(@__DIR__, "geography.jl"))
println("Dependencies successfully loaded. Engine is primed!")

## ------------------------------------------------------------------
#  SECTION 2: AGENT DEFINITIONS & INITIALIZATION
#  Defines the individual structural blueprint for the vectors.
## ------------------------------------------------------------------
# 1. Define distinct biological states using integers or symbols
# :seeking_host -> Look for blood meal
# :digesting    -> Rest and develop eggs
# :seeking_water -> Find cyan pools to lay eggs

mutable struct Boid # setting up position, direction, velocity
    x::Float64
    y::Float64
    vx::Float64
    vy::Float64
    state::Symbol    # Track current biological drive
    timer::Int       # Keep track of time spent in a state
end

#Set up boids positionality
function init_boids(n::Int, width=800.0, height=600.0; seed=42)
    rng = Xoshiro(seed)
    speed = 2.0
    [Boid(
        rand(rng) * width,              # 1. x spawning within bounds
        rand(rng) * height,             # 2. y
        (rand(rng) - 0.5) * speed * 2,  # 3. vx between -2.0-2.0
        (rand(rng) - 0.5) * speed * 2,  # 4. vy
        :seeking_host,                  # 5. state: they all start hungry
        0                               # 6. timer 
    ) for _ in 1:n]
end

## ------------------------------------------------------------------
#  SECTION 3: STEERING CORE & BEHAVIORAL RULES
#  The mathematical laws governing emergent swarming dynamics.
## ------------------------------------------------------------------
const MAX_SPEED = 2.0
const MIN_SPEED = 0.2
const SEP_RADIUS = 15.0  # <-- Changed from 25.0 to 15.0 for tighter mosquito spacing

# new default weights for the mosquito behavior
const DEFAULT_W_SEP = 1.8
const DEFAULT_W_ALI = 0.05
const DEFAULT_W_COH = 0.5
const DEFAULT_RADIUS = 50.0  # This will act as the shared radius for both Ali and Coh

#= Breaking down the Parameters:
    Separation(SEP_RADIUS & W_SEP): "personal space"; how close they can get before repel
                LOW = collision can happen even merge into single point
                HIGH = repel
    Alignment(W_ALI): tells boids how much to match the flight direction and speed of seen neighbors
                LOW = autonomy; HIGH conformity
                near zero looks "skeeterish" bc they never form flight lines they act more independently
    Cohesion(W_COH): "Loneliness"; calculates mean center of visible crowd and steers boid towards it
                LOW = swarm disintegration; HIGH = inward collapse
    Shared View(Radius): Controls the information network, how far each can look to find neighbors
                LOW = only a few neighbors, little global smoothing, fitful mapping (at 0 total chaos)
                HIGH = looks and averages position/direction of many neighbors, calm flow

    Example states: 
        HIGH coh; LOW ali; LOW radius: bouncing and repelling around central point (with geo)
=#

function clamp_speed!(b::Boid)
    s = sqrt(b.vx^2 + b.vy^2)
    if s > MAX_SPEED
        b.vx *= MAX_SPEED / s
        b.vy *= MAX_SPEED / s
    elseif s < MIN_SPEED && s > 0
        b.vx *= MIN_SPEED / s
        b.vy *= MIN_SPEED / s
    end
end

# Coding the Biological clock
#-------
function update_biology!(boids, water_nodes, width, height)
    for b in boids
        b.timer += 1 # Every frame, time moves forward

        # STATE 1: Looking for a host
        if b.state == :seeking_host #for today we'll just assume this is random
            if rand() < 0.0008 #changed from 0.002
                b.state = :digesting
                b.timer = 0
            end

            # STATE 2: Heavy and digesting blood
            # In update_biology!
        elseif b.state == :digesting
            if b.timer > 600
                # Add a little "jitter" so they don't all switch at once
                if rand() < 0.1
                    b.state = :seeking_water
                    b.timer = 0
                end
            end # this little end took me 8000 years to find

        # STATE 3: Ready to lay eggs!
        # --- BULLETPROOF WATER SEEKING ---
        elseif b.state == :seeking_water
            # Check if WATER_NODES actually exists and has items
            if @isdefined(WATER_NODES) && !isempty(WATER_NODES)
                for w in WATER_NODES
                    # We know it's a BreedingSite struct now, so use .pos
                    dx = w.pos[1] - b.x
                    dy = w.pos[2] - b.y
                    dist = sqrt(dx^2 + dy^2)

                    # If close enough to lay eggs, reset back to hunting hosts!
                    if dist < 15.0 # close contact threshold
                        b.state = :seeking_host
                        b.timer = 0
                        break
                    end
                end
            else
                # If no water is found, reset state so they don't get stuck in a 'thirsty' loop
                b.state = :seeking_host
            end
        end
    end
end
#------


function update_boids!(boids, w_sep, w_ali, w_coh, radius, bounce, width, height)
    n = length(boids)
    new_vx = zeros(n)
    new_vy = zeros(n)

    for i in 1:n
        b = boids[i]
        sep_x = sep_y = 0.0
        ali_x = ali_y = 0.0
        coh_x = coh_y = 0.0
        n_sep = n_ali = n_coh = 0

        for j in 1:n
            i == j && continue
            o = boids[j]
            dx = o.x - b.x
            dy = o.y - b.y
            dist = sqrt(dx^2 + dy^2)

            if dist < SEP_RADIUS && dist > 0
                push_strength = (SEP_RADIUS - dist) / dist
                sep_x -= (dx / dist) * push_strength
                sep_y -= (dy / dist) * push_strength
                n_sep += 1
            end

            if dist < radius
                ali_x += o.vx
                ali_y += o.vy
                n_ali += 1

                coh_x += o.x
                coh_y += o.y
                n_coh += 1
            end
        end

        fx = fy = 0.0
        if n_sep > 0
            fx += w_sep * sep_x / n_sep
            fy += w_sep * sep_y / n_sep
        end
        if n_ali > 0
            fx += w_ali * (ali_x / n_ali - b.vx)
            fy += w_ali * (ali_y / n_ali - b.vy)
        end
        if n_coh > 0
            fx += w_coh * (coh_x / n_coh - b.x) * 0.01
            fy += w_coh * (coh_y / n_coh - b.y) * 0.01
        end

        # --- OPTIMIZED WATER ATTRACTION FORCE ---
        # --- UPDATED WATER ATTRACTION FORCE ---
        if b.state == :seeking_water
            best_dist = Inf
            target_dx = 0.0
            target_dy = 0.0

            if @isdefined(WATER_NODES) && !isempty(WATER_NODES) # accessing geography
                for w in WATER_NODES
                    dx = w.pos[1] - b.x
                    dy = w.pos[2] - b.y
                    d = sqrt(dx^2 + dy^2)
                    if d < best_dist
                        best_dist = d
                        target_dx = dx
                        target_dy = dy
                    end
                end

                if best_dist > 0
                    # You could even turn 0.05 into a global constant (e.g., W_WATER = 0.05)
                    pull_strength = 0.05
                    fx += pull_strength * (target_dx / best_dist)
                    fy += pull_strength * (target_dy / best_dist)
                end
            end
        end

        # ----------------------------------------
        new_vx[i] = b.vx + fx
        new_vy[i] = b.vy + fy
    end

    for i in 1:n
        b = boids[i]
        b.vx = new_vx[i]
        b.vy = new_vy[i]
        clamp_speed!(b)

        b.x += b.vx
        b.y += b.vy

        if bounce
            if b.x < 0
                b.x = 0.0
                b.vx = abs(b.vx)
            end
            if b.x > width
                b.x = width
                b.vx = -abs(b.vx)
            end
            if b.y < 0
                b.y = 0.0
                b.vy = abs(b.vy)
            end
            if b.y > height
                b.y = height
                b.vy = -abs(b.vy)
            end
        else
            b.x = mod(b.x, width)
            b.y = mod(b.y, height)
        end
    end
end


## ------------------------------------------------------------------
#  SECTION 4: GRAPHICS INTERFACE & SIMULATION CANVAS
#  Launches the interactive dashboard window natively.
## ------------------------------------------------------------------

# 1. Initialize stable global state
#global_boids = init_boids(500, 1600.0, 1200.0)

global_boids = init_boids(300, 1600.0, 1200.0) #smoll test

# 2. Build layout window
fig = Figure(size=(900, 700), backgroundcolor=:gray20)

# 3. Create native standalone slider grids
sg = SliderGrid(fig[2, 1],
    (label="Separation", range=0.0:0.1:5.0, startvalue=DEFAULT_W_SEP),
    (label="Alignment", range=0.0:0.01:1.0, startvalue=DEFAULT_W_ALI),
    (label="Cohesion", range=0.0:0.05:3.0, startvalue=DEFAULT_W_COH),
    (label="Radius", range=10.0:5.0:200.0, startvalue=DEFAULT_RADIUS),
    (label="Max Speed", range=0.5:0.1:5.0, startvalue=2.0), # New control!
)

# 4. Stylize canvas
ax = Axis(fig[1, 1], backgroundcolor=:black, aspect=DataAspect(), title="Vector Swarm Simulation")
xlims!(ax, 0, 1600)  # Expanded from 800
ylims!(ax, 0, 1200)  # Expanded from 600

# Map biological states to distinct visual colors
function state_color(state)
    if state == :seeking_host
        return :deeppink    # Vibrant pink for hunters (stand out against black)
    elseif state == :digesting
        return :gray60      # Neutral, dull gray for resting
    else
        return :yellow      # Electric yellow for "thirsty" vectors
    end
end

# 5. Connect tracking states
positions = Observable(Point2f[(b.x, b.y) for b in global_boids])

# NEW: Track the biological state colors instead of vector angles
b_colors = Observable(Symbol[state_color(b.state) for b in global_boids])

# SWAPPED: 'color' now points to b_colors, and we dropped the colormap/colorrange
scatter!(ax, positions, markersize=8, color=b_colors)

# Pull the layout directly from our geography engine
render_water!(ax)

# 6. Extract raw values from reactive UI elements
w_sep = sg.sliders[1].value
w_ali = sg.sliders[2].value
w_coh = sg.sliders[3].value
radius = sg.sliders[4].value

# Display the window frame
display(fig)

## ------------------------------------------------------------------
#  SECTION 5: LIVE ANIMATION RUNNER
## ------------------------------------------------------------------
println("Starting animation loop...")

# The @async makes this run in the background so it doesn't block the UI
@async begin # <--- FIX 2: Removed stray '@Pro' typo
    # This loop keeps the animation running
    while isopen(fig.scene)

        # 1. Biology & Physics
        update_biology!(global_boids, WATER_NODES, 1600.0, 1200.0)
        update_boids!(global_boids, w_sep[], w_ali[], w_coh[], radius[], false, 1600.0, 1200.0)

        # 2. Update Visuals
        if isopen(fig.scene)
            positions.val = Point2f[(b.x, b.y) for b in global_boids]
            b_colors.val = [state_color(b.state) for b in global_boids]

            notify(positions)
            notify(b_colors)
        end

        # 3. Control frame rate
        yield()
        sleep(0.016)
    end
    println("Animation loop stopped.")
end # <--- FIX 3: Added missing 'end' for the async begin block


#=Terminal commands for fun:

    Basic Commands
to pause/unpause
is_running = false ; is_running = true

Force everyone back to square one (Hungry hunters)
foreach(b -> b.state = :seeking_host, global_boids)

Make everyone instantly fat and sleepy (Digesting):
foreach(b -> b.state = :digesting, global_boids)

Blow the whole swarm to the right:
foreach(b -> b.vx += 1.5, global_boids)
and left:  foreach(b -> b.vy -= 1.5, global_boids)

Find out what the highest timer value currently is in the swarm:
maximum(b -> b.timer, global_boids)

border teleport
Line them all up on the left wall x=10
foreach(b -> b.x = 10.0, global_boids)
and right: foreach(b -> b.y = 10.0, global_boids)

DATA stuff
Get the exact coordinates of the first x boids (fill in with w/e val):
[(b.x, b.y) for b in global_boids[1:x]]


EXTRA FUN
    1. Population Control (God Mode)
Want to see how many mosquitoes are currently in each biological state? 
Paste into the terminal:
    println("Hunting: ", count(b -> b.state == :seeking_host, global_boids))
    println("Digesting: ", count(b -> b.state == :digesting, global_boids))
    println("Thirsty: ", count(b -> b.state == :seeking_water, global_boids))

Want to instantly force every single boid to wake up and start hunting for water?
    for b in global_boids; b.state = :seeking_water; b.timer = 0; end

    2. Chaotic Physics Modifiers
Want to give the swarm a massive sudden speed boost (like a gust of wind)?
    for b in global_boids; b.vx *= 5.0; b.vy *= 5.0; end

Want to freeze them in mid-air spatially, 
but keep their internal biological clocks ticking?
   for b in global_boids; b.vx = 0.0; b.vy = 0.0; end

   Want to completely teleport the entire swarm into a single tight cluster 
   right in the dead-center of your map ($(800, 600)$)?
        or b in global_boids; b.x = 800.0; b.y = 600.0; end

3. Biological Time-Warping
Want to artificially age all the digesting mosquitoes so they instantly get ready to lay eggs? 
This pushes their timers past the 600-frame limit:
    for b in global_boids
    if b.state == :digesting
        b.timer = 599 # One frame away from checking the jitter!
    end
end

4. Teleporting Individual "Super-Boids"
Want to track just the very first boid (global_boids[1]), 
see where it is, and manually fling it across the screen?

Check its stats:
    global_boids[1]
Make it an ultra-fast rogue mosquito traveling diagonally:
    global_boids[1].vx = 5.0; global_boids[1].vy = 5.0;

    Pro-Tip for Terminal Chaos:
If you type a command and nothing changes on your screen immediately, 
it means GLMakie is waiting for the next frame draw. 
    Just run a quick notify(positions) or let the live loop step forward once, 
        and you'll see your terminal commands instantly warp reality on the canvas!
    =#