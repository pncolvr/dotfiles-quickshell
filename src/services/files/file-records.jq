# Shared identity fields for an absolute local path. Callers own source metadata.
def file_record:
    . as $path | split("/") as $parts |
    {path: $path, name: $parts[-1],
     directory: ($parts[:-1] | join("/") | if . == "" then "/" else . end),
     uri: ("file://" + ($parts | map(@uri) | join("/")))};
