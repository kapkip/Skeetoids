# Skeetoids: A Boids-Based Vector Ecology Simulation

`Skeetoids` is a real-time, agent-based simulation built from scratch to explore how mosquitoes navigate space, track resources, and survive.

This project serves as a functional proof-of-concept and a sandbox for learning Julia, concurrent programming, and dynamic data visualization using `GLMakie`.

---

## The Core Concept
Traditional epidemiological models often look at populations as static. This framework is a dynamic approach that captures the emergent properties of vector populations by simulating individual biological feedback loops in a continuous spatial environment.

Instead of reinventing all the physics, the agents are built on a modified Boids flocking algorithm tweaked so that instead of just grouping together like birds, they act like more of a decentralized swarm reacting dynamically to their surroundings.

This framework couples a multi-agent system with localized resource grids to explore how micro-environmental factors, like breeding pools and host availability, influence vector distribution and foraging efficiency.

## Dynamic Behavioral States
The insects navigate the environment based on three shifting priorities:

:seeking_host – Foraging flight patterns driven by a random walk, searching for a blood meal.

:digesting – A post-feed rest phase governed by internal countdown timers.

:seeking_water – A survival mode triggered when internal hydration thresholds drop, overriding other behaviors and forcing flight vectors toward the nearest aquatic resource grid coordinates.

## Project Status & Next Steps

This repository is an active, work-in-progress. Because it doubles as a deep-dive learning environment for Julia, the codebase contains notes,  active debugging loops, and other messiness.

What's Working Now:
- A real-time, hardware-accelerated swarm rendering via `GLMakie`.

- An asynchronous pipeline (@async) that keeps the physics loops from locking up the graphics.

- A fully operational three-tier interactive behavioral state machine.

## Features Coming Soon (hopefully):
- CO2 Pathing: Implementing a dynamic chemical plume/gradient matrix so agents can actively track hosts via simulated carbon dioxide paths rather than just random luck.

- Parameter Calibration: Tuning behavioral and spatial parameters to reflect dynamics supported by the scientific literature.

- Geospatial Data Logic: Exploring how to format the grid so it can theoretically ingest standard raster data (like GeoTIFFs), focusing purely on the data architecture rather than mapping a specific, literal location.

- Publishing: Eventually deploying the simulation online (maybe using `bonito.jl`), making it easy for people to interact with the swarm in a browser without needing a local Julia setup. 
