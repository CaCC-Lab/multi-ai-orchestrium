import { describe, test, expect } from '@jest/globals';
import { Board } from '../src/board.js';
import { Tetromino } from '../src/tetromino.js';

describe('Board', () => {
  test('should create empty board with correct dimensions', () => {
    const board = new Board(10, 20);
    expect(board.width).toBe(10);
    expect(board.height).toBe(20);
    expect(board.grid.length).toBe(20);
    expect(board.grid[0].length).toBe(10);
  });

  test('should initialize all cells as empty', () => {
    const board = new Board(10, 20);
    for (let y = 0; y < board.height; y++) {
      for (let x = 0; x < board.width; x++) {
        expect(board.grid[y][x]).toBe(0);
      }
    }
  });

  test('should detect collision with bottom boundary', () => {
    const board = new Board(10, 20);
    const tetromino = new Tetromino('I');
    tetromino.y = 20;
    expect(board.isCollision(tetromino)).toBe(true);
  });

  test('should detect collision with left boundary', () => {
    const board = new Board(10, 20);
    const tetromino = new Tetromino('I');
    tetromino.x = -1;
    expect(board.isCollision(tetromino)).toBe(true);
  });

  test('should detect collision with right boundary', () => {
    const board = new Board(10, 20);
    const tetromino = new Tetromino('I');
    tetromino.x = 10;
    expect(board.isCollision(tetromino)).toBe(true);
  });

  test('should not detect collision for valid position', () => {
    const board = new Board(10, 20);
    const tetromino = new Tetromino('I');
    tetromino.x = 3;
    tetromino.y = 0;
    expect(board.isCollision(tetromino)).toBe(false);
  });

  test('should merge tetromino into board', () => {
    const board = new Board(10, 20);
    const tetromino = new Tetromino('O');
    tetromino.x = 4;
    tetromino.y = 18;

    board.merge(tetromino);

    const hasMergedCells = board.grid.some(row =>
      row.some(cell => cell !== 0)
    );
    expect(hasMergedCells).toBe(true);
  });

  test('should clear completed lines', () => {
    const board = new Board(10, 20);

    for (let x = 0; x < 10; x++) {
      board.grid[19][x] = 1;
    }

    const linesCleared = board.clearLines();
    expect(linesCleared).toBe(1);
    expect(board.grid[19].every(cell => cell === 0)).toBe(true);
  });

  test('should clear multiple completed lines', () => {
    const board = new Board(10, 20);

    for (let x = 0; x < 10; x++) {
      board.grid[19][x] = 1;
      board.grid[18][x] = 1;
      board.grid[17][x] = 1;
    }

    const linesCleared = board.clearLines();
    expect(linesCleared).toBe(3);
  });
});
