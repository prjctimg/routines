#!/usr/bin/env fish


# Bail if not inside a Git repo
set repo_root (git rev-parse --show-toplevel 2>/dev/null)
if test -z "$repo_root"
    echo "Not inside a Git repository."
    exit 1
end

# Latest commit data
set commit_full (git rev-parse HEAD)
set commit (string sub -l 7 -- $commit_full)
set title (git log -1 --pretty=%s)
set message (git log -1 --pretty=%B)

# Commit timestamp (from the commit itself)
# Use single quotes to avoid fish interpreting % sequences
set year (git log -1 --date=format:'%Y'        --format=%cd)
set date (git log -1 --date=format:'%b %d %Y'  --format=%cd)
set month (git log -1 --date=format:'%B'        --format=%cd)

# Repo name inferred from parent dir containing .git
set cwd (basename -- "$repo_root")

# Final devlog path: $HOME/workspace/blog/data/blog/devlogs/$cwd/<year>.md
set devlog_dir "$HOME/workspace/blog/data/blog/devlogs/$cwd"
mkdir -p -- "$devlog_dir"
set logfile "$devlog_dir/$year.md"

# Helper: prepend frontmatter if missing
function ensure_frontmatter --argument-names file year date cwd
    set has_file (test -e "$file"; echo $status)
    set has_frontmatter 1
    if test $has_file -eq 0
        # Check if first line is '---'
        set first (head -n 1 "$file" 2>/dev/null)
        if string match -q -- --- "$first"
            set has_frontmatter 0
        end
    end

    if test $has_file -ne 0 -o $has_frontmatter -ne 0
        # Create temp file safely
        set tmpfile (mktemp -t devlog_frontmatter.XXXXXX)
        # Write frontmatter
        printf "%s\n" --- >>"$tmpfile"
        printf "title: %s\n" "$year" >>"$tmpfile"
        printf "date: %s\n" "$date" >>"$tmpfile"
        printf "imageUrl: /images/devlogs/$cwd/logo.jpg\n" >>"$tmpfile"
        printf "project: %s\n" "$cwd" >>"$tmpfile"
        printf "layout: post\n" >>"$tmpfile"
        printf "%s\n\n" --- >>"$tmpfile"

        # Append existing content if file exists
        if test $has_file -eq 0
            cat "$file" >>"$tmpfile"
        end

        mv "$tmpfile" "$file"
    end
end

# Ensure frontmatter exists
ensure_frontmatter "$logfile" "$year" "$date" "$cwd"

# Ensure the month section header exists (exact match)
if not grep -q "^## $month\$" "$logfile"
    printf "## %s\n\n" "$month" >>"$logfile"
end

# Emoji based on Conventional Commit type in the title
set emoji "📝"
if string match -r -q -- '^feat(\(|:| )' "$title"
    set emoji "✨"
else if string match -r -q -- '^(fix|bug)(\(|:| )' "$title"
    set emoji "🐛"
else if string match -r -q -- '^docs(\(|:| )' "$title"
    set emoji "📚"
else if string match -r -q -- '^refactor(\(|:| )' "$title"
    set emoji "🔨"
else if string match -r -q -- '^test(\(|:| )' "$title"
    set emoji "✅"
else if string match -r -q -- '^perf(\(|:| )' "$title"
    set emoji "⚡"
else if string match -r -q -- '^chore(\(|:| )' "$title"
    set emoji "🧹"
end

set url "https://github.com/prjctimg/$cwd/commit/$commit_full"

# Extract title and body from the full commit message
set lines (string split '\n' -- "$message")
if test (count $lines) -gt 1
    set body_lines $lines[2..]
    set formatted_message (string join '\n\n' $body_lines)
    set entry (printf "#### [%s](%s) - %s\n\n%s\n\n---\n\n" \
        "$commit" "$url" "$title" "$formatted_message")
else
    set entry (printf "#### [%s](%s) - %s\n\n---\n\n" \
        "$commit" "$url" "$title")
end
printf "%s\n" "$entry" >>"$logfile"

# Optionally copy to clipboard (best effort)
if type -q pbcopy
    printf "%s" "$entry" | pbcopy
else if type -q xclip
    printf "%s" "$entry" | xclip -selection clipboard
else if type -q clip
    printf "%s" "$entry" | clip
end

echo "Logged commit to $logfile"
