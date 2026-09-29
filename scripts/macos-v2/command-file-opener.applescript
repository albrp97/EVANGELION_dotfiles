on open openedFiles
  set helperPath to (POSIX path of (path to home folder)) & ".local/bin/rice-v2-open-command-file"
  repeat with openedFile in openedFiles
    set commandPath to POSIX path of openedFile
    do shell script quoted form of helperPath & " " & quoted form of commandPath
  end repeat
end open
