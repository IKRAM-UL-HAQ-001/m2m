# AGENTS.md

## Mobile App Overview
This Flutter mobile application is the client for a real-time communication system.

Main focus:
- user-to-user messaging
- real-time chat experience
- notifications
- file sharing
- voice messages

## Tech Stack
- Flutter

## Core Principles
- Keep code simple, clean, and readable.
- Avoid unnecessary complexity.
- Follow existing coding style and structure.
- Maintain consistency for developer readability.
- Prefer practical and maintainable solutions.

## UI / UX Rules
- Do not change the current theme.
- Always use existing theme colors.
- Maintain the current design system.
- Ensure a professional and clean interface.
- Follow WhatsApp-like simplicity where appropriate, without changing branding.
- Do not disrupt existing user flows.

## Performance
- The app must remain smooth and responsive.
- Avoid lag, jank, and heavy UI rendering.
- Minimize unnecessary widget rebuilds.
- Optimize lists and chat screens.
- Keep rendering efficient.

## Stability
- Prevent memory leaks.
- Properly dispose controllers, streams, listeners, and timers.
- Avoid orphan background listeners.
- Ensure stable screen transitions.
- Avoid fragile or crash-prone logic.

## Code Style
- Follow existing naming conventions.
- Maintain current folder structure.
- Keep coding style consistent with the existing codebase.
- Avoid introducing new patterns unless necessary.
- Avoid excessive abstraction.
- Write small and clear functions.
- Create reusable widgets only when truly needed.

## Real-Time Behavior
- Ensure smooth chat updates.
- Maintain consistent UI updates for incoming messages.
- Keep real-time sync lightweight and stable.
- Follow existing notification handling patterns.

## Media / File / Voice
- Keep file sharing simple and reliable.
- Voice message handling should be basic and stable.
- Ensure smooth media interactions.
- Avoid heavy custom implementations.

## Explicit Restrictions
Do NOT implement or modify:
- calling UI
- audio/video call screens
- ringing flows
- call state management
- community features
- group features
- status features
- app-wide redesign
- theme color changes
- major navigation changes

If a task touches future features:
- acknowledge it
- do not implement it

## Optimization Rules
- Do not rewrite working code without reason.
- Apply incremental optimizations.
- Keep behavior unchanged while improving performance.
- Do not disrupt the current user experience.

## Working Style
- Identify relevant screens, widgets, services, and state flow first.
- Explain the issue briefly.
- Apply minimal safe changes.
- Avoid touching unrelated files.
- Avoid large refactors unless explicitly required.

## Communication Format
1. Short plan
2. Relevant files
3. Implementation / patch
4. Validation steps

## Validation
After changes:
- verify affected screens
- check rebuild behavior
- ensure proper disposal of resources
- confirm theme consistency
- confirm UX remains unchanged
- note performance impact

## Important Constraint
The mobile app is currently focused on delivering a stable, optimized messaging experience.

Do not introduce structures or UI for future features such as calling.