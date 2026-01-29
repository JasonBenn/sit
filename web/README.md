# Sit - Meditation Tracker Web Dashboard

Web dashboard for the Sit meditation and View tracking app.

## Tech Stack

- **Frontend**: React + Vite
- **Backend**: Convex
- **Testing**: Vitest

## Getting Started

### Prerequisites

- Node.js 18+
- pnpm

### Setup

1. Install dependencies:
```bash
pnpm install
```

2. Set up Convex:
```bash
npx convex dev
```

This will:
- Prompt you to log in to Convex
- Create a new Convex project
- Generate the `_generated` directory with TypeScript types
- Start the Convex dev server

### Development

```bash
# Run tests
pnpm test

# Run tests in watch mode
pnpm test:watch

# Start Convex dev server
npx convex dev
```

## Convex Schema

The backend includes the following tables:

### beliefs
- `text`: Limiting belief text
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

### timerPresets
- `durationMinutes`: Timer duration
- `label`: Optional label
- `order`: Display order
- `createdAt`: Timestamp

### promptSettings
- `promptsPerDay`: Number of daily prompts
- `wakingHourStart`: Start of waking hours (0-23)
- `wakingHourEnd`: End of waking hours (0-23)
- `updatedAt`: Timestamp

### meditationSessions
- `durationMinutes`: Session duration
- `startedAt`: Start timestamp
- `completedAt`: Completion timestamp
- `hasInnerTimers`: Whether inner timers were used
- Index: `by_completed_at`

### promptResponses
- `inTheView`: Boolean response to "In the View?" prompt
- `respondedAt`: Response timestamp
- Index: `by_responded_at`

## API

### Mutations

**Beliefs:**
- `createBelief({ text })`
- `updateBelief({ id, text })`
- `deleteBelief({ id })`

**Timer Presets:**
- `createTimerPreset({ durationMinutes, label? })`
- `deleteTimerPreset({ id })`

**Prompt Settings:**
- `updatePromptSettings({ promptsPerDay, wakingHourStart, wakingHourEnd })`

**Sessions:**
- `logMeditationSession({ durationMinutes, startedAt, completedAt, hasInnerTimers? })`
- `logPromptResponse({ inTheView, respondedAt })`

### Queries

- `listBeliefs()` - Returns all beliefs in descending order
- `listTimerPresets()` - Returns all presets in ascending order
- `getPromptSettings()` - Returns the current prompt settings
- `listMeditationSessions({ limit? })` - Returns sessions in descending order
- `listPromptResponses({ limit? })` - Returns responses in descending order

## Testing

The project includes schema validation tests. Full integration tests require a deployed Convex instance.

To run tests:
```bash
pnpm test
```

For manual testing of CRUD operations, use the Convex dashboard after running `npx convex dev`.
