# Build 184: the triangle, and the glass measured

From the review chat's split (16 November 2026, 12:39, approved by the owner): 184 = items 2 + 8 of
`tasks/QUEUE-next-build.md`:
- **Item 2: the triangle's turn**, the final spec the owner approved: `tapOutcome()`, the Window rule,
  `sameMeaningTurn`, the cases, Petals stops turning, tests 1–5.
- **Item 8: Measure the glass**, as the investigation: three levels behind the bar and the carried lens,
  in a table.

Prepared on a local branch after 183 was pushed; to be pushed only on the review chat's go ("Start
preparing 184 right after 183 is pushed, but don't push 184 until I say").

**The go** (review chat, 16 November 2026, 13:44), after both 183 reports:
- **The scope:** the triangle (`tapOutcome`), plus the glass measurement, plus the test-area part 2 if
  test-kit-only and small. The badge is set to build 184, today's date and the title, with
  `askedTest = 'button'`.
- **Not to fix in 184, but to find and write into the report:**
  1. The stand-in is never asked for, at any sampled stage, on either phone.
     - S25: window [787,917,220,220], box 8,56,330,745, overlap 33.2.
     - S26: [800,773,220,220], box 8,56,330,779, overlap 28.2.
  2. The S26's one missed tap ("ignoring yes"): one line on why.
  3. Confirm that the past-reports check's fixture never reaches the owner's list.
- **185, for planning:** under the glass, the stand-in fix, and the lens "always full quality" rule.

