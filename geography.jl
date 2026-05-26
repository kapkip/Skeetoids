using GLMakie

# Define static water nodes (breeding sites)
const WATER_NODES = [
    Point2f(200.0, 300.0),  # Node 1: Left-center
    Point2f(600.0, 450.0)   # Node 2: Top-right
]

# Helper function to overlay the water nodes onto the simulation axis
function render_water!(ax)
    scatter!(ax, WATER_NODES, markersize=25, color=:cyan, marker=:circle)
end