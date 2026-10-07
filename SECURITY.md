# Security policy

## Reporting a vulnerability

Please **don't open a public issue** for security problems.

Report it privately through GitHub instead:
<https://github.com/KevinTechLabs/Custom-Linux-Waybar/security/advisories/new>
(**Security → Report a vulnerability**). Include what you found, how to
reproduce it, and what an attacker could do with it. You'll get a reply within
a few days. Please allow up to 90 days for a fix before disclosing the issue
publicly.

If you spot something in this repository that looks like a real credential,
token, address or other private detail, please report it the same way.

## Supported versions

Only the latest commit on `main` is supported.

## What's already in place

- The installer runs as your user. Anything that needs root (installing packages, the optional RAPL power-reading rule in `system/`) is printed as a command for you to review and run yourself.
- The sidebar's **UPDATE** button opens a visible terminal and runs your normal system update (`paru`, `yay` or `sudo pacman -Syu`), so you see every command and are asked for your password as usual.
