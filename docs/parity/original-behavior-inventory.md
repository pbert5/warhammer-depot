# Original Depot behavior inventory

Oracle: Depot `6d424fc55820d773bb20866a999750d9462f16e1` (the exact merge-base before the fork).
Candidate: Depot `8f9bc1c202dfd40103768ae15ea3768a3d811a1c`.

This is the source-archaeology inventory for parity recovery. Evidence paths are
relative to `vendor/depot/packages/web/`. `static-confirmed` means the behavior is
established from oracle source and existing test artifacts; it does not claim that
the detached oracle has been run. `runtime-pending` means detached-oracle runtime
validation is still required before the behavior becomes a valid parity contract.
The test layer named in the final column describes coverage or the intended check,
not a completed runtime result. No candidate-only behavior is listed as an oracle
requirement.

| ID | Area / route | User action and expected result | Persistence / navigation | Evidence (relative to `vendor/depot/packages/web/`) | Status / test layer |
|---|---|---|---|---|---|
| NAV-001 | Shell `/`, `/factions`, `/rosters`, `/collections`, `/settings` | Desktop rail and mobile bottom navigation expose Home, Rules, Armies, Settings; active section follows nested routes. | Drill-ins replace mobile nav with a back header; direct routes are reloadable. | `src/components/layout`, `src/routes.tsx` | static-confirmed; Playwright |
| NAV-002 | Shell drill-ins | Breadcrumbs show ancestors only; back destinations are route-defined. | Back is available on mobile drill-ins. | `src/components/layout`, `src/components/breadcrumbs` | static-confirmed; component + Playwright |
| HOME-001 | Home `/` | Empty bookmarks, rosters, and collections are omitted; hero remains visible. With data, recent roster/collection rows and bookmark cards appear. | Cards link to their detail routes; state is loaded from IndexedDB. | `src/routes/home`, `e2e/home.spec.ts` | static-confirmed; Playwright |
| RULES-001 | Factions `/factions` | Search filters factions and clear restores the complete list. | Search is transient and debounced. | `src/routes/factions` | static-confirmed; Playwright |
| FACTION-001 | Faction `/faction/:slug` | Datasheets and Detachments tabs, bookmark and share controls are visible; tab routes preserve faction context. | Datasheets is canonical; detachment tab uses replace navigation. | `src/routes/factions/[factionSlug]`, `e2e/faction.spec.ts` | static-confirmed; Playwright |
| DATASHEET-001 | Datasheet `/faction/:faction/datasheet/:sheet` | Profile displays stats, composition, wargear, abilities, and applicable leader rules. | Reload and hash return to the faction list are supported. | `src/routes/factions/[factionSlug]/datasheet` | static-confirmed; Playwright/component |
| DETACHMENT-001 | Detachment `/faction/:faction/detachment/:detachment` | Profile displays disposition/DP, abilities, enhancements, and stratagem sections. | Mobile back returns to the detachment list. | `src/routes/factions/[factionSlug]/detachment` | static-confirmed; Playwright |
| BOOKMARK-001 | Rules detail pages | Bookmark toggles create/remove a stable bookmark and show feedback. | Bookmark survives reload and appears newest-first on Home. | `src/utils/bookmarks`, `src/contexts/bookmarks` | static-confirmed; unit + Playwright gap |
| SHARE-001 | Rules detail pages | Native share is used when available; otherwise absolute route URL is copied and a success toast appears; rejected native share falls back. | No data mutation beyond user bookmark/share feedback. | `src/hooks/use-share`, `e2e/datasheet-share.spec.ts` | static-confirmed; Playwright |
| ROSTER-CREATE-001 | Roster library `/rosters` | Create requires a nonblank name, known faction, one detachment, and positive max points; default max is 2000. | New roster starts empty, persists, and navigates to `/rosters/:id/edit`. | `src/routes/rosters/_components/create-roster-sheet.tsx` | static-confirmed; Playwright |
| ROSTER-DETAILS-001 | Roster details `/rosters/:id/details` | Name, max points, faction detachment selection can be edited; changing faction during creation clears incompatible detachment. | Save returns to edit; invalid lists remain editable and show advisory issues. | `src/routes/rosters/[rosterId]/details`, `src/utils/roster-legality` | static-confirmed; Playwright |
| ROSTER-ADD-001 | Add Units `/rosters/:id/add-units` | Search a datasheet, add one selection, review it, confirm, and see one exact unit card in the roster. | Confirm routes to edit and persists across reload. | `src/routes/rosters/[rosterId]/add-units`, `e2e/roster-add-units.spec.ts` | static-confirmed; Playwright |
| ROSTER-ADD-002 | Add Units | Add two different datasheets across search changes; both remain queued and are confirmed together. | Queue is in-memory until confirmation. | `src/components/shared/add-units-view.tsx`, existing E2E | runtime-pending; Playwright |
| ROSTER-ADD-003 | Add Units | Add the same datasheet repeatedly; review quantity equals the number of clicks and each confirmed unit is present. | Cost bracket is corrected for ordinal unit count. | `src/hooks/use-roster-unit-selection.ts`, `src/contexts/roster/reducer.ts` | runtime-pending; Playwright |
| ROSTER-ADD-004 | Add Units | Review exposes grouped quantities; decrease removes only the latest matching unit, leaving other groups intact; zero cannot go below zero. | Close/reopen preserves queue; Clear empties and closes summary. | `src/components/shared/selection-summary.tsx` | runtime-pending; Playwright |
| ROSTER-ADD-005 | Add Units | Back/cancel abandons the transient queue without a prompt. | Returning to Add Units starts an empty queue. | `src/routes/rosters/[rosterId]/add-units` | static-confirmed; Playwright |
| ROSTER-ADD-006 | Add Units mobile | Review is a bottom sheet; essential multi-select flow works at 390px and 360px without horizontal overflow. | Confirm has the same roster result as desktop. | `src/components/shared/selection-summary.tsx`, Playwright projects | runtime-pending; Playwright |
| ROSTER-UNIT-001 | Roster edit | Unit card opens edit; Apply changes model cost, wargear, abilities, enhancement, and eligible character Warlord state. | Apply returns to edit with hash anchor; Cancel discards edits. | `src/routes/rosters/[rosterId]/units/[unitId]/edit` | static-confirmed; component + Playwright gap |
| ROSTER-UNIT-002 | Roster edit | Duplicate creates a new configured unit; remove immediately deletes a unit and dependent enhancement/Warlord assignment. | Changes persist after reload; no delete confirmation for unit removal. | `src/contexts/roster/reducer.ts` | static-confirmed; Playwright gap |
| COLLECTION-001 | Collections `/collections` | Create requires name/faction; collection begins empty at zero points and routes to detail. | Data persists through reload. | `src/routes/collections/_components/create-collection-sheet.tsx` | static-confirmed; Playwright |
| COLLECTION-002 | Collection Add Units | Each click queues an individual item; repeated items remain separate and default to Sprue. | Confirm persists all items and point total. | `src/routes/collections/[collectionId]/add-units` | static-confirmed; Playwright |
| COLLECTION-003 | Collection detail | State filter supports Sprue, Assembled, Battle Ready, Parade Ready; unit edit changes state/loadout/cost. | Filter persists in `depot:tag-selection:collection-state-filter`; edits reload. | `src/utils/collection`, `src/routes/collections/[collectionId]` | static-confirmed; Playwright gap |
| COLLECTION-004 | Collection lifecycle | Duplicate deep-copies collection and item IDs; delete uses native confirmation; item removal is immediate. | Source remains independent after duplicate. | collection route/components | static-confirmed; Playwright gap |
| COLLECTION-005 | Create roster from collection | Select owned collection copies up to available quantity; confirm creates new roster units while source remains unchanged. | Roster keeps a soft collection link; deleting source hides link but does not delete roster. | `src/routes/collections/[collectionId]/new-roster` | static-confirmed; Playwright gap |
| SETTINGS-001 | Settings `/settings` | Toggles for Legends, Forge World, fluff and sharing persist and affect consumers; theme persists and is applied before paint. | Settings/bookmarks/rosters survive catalog-cache clearing. | `src/constants/settings`, `src/utils/theme`, settings route | static-confirmed; component + Playwright |
| OFFLINE-001 | App lifecycle | Index/manifests/datasheets cache locally; network failure uses matching-version cache and shows recoverable error/offline UI. | Version change clears catalog cache only; saved user data remains. | `src/contexts/factions/index-sync.ts`, `src/data/offline-storage.ts` | static-confirmed; unit + Playwright gap |
| ERROR-001 | Unknown/failed routes | Unknown route shows 404 with Return home and Go back; failed loads show retry and back/home actions. | Retry performs reload; no destructive mutation. | `src/routes/not-found`, route components | static-confirmed; Playwright gap |
| INFO-001 | `/about`, `/privacy` | Informational and privacy pages render their content and remain navigable from shell links. | No special persistence. | `src/routes/about`, `src/routes/privacy` | static-confirmed; Playwright gap |

## Completion rules

Each `runtime-pending` row becomes a parity contract only after it passes against the
detached oracle. Candidate failures are regressions unless recorded in the explicit
override registry. Fork-only API persistence, autosave, backup JSON/YAML, migration,
catalogue URL/session state, category grouping, and enhanced search are intentionally
excluded from this original-behavior inventory.
