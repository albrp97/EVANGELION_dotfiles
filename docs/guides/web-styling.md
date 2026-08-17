# Zen web styling guide

The rice separates Zen browser styling into three files:

| File | Purpose |
| --- | --- |
| `dotfiles/common/zen/userChrome.css` | Zen's tabs, toolbar, sidebar, URL bar, and browser chrome |
| `dotfiles/common/zen/userContent.css` | Website surfaces and controls selected with `@-moz-document` |
| `dotfiles/common/zen/user.js` | Zen preferences required for custom styles and the browser defaults |

These files are shared by macOS and Linux. The installer discovers the active
Zen profile and copies them into that profile. It also backs up the previous
CSS and `user.js` before replacing them.

## Supported website rules

The tracked content stylesheet currently has rules for:

- GitHub: transparent page surfaces, dark EVA controls, lavender links, green
  success states, orange attention states, and rose errors.
- Gmail: transparent dark surfaces, readable message text, EVA controls, and
  lavender links.
- YouTube: transparent page chrome, dark controls, readable secondary text,
  lavender calls to action, and green active icons.

There are two GitHub blocks because one handles the broad transparent layout
and another handles GitHub's color variables and controls. Keep both when
editing GitHub styling.

## Adding a website

Add a new block to `dotfiles/common/zen/userContent.css`:

```css
@-moz-document domain("example.com") {
  :root {
    color-scheme: dark !important;
  }

  body,
  main {
    background: transparent !important;
    color: #e0def4 !important;
  }

  a {
    color: #c4a7e7 !important;
  }
}
```

Prefer stable elements, CSS variables, and semantic selectors over generated
class names. Use the shared palette roles:

- `#0F1020` for the transparent-compatible base
- `#191724` and `#26233A` for surfaces and borders
- `#C4A7E7` for links and lavender structure
- `#A3D977` for success and active states
- `#F6C177` for warnings and attention
- `#D98BC4` for errors
- `#9A86B8` for muted text

Use `!important` only where the site's own stylesheet otherwise wins. Keep
website-specific overrides inside that site's `@-moz-document` block so they
do not leak into other pages.

## Applying changes

From the repository root, run:

```sh
scripts/configure-zen.sh
```

The script searches the standard profile roots on both operating systems:

- Linux: `~/.config/zen`, `~/.config/zen-browser`, and `~/.zen`
- macOS: `~/Library/Application Support/Zen/Profiles`

Close and reopen Zen after applying changes. A regular tab refresh is not
enough for `userChrome.css`; `userContent.css` changes may also require a
full browser restart when the site caches styles.

## Troubleshooting

1. Confirm that the script found the profile and that the files are in the
   profile's `chrome/` directory.
2. Check that `user.js` enabled
   `toolkit.legacyUserProfileCustomizations.stylesheets`.
3. Make sure Zen was fully closed before applying the files. A stale process
   can rewrite profile files on exit.
4. Use the browser inspector to identify the current site selector. Website
   markup changes can make an old selector stop matching.
5. If only one site is broken, temporarily comment out that site's block
   instead of changing the global browser chrome rules.

Third-party Sine mods and generated profile CSS are not tracked by this
repository. Leave them separate from the EVA layer; update the tracked files
when the shared rice appearance changes.
