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
    x  :: Float64
    y  :: Float64
    vx :: Float64
    vy :: Float64
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
const MAX_SPEED  = 2.0
const MIN_SPEED  = 0.2
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

# --- WATER ATTRACTION FORCE ---
w_water = 0.05        # The weight (or intensity) of the homing instinct.
water_radius = 50.0 # The 'sensory range' of the vector agent in pixels.

for w in WATER_NODES
    # 1. Calculate the distance vector components from the boid to the water pool
    dx_w = w[1] - b.x  # Distance along the X axis
    dy_w = w[2] - b.y  # Distance along the Y axis
    
    # 2. Pythagorean theorem to find the straight-line distance (hypotenuse)
    dist_w = sqrt(dx_w^2 + dy_w^2)
    
    # 3. If the boid is within sensory range, calculate the steering pull
    if dist_w < water_radius && dist_w > 0
        # (dx_w / dist_w) normalizes the vector to a length of 1.0, 
        # meaning it represents a pure, raw direction toward the water.
        # Then we multiply it by our weight to decide how hard to pull.
        fx += w_water * (dx_w / dist_w)
        fy += w_water * (dy_w / dist_w)
    end
end
# ------------------------------
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
            if b.x < 0      b.x = 0.0;     b.vx = abs(b.vx)  end
            if b.x > width  b.x = width;   b.vx = -abs(b.vx) end
            if b.y < 0      b.y = 0.0;     b.vy = abs(b.vy)  end
            if b.y > height b.y = height;  b.vy = -abs(b.vy) end
        else
            b.x = mod(b.x, width)
            b.y = mod(b.y, height)
        end
    end
end

function heading_hue(vx, vy)
    angle = atan(vy, vx)          
    return (angle + π) / (2π)     
end

## ------------------------------------------------------------------
#  SECTION 4: GRAPHICS INTERFACE & SIMULATION CANVAS
#  Launches the interactive dashboard window natively.
## ------------------------------------------------------------------

# 1. Initialize stable global state
global_boids = init_boids(100)

# 2. Build layout window
fig = Figure(size=(900, 700), backgroundcolor=:gray20)

# 3. Create native standalone slider grids
sg = SliderGrid(fig[2, 1],
    (label="Separation", range=0.0:0.1:5.0,   startvalue=DEFAULT_W_SEP),
    (label="Alignment",  range=0.0:0.01:1.0,  startvalue=DEFAULT_W_ALI),
    (label="Cohesion",   range=0.0:0.05:3.0,  startvalue=DEFAULT_W_COH),
    (label="Radius",     range=10.0:5.0:200.0, startvalue=DEFAULT_RADIUS),
    (label="Max Speed",  range=0.5:0.1:5.0,   startvalue=2.0), # New control!
)

# 4. Stylize canvas
ax = Axis(fig[1, 1], backgroundcolor=:black, aspect = DataAspect(), title="Vector Swarm Simulation")
xlims!(ax, 0, 800)
ylims!(ax, 0, 600)

# 5. Connect tracking states
positions = Observable(Point2f[(b.x, b.y) for b in global_boids])
headings  = Observable(Float64[heading_hue(b.vx, b.vy) for b in global_boids])

scatter!(ax, positions, markersize=8, color=headings, colormap=:hsv, colorrange=(0.0, 1.0))
# Pull the layout directly from our geography engine
render_water!(ax)

# 6. Extract raw values from reactive UI elements
w_sep  = sg.sliders[1].value
w_ali  = sg.sliders[2].value
w_coh  = sg.sliders[3].value
radius = sg.sliders[4].value

# Display the window frame
display(fig)

## ------------------------------------------------------------------
#  SECTION 5: LIVE ANIMATION RUNNER
#  Asynchronous worker loop that handles runtime iteration frames.
## ------------------------------------------------------------------
@async while isopen(fig.scene)
    update_boids!(
        global_boids, 
        w_sep[], w_ali[], w_coh[], radius[], 
        false, 800.0, 600.0
    )
    
    positions.val = Point2f[(b.x, b.y) for b in global_boids]
    headings.val  = Float64[heading_hue(b.vx, b.vy) for b in global_boids]

    notify(positions)
    notify(headings)
    
    sleep(0.016)
end