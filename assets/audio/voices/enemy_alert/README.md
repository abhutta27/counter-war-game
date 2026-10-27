Add short, legally usable human voice clips to this folder.

Supported formats: `.wav`, `.ogg`, `.mp3`

Suggested lines: “Hey, you!”, “Contact!”, “There he is!”, “Enemy spotted!”

The game automatically discovers every supported clip in this folder. It plays
one from the detecting Enemy's `AudioStreamPlayer3D`, avoids immediately
repeating the same clip when alternatives exist, and applies a shared 2.5-second
cooldown across all Enemies.
