# EVA-01 Pastel Theme Preview

This Markdown file is for checking headings, lists, links, code blocks, quotes, emphasis, tables, and task markers in VS Code.

## Color priorities

1. **Purple** is the identity color for headings, focus, tabs, and key structure.
2. **Green** is reserved for action, success, functions, links, and live indicators.
3. **Orange** should stay rare: numbers, warnings, and details that need contrast.
4. `#0F1020` is the base surface behind the fake transparent editor background.

### Quick checklist

- [x] Headings should feel pastel purple, not neon.
- [x] Inline code like `scripts/apply-vscode-background.sh` should be readable.
- [ ] Links such as [Yazi](https://yazi-rs.github.io/) should stand out without screaming.
- [ ] Long prose should stay comfortable against the wallpaper-backed editor.

> The goal is not maximum contrast everywhere.
> The goal is a calm Linux-style desktop with EVA-01 identity.

| Surface | Opacity | Purpose |
| --- | ---: | --- |
| Editor wallpaper layer | 66% | Show the blurred wallpaper without hurting readability |
| Editor soft overlay | 56% | Let code areas feel less flat |
| Sidebar and panels | 90% | Avoid broken seams |
| Status bar | 100% | Keep the purple bottom accent stable |

```python
def activate_eva01(theme: str = "pastel") -> dict[str, str]:
    return {
        "background": "#0F1020",
        "focus": "#7C5FB8",
        "success": "#A3D977",
        "warning": "#F6C177",
    }
```

```json
{
  "theme": "EVA-01 Pastel",
  "fakeTransparency": true,
  "editorOpacity": 0.66
}
```

---

If anything feels off, check whether it is a **syntax token issue** or a **workbench surface issue**.
