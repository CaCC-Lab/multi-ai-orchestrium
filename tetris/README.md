# Tetris - TDD Implementation

A complete Tetris game implementation following Test-Driven Development (TDD) principles.

## Features

- **TDD Approach**: All core game logic developed using RED-GREEN-REFACTOR cycle
- **34 Unit Tests**: Comprehensive test coverage for game logic
- **Multiple Interfaces**:
  - Console-based gameplay (Node.js)
  - Browser-based gameplay (HTML5 Canvas)
- **Classic Tetris Mechanics**:
  - 7 standard Tetromino shapes (I, O, T, S, Z, J, L)
  - Collision detection
  - Line clearing
  - Score tracking
  - Level progression

## Project Structure

```
tetris/
├── src/
│   ├── tetromino.js    # Tetromino shapes and rotation logic
│   ├── board.js        # Game board and collision detection
│   ├── game.js         # Game state and control logic
│   ├── renderer.js     # Console rendering
│   └── index.js        # Main game loop (Node.js)
├── tests/
│   ├── tetromino.test.js
│   ├── board.test.js
│   ├── game.test.js
│   └── renderer.test.js
├── public/
│   └── index.html      # Browser-based game
└── package.json
```

## Installation

```bash
npm install
```

## Running Tests

```bash
# Run all tests
npm test

# Watch mode
npm run test:watch

# Coverage report
npm run test:coverage
```

## Playing the Game

### Console Version (Node.js)

```bash
npm start
```

**Controls:**
- `←` - Move left
- `→` - Move right
- `↓` - Soft drop
- `↑` - Rotate
- `Space` - Hard drop
- `P` - Pause/Resume
- `R` - Restart (when game over)
- `Q` - Quit
- `Ctrl+C` - Exit

### Browser Version

Open `public/index.html` in your web browser.

**Controls:**
- Arrow keys for movement and rotation
- `Space` - Hard drop
- `R` - Restart

## TDD Development Process

This project was developed following strict TDD methodology:

### Phase 1: Core Game Logic
1. **RED**: Write failing tests for Tetromino shapes
2. **GREEN**: Implement minimum code to pass tests
3. **REFACTOR**: Optimize shape representation

### Phase 2: Board & Collision
1. **RED**: Write tests for board initialization and collision detection
2. **GREEN**: Implement board grid and collision logic
3. **REFACTOR**: Extract collision detection methods

### Phase 3: Game Control
1. **RED**: Write tests for movement, rotation, line clearing
2. **GREEN**: Implement game state management
3. **REFACTOR**: Separate concerns (Game class)

### Phase 4: Rendering
1. **RED**: Write tests for console rendering
2. **GREEN**: Implement ASCII-based renderer
3. **REFACTOR**: Clean separation of game logic and rendering

## Test Coverage

```
Test Suites: 4 passed, 4 total
Tests:       34 passed, 34 total
```

Coverage areas:
- Tetromino shape definitions and rotations
- Board collision detection (boundaries and occupied cells)
- Game state management (score, level, game over)
- Line clearing mechanics
- Rendering output validation

## Game Mechanics

### Scoring System
- 1 line: 100 points × level
- 2 lines: 300 points × level
- 3 lines: 500 points × level
- 4 lines (Tetris): 800 points × level

### Level Progression
- Level increases every 10 lines cleared
- Game speed increases with each level

### Game Over Condition
- Game ends when a new Tetromino cannot be placed at the top of the board

## Technical Details

- **Language**: JavaScript (ES6 modules)
- **Test Framework**: Jest
- **Node.js Version**: 14+ (for `--experimental-vm-modules`)
- **Browser Support**: Modern browsers with Canvas API support

## Future Enhancements

Potential improvements (following TDD):
- [ ] Ghost piece (preview of drop location)
- [ ] Next piece preview
- [ ] Hold piece functionality
- [ ] Wall kicks for rotation
- [ ] Sound effects and music
- [ ] Persistent high scores
- [ ] Multiplayer mode

## License

ISC

## Development Notes

This implementation demonstrates:
- Pure TDD workflow (test-first development)
- Separation of concerns (MVC-like architecture)
- Modular design with ES6 modules
- Both console and browser interfaces from same core logic
- Comprehensive unit test coverage

Built as part of the Multi-AI Orchestrium TDD demonstration.
