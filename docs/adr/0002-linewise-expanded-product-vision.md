# ADR 2: Use LineWise as the Working Product Frame

Date: 2026-06-30

## Decision

The climbing product will use **LineWise** as the working English product name and **线感** as the working Chinese product name, while keeping **Gym Visit Memory** as the P0 scope.

LineWise can eventually include AI route reading, stick-figure movement visualization, routesetter-lens analysis, teaching/training, and climbing partner workflows. P0 does not attempt to ship all of these. It first proves the route/project memory loop and collects the personal climbing dataset needed for later AI and training features.

## Context

The product direction expanded beyond Watch-based attempt/rest tracking. The user wants the product to cover climbing buddy behavior, automatic route reading from photos, playful stick-figure interaction, routesetter-style analysis, and teaching/training. The earlier generic companion-name direction was understandable but too broad. `LineWise` is more specific to indoor bouldering because it points to reading lines, interpreting movement, and making smarter training decisions.

## Consequences

- `LineWise` becomes the English name used in product docs unless later changed.
- `线感` becomes the Chinese working name unless later changed.
- `Gym Visit Memory` remains the P0 mechanism, not the public brand.
- Future modules should be named explicitly: `RouteRead`, `StickFigureCue`, `SetterLens`, `TrainingPath`, and `ClimbingBuddy`.
- AI route reading and training features require a clean `PersonalClimbingDataset` before implementation promises.
- Partner/social workflows stay out of P0 until privacy, retention, and trust are validated.
