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

### Step 2: Main Layout (4-pane skeleton)
- **Completed:**
  - Created `MainLayoutView` skeleton with 4 zones.
  - Created custom `SidebarView` and integrated the provided `Logo.png`.
  - Replaced standard `NavigationView` in `ContentView` with `MainLayoutView`.
  - Created visual stubs for Collections and Navigation links.

### Step 3: Central Zone (Header & Library)
- **Completed:**
  - Created `TopHeaderView` with Drop Zone and primary action buttons.
  - Created `LibraryToolbarView` with visual stubs for view modes, filters, and a functional search bar.
  - Rebuilt `TrackListView` replacing the standard `List` with a `LazyVStack` to support deep custom styling (hover, select, colors) and columns.

### Step 4: Right Inspector Panel
- **Completed:**
  - Created `InspectorView` with interactive tabs (Info, Metadata, Artwork).
  - Implemented the audio parameters tech grid in the Info tab.
  - Re-wired the existing `MetadataEditDraft` logic to a sleek right-aligned custom form in the Metadata tab.

### Step 5: Player & Conversion Status (In Progress)
- **Pending:**
  - Create persistent `BottomPlayerView`.
  - Tie `AudioPlayerEngine` states to play/pause controls and waveform seekbar.
  - Implement Conversion queue progress widget in the bottom right corner.
