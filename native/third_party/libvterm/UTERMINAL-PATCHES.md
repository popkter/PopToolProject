# Local terminal metadata extension

This vendored copy is statically compiled into UTerminal. The appended callbacks are local source API extensions; do not exchange callback structs with binaries built against an unmodified header.

- `VTermStateCallbacks.prescroll` observes a scroll before state line metadata is moved.
- `VTermScreenCallbacks.sb_pushline_info` and `sb_popline_info` preserve `VTermLineInfo` alongside scrollback cells. Legacy callbacks remain supported when the extended callbacks are absent.
- Normal scrolling captures rows before their continuation flags are overwritten. Resize passes the old row metadata on push and restores it on backfill.
- Reflow stops its backward scan at visible row zero when a logical line starts in history, preventing a negative buffer index. The first visible row retains its continuation flag after reflow.

UTerminal uses the continuation flag to distinguish visual wrapping from explicit newlines for selection copying and search. Runtime tests cover screen rows, history, width changes, height backfill, explicit spaces, and wide characters at the right margin.
