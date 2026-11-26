# Counter-War — Stage 08: Operation Whiteout
## UI Design Rules

**Status:** Initial design reference rules  
**Scope:** Stage 08 UI only  
**Project:** `C:\Users\lenevo\Desktop\counter-war-game`

These rules govern the implementation of the approved Stage 08 UI reference images. The images are design references, not finished game screens.

## 1. Required reference assets

Keep the Stage 08 UI references in this folder structure:

```text
assets/
└── ui/
    └── stage08_whiteout/
        ├── stage08_ui_overview.png
        ├── screens/
        │   ├── briefing.png
        │   ├── loadout.png
        │   ├── gameplay_hud.png
        │   ├── pause.png
        │   ├── mission_success.png
        │   └── mission_failed.png
        └── UI_DESIGN_RULES.md
```

If a reference image has not been created or approved yet, do not invent it or claim it exists. Report the missing asset clearly.

## 2. Visual direction

- Use a realistic, modern military visual style suitable for a snowy, high-altitude operation.
- Maintain a consistent visual language across all Stage 08 screens: dark tactical panels, restrained blue/grey tones, readable light text, and limited red accents for danger or failure.
- Use clear hierarchy, aligned spacing, consistent button styles, and legible text.
- Avoid cartoon-like, playful, overly futuristic, or unrelated visual styles.
- Treat the overview board as a quick consistency reference. Use the relevant individual screen image as the primary reference whenever available.

## 3. Screen purposes

- `briefing.png`: operation briefing, mission context, objectives, and start action.
- `loadout.png`: available soldier equipment and weapons, but only options supported by the actual game.
- `gameplay_hud.png`: in-game HUD for health, ammunition, current objective, direction/compass, and progress, limited to data actually available in the game.
- `pause.png`: resume, controls/settings where supported, restart, and exit/leave mission.
- `mission_success.png`: completed objectives, actual score/results where available, and continue action.
- `mission_failed.png`: failure status/reason where known, retry, and exit/leave mission.

These are the initial planned screens. Before adding extra screens, inspect the existing Stage 08 flow and explain why the extra screen is needed.

## 4. Implementation requirements

- Build real, interactive Godot UI controls. Do **not** display a reference image as the entire screen and pretend the UI is implemented.
- Use the images to guide layout, proportions, colors, typography, spacing, panels, and button appearance.
- Connect buttons only to real, existing or explicitly approved game actions. Do not invent gameplay systems, statistics, weapons, or mission objectives.
- If a required action or data source does not exist, report it rather than creating unrelated systems.
- Reuse existing project UI components and conventions when appropriate, while keeping Stage 08 visually consistent with its approved references.
- Keep UI responsive to the project’s supported display resolutions and aspect ratios.

## 5. Mandatory workflow for the AI agent

Before each Stage 08 UI task:

1. Read this file.
2. Inspect only the relevant screen reference and the minimum necessary related files.
3. State the exact files/areas planned for change and the reason.
4. Make the smallest scoped change that meets the task.
5. Run relevant targeted checks and report actual results.
6. If visual verification is required, provide a screenshot or explain precisely why it could not be captured.

Do not repeatedly open the same mountain scene as a substitute for implementing or verifying the requested UI.

## 6. Safety and preservation rules

- Do not modify `scenes/stages/Stage08.tscn` or its gameplay scripts unless the user explicitly authorizes that specific change.
- Do not modify Stage 01–07, shared gameplay systems, player/enemy behavior, mission logic, or save/profile systems for a Stage 08 UI task unless the user explicitly approves the exact scope.
- Preserve all pre-existing Git changes and untracked files. Do not reset, revert, overwrite, or delete user work.
- Do not perform broad refactors or unrelated cleanup.
- Do not create Git commits or push changes unless the user explicitly asks.
- Do not overwrite an existing reference image or rules file without first reporting the conflict and getting approval.

## 7. Reporting

At the end of each task, report:
- Files created or changed.
- Which reference images were actually used.
- Tests/checks run and their real results.
- Any missing assets, blocked actions, or unverified behavior.

Never claim success, performance, or visual fidelity without evidence.

## 8. Change control

These rules remain in force for Stage 08 UI work unless the user explicitly changes them. If a request conflicts with preserving existing project content, stop and ask for approval before making that change.
