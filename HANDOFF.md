# Convertra - Handoff Document

## UI Redesign Phase (Phase 5)
**Goal:** Transition to a 4-pane professional DJ interface architecture (Sidebar, Top/Center Library, Right Inspector, Bottom Persistent Player) using deep black and khaki gold aesthetics.

### Key UX Decisions
- Fully custom SwiftUI layout (no native macOS Sidebar, no standard Table styles).
- Visual stubs for uncompleted logic (Renamer, Duplicates, Genre Collections).
- Dark mode only, with full control over hover and selection states.

### Step 1: Foundation & Design System
- **Completed:** 
  - Created `Theme.swift` with colors (`bgPrimary`, `bgSecondary`, `goldAccent`), fonts, and layout constants.
  - Created base UI components (`GoldButtonStyle`, `GhostButtonStyle`, `SearchTextFieldStyle`).
  - Configured `WindowGroup` for custom styling (hidden titlebar, dark mode).
  - Integrated `Logo.png` into Resources.

### Step 2: Main Layout (4-pane skeleton) (In Progress)
- **Pending:**
  - Create MainLayoutView
  - Create custom SidebarView (Navigation & Collections stubs)
  - Create BottomPlayer placeholder
  - Wire layout in App
