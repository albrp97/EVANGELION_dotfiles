# Window manager decision: AeroSpace vs yabai

## Original decision

Use **AeroSpace** for the first implementation.

Keep **yabai + skhd** documented as the advanced alternative if we later decide we need deeper scripting, native macOS Spaces manipulation, or yabai-specific layout features enough to accept more setup complexity and possible SIP tradeoffs.

## Why this matters

The goal is not just "tiling on macOS". The goal is a reproducible MacBook setup that feels close to Linux/Hyprland while being stable enough for daily development and safe enough to install on a new machine without immediately weakening macOS security.

That makes the first decision less about absolute power and more about the best starting point.

## Official docs comparison

### AeroSpace

Official claims and constraints:
- i3-like tiling window manager for macOS.
- Plain text config, dotfile-friendly.
- CLI-first.
- Own virtual workspace model instead of relying on native macOS Spaces.
- Fast workspace switching without macOS Spaces animations.
- Does **not** require disabling SIP.
- Proper multi-monitor support using an i3-like paradigm.
- Public beta: usable daily, but breaking changes are still possible before 1.0.
- Maintainer explicitly says ricing is not a core project value; AeroSpace mostly provides gaps and callbacks for bar integrations.

Implication for us:
- Very good match for keyboard-first workspaces, app bindings, and dotfiles.
- Safer starting point.
- We should not expect AeroSpace itself to provide Hyprland eye candy; we add visuals with SketchyBar and JankyBorders.

Sources:
- <https://github.com/nikitabobko/AeroSpace>
- <https://nikitabobko.github.io/AeroSpace/guide>
- <https://nikitabobko.github.io/AeroSpace/goodies>

### yabai

Official claims and constraints:
- Tiling window manager for macOS based on binary space partitioning.
- Very powerful CLI with domains for config, displays, spaces, windows, queries, rules, and signals.
- Integrates well with hotkey tools like skhd.
- Can control/query windows, spaces, and displays in a very scriptable way.
- Requires Accessibility permission.
- Screen Recording is required for window animations.
- Many advanced functions require the scripting addition, and the scripting addition requires partially disabling SIP.
- Examples of SIP-dependent capabilities include scripting-addition loading, creating/destroying/moving/swapping native Spaces, changing shadows/opacity, some layer/sticky/PiP behavior, and more robust advanced control.

Implication for us:
- Most powerful option if we want maximal macOS window/space scripting.
- Also the option with more security/setup friction.
- More attractive if we later want native Spaces manipulation or deeper automation than AeroSpace exposes.

Sources:
- <https://github.com/koekeishiya/yabai/wiki>
- <https://github.com/koekeishiya/yabai/blob/master/doc/yabai.asciidoc>
- <https://github.com/koekeishiya/skhd>

## Community / Reddit themes found

Reddit's modern pages often block direct fetching, so the accessible research came mainly from old Reddit search snippets and visible post excerpts. These are useful as community signals, not definitive measurements.

### Themes favoring AeroSpace

- People coming from Linux tiling WMs often try AeroSpace because it feels i3-like and gives keyboard-first workspace management without disabling SIP.
- A visible Reddit opinion says AeroSpace is better than yabai/Amethyst for users who do not want to weaken system security, specifically citing no SIP disable, fewer native Spaces issues because of virtual workspaces, less flickering, and useful heuristics for floating windows.
- A Linux/BSPWM user moving to Mac reported considering yabai first, then choosing AeroSpace because many people talked about it; their verdict was that AeroSpace is beta and not perfect, but it works.
- Community comparisons repeatedly mention AeroSpace as keyboard-first, powerful, and workspace-oriented.

### Themes favoring yabai

- yabai is repeatedly described as probably the most popular or classic macOS tiling option among power users.
- Reddit ricing guides and power-user setups commonly use yabai + skhd + SketchyBar.
- Users looking for scriptability often identify yabai as the strongest option, especially compared with more GUI-oriented tools.
- yabai has a larger body of existing configs, guides, and examples because it has been around longer.

### Concerns about AeroSpace

- It is newer and still public beta.
- Some users mention possible slowness or transition glitches.
- It has fewer advanced workflow examples than yabai.
- Some users find it keyboard-only and steep to learn.
- Its maintainer does not prioritize ricing/eye-candy features directly.

### Concerns about yabai

- Partial SIP disable is the recurring concern.
- Advanced native Spaces/window-server features are tied to the scripting addition.
- Setup is more fragile: Accessibility, optional Screen Recording, optional SIP changes, code signing considerations when building from source, and macOS settings caveats.
- Native macOS Spaces can be animated/quirky; some community posts complain about Spaces delay or about trying multiple tools because none feel perfectly smooth compared with Linux.

## Practical comparison for this project

| Criterion | AeroSpace | yabai + skhd |
| --- | --- | --- |
| Linux-like workspaces | Strong; virtual workspaces | Strong; native Spaces/control |
| SIP requirement | No SIP disable | Basic use can work, advanced features need partial SIP disable |
| Dotfile friendliness | High; TOML config | High; shell-style config + skhd config |
| Scripting power | Good CLI/callbacks | Excellent CLI/signals/rules |
| Community examples | Growing | Larger/more mature |
| Ricing visuals | Needs SketchyBar/JankyBorders | Often used with SketchyBar; some visuals may need SIP |
| Stability risk | Beta project risk | macOS/SIP/private API fragility risk |
| Setup complexity | Lower | Higher |
| Best fit | Safe first daily driver | Advanced power-user branch |

## Reasoned choice

For this MacBook setup, **AeroSpace is the better first choice** because:

1. The base workflow we want is keyboard-first tiling, workspaces, app launch bindings, focus/move/resize, and bar integration. AeroSpace covers that directly.
2. Avoiding SIP changes matters on a brand-new MacBook. We should not start by partially disabling a core macOS protection unless a specific workflow requires it.
3. AeroSpace's virtual workspaces avoid some native Spaces animation/ordering problems, which is useful for a Hyprland-like feel.
4. The missing "rice" parts can be handled outside the WM: SketchyBar for the bar, JankyBorders for active borders, Ghostty/Yazi/Starship/Nord for the terminal environment.
5. The setup will be easier to document, reproduce, and dotfile for a first version.

Why not choose yabai first:

1. Its biggest advantage is deeper scripting/native Spaces power, not something we need before the base rice exists.
2. The setup would immediately require deciding how far to go with SIP and scripting additions.
3. If we start with yabai, the project becomes more fragile and harder to replicate safely.

When to switch to yabai later:

- We need native macOS Spaces create/destroy/move/swap behavior.
- We need yabai signals/rules that AeroSpace cannot replicate.
- We decide partial SIP disable is acceptable.
- We want to follow an existing yabai + skhd + SketchyBar rice exactly.
- AeroSpace performance or beta limitations become a real blocker after testing.

## Final project stance

Start with:

```text
AeroSpace + Karabiner-Elements + SketchyBar + JankyBorders
```

Keep this fallback path documented:

```text
yabai + skhd + SketchyBar + JankyBorders
```

Do not delete the yabai option from the project. It remains the power-user alternative, but not the safest first implementation.

## Current migration update

The project has now migrated to:

```text
yabai + skhd + SketchyBar + JankyBorders
```

Reason:
- The current target explicitly wants yabai animation and scripting-addition capabilities.
- The first AeroSpace implementation proved the base rice, but yabai is now the power-user path.

Caveat:
- Basic yabai tiling and skhd hotkeys can run after macOS Accessibility permission is granted.
- Animation and scripting-addition features require partial SIP changes from Recovery. Those steps are documented in `docs/yabai-migration.md`.
