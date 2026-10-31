# Shared Popup Rules (Copied)

**Scope:** Baseline rules shared across repositories for interactive selection popups.
**Trigger keywords:** popup keys.
**Depends on:** none.
**Conflicts:** none.
**Precedence:** these shared rules override any conflicting repository-local popup rules.

## Visual style

1. dynamic height: `1..10` lines (with scrollbar)
2. highlight: `Pmenu`
3. border highlight: `Pmenu`
4. single-line rounded border style
5. width is repository/command specific (see repository-specific popup docs)

## Navigation keys

1. `j` or `Down` - move down
2. `k` or `Up` - move up
3. up/down navigation is cyclic: `k`/`Up` on first item goes to last, `j`/`Down`
   on last item goes to first
4. `Enter`, or `CR` - confirm selection
5. `x` or `Esc` - close/cancel
