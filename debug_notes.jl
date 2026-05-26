#=
Since VSCode debugger does not want to help:
Use @Infiltrate to help

    EXAMPLE
using Infiltrator

function update_biology!(boids, water_nodes, width, height)
    for b in boids
        if b.state == :seeking_water
            @infiltrate  # <- Simulation freezes right here!
        end
    end
end

When a bug triggers, the terminal transforms into custom sub-REPL
Type any local var (eg b, water_nodes) to see whats going on
step through the loops, exit when done, @async does not crash

ALSO OTHER REALLY IMPORTANT LOGGING MACROS:
@show: The fastest way to inspect variables without setting up anything. 
Dropping EXAMPLE @show b.state inside a function 
will print the var name and value to your terminal dynamically.

@info, @warn, @error: These are built-in smart logging utilities. 
You can use them to print cleanly formatted, color-coded messages 
that tell you exactly what function or line they came from:
    EXAMPLE
if b.state == :seeking_water && isempty(WATER_NODES)
    @warn "Boid is looking for water, but WATER_NODES is empty!" b.x b.y
end
this is really obnoxious, but I guess... get good.

Also:
Revise.jl is your friend, but takes some tooling to work dynamically
If sim is updating too fast, you cannot
    but.... if you pause your @async in console
        is_running = false
    then make edits and save
        is_running = true
    will restart the loop

How to tell if Revise successfully grabbed your changes:
        Info: Reevaluating update_boids! in Main
    should pop up in terminal


ALSO SINCE YOU'RE a NOOB:

function update_biology!(boids, water_nodes, width, height)  # 1. Opens Function
    for b in boids                                           # 2. Opens Loop
        if b.state == :seeking_host                          
            # ...
        elseif b.state == :digesting                         # 3. Opens State 2
            if b.timer > 600                                 # 4. Opens Timer Check
                if rand() < 0.1                              # 5. Opens Jitter Check
                    b.state = :seeking_water
                    b.timer = 0
                end                                          # 5. Closes Jitter
            end                                              # 4. Closes Timer (THIS WAS MISSING!)
        elseif b.state == :seeking_water                     
            # ...
        end                                                  # 3. Closes State Checks
    end                                                      # 2. Closes Loop
end                                                          # 1. Closes Function

Notice how if you actually FORMAT your code properly its a little easier
=#