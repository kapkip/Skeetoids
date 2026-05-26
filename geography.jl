# geography.jl

using GLMakie

# 1. Define a struct to track the pools
mutable struct BreedingSite
    pos::Point2f
    count::Int
    capacity::Int
end

# 2. Update your global nodes
const WATER_NODES = [
    BreedingSite(Point2f(300.0, 800.0), 0, 150),
    BreedingSite(Point2f(1300.0, 400.0), 0, 150),
    BreedingSite(Point2f(800.0, 600.0), 0, 150)
]

# 3. Update your helper function to handle the struct
function render_water!(ax)
    # Extract just the positions for scatter!
    positions = [node.pos for node in WATER_NODES]
    scatter!(ax, positions, markersize=35, color=:cyan, marker=:circle)
end