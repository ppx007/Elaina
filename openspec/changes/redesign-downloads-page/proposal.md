# Redesign Downloads Page

## Summary
Redesign the downloads page into a BT download management workspace. The page
must consume the existing BT task runtime through the download domain boundary
and expose task status, speeds, files, events, capabilities, and lifecycle
commands without importing concrete torrent engine APIs into UI.

## Motivation
The current downloads page is a card list with narrow task data and incomplete
task controls. It also advertises HTTP(S) torrent URL support that the concrete
runtime does not provide. Users need a dense, professional management surface
for magnet and local torrent tasks, including quick add, advanced file
selection, task details, and safe destructive actions.
