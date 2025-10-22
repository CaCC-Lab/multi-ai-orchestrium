import { describe, test, expect, beforeEach } from '@jest/globals';
import { Game } from '../src/game.js';

describe('Game', () => {
  let game;

  beforeEach(() => {
    game = new Game();
  });

  test('should initialize with empty board and first tetromino', () => {
    expect(game.board).toBeDefined();
    expect(game.currentTetromino).toBeDefined();
    expect(game.score).toBe(0);
    expect(game.level).toBe(1);
    expect(game.isGameOver).toBe(false);
  });

  test('should move tetromino down', () => {
    const initialY = game.currentTetromino.y;
    game.moveDown();
    expect(game.currentTetromino.y).toBe(initialY + 1);
  });

  test('should move tetromino left', () => {
    const initialX = game.currentTetromino.x;
    game.moveLeft();
    expect(game.currentTetromino.x).toBe(initialX - 1);
  });

  test('should move tetromino right', () => {
    const initialX = game.currentTetromino.x;
    game.moveRight();
    expect(game.currentTetromino.x).toBe(initialX + 1);
  });

  test('should rotate tetromino', () => {
    const initialShape = JSON.stringify(game.currentTetromino.shape);
    game.rotate();
    const newShape = JSON.stringify(game.currentTetromino.shape);
    expect(newShape).not.toBe(initialShape);
  });

  test('should not move if collision detected', () => {
    game.currentTetromino.x = 0;
    const initialX = game.currentTetromino.x;
    game.moveLeft();
    expect(game.currentTetromino.x).toBe(initialX);
  });

  test('should lock tetromino and spawn new one when reaching bottom', () => {
    const firstType = game.currentTetromino.type;

    game.currentTetromino.y = 18;
    game.moveDown();

    const hasLockedPiece = game.board.grid.some(row =>
      row.some(cell => cell !== 0)
    );
    expect(hasLockedPiece).toBe(true);
  });

  test('should update score when clearing lines', () => {
    const initialScore = game.score;

    for (let x = 0; x < 10; x++) {
      game.board.grid[19][x] = 1;
    }

    game.clearLines();
    expect(game.score).toBeGreaterThan(initialScore);
  });

  test('should increase level after clearing 10 lines', () => {
    for (let i = 0; i < 10; i++) {
      for (let x = 0; x < 10; x++) {
        game.board.grid[19 - i][x] = 1;
      }
    }

    game.clearLines();
    expect(game.level).toBeGreaterThan(1);
  });

  test('should end game when tetromino cannot spawn', () => {
    for (let x = 0; x < 10; x++) {
      game.board.grid[0][x] = 1;
      game.board.grid[1][x] = 1;
    }

    game.checkGameOver();
    expect(game.isGameOver).toBe(true);
  });

  test('should generate random tetromino', () => {
    const tetrominoTypes = ['I', 'O', 'T', 'S', 'Z', 'J', 'L'];
    const newTetromino = game.spawnTetromino();
    expect(tetrominoTypes).toContain(newTetromino.type);
  });

  test('should hard drop tetromino to bottom', () => {
    game.hardDrop();

    const hasLockedPiece = game.board.grid.some(row =>
      row.some(cell => cell !== 0)
    );
    expect(hasLockedPiece).toBe(true);
  });
});
