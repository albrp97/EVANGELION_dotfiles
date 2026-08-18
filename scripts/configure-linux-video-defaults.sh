#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux video defaults require Linux." >&2
  exit 1
fi

if ! command -v xdg-mime >/dev/null 2>&1; then
  echo "xdg-mime is required to configure video defaults." >&2
  exit 1
fi

desktop_id="smplayer.desktop"
if [[ ! -f "/usr/share/applications/$desktop_id" ]]; then
  echo "SMPlayer desktop entry not found: /usr/share/applications/$desktop_id" >&2
  exit 1
fi

video_mimes=(
  video/3gpp
  video/3gpp2
  video/avi
  video/flv
  video/mp2t
  video/mp4
  video/mpeg
  video/ogg
  video/quicktime
  video/vnd.rn-realvideo
  video/webm
  video/x-f4v
  video/x-flv
  video/x-m4v
  video/x-matroska
  video/x-ms-asf
  video/x-msvideo
  video/x-ms-wmv
  video/x-ogm
  video/x-ogm+ogg
  video/x-theora
)

for mime in "${video_mimes[@]}"; do
  xdg-mime default "$desktop_id" "$mime"
done

echo "SMPlayer is now the default application for common video MIME types."
