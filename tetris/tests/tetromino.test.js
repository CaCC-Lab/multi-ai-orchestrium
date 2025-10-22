import { describe, test, expect } from '@jest/globals';
import { Tetromino, SHAPES } from '../src/tetromino.js';

describe('Tetromino', () => {
  test('should create I-shape tetromino', () => {
    const tetromino = new Tetromino('I');
    expect(tetromino.shape).toBeDefined();
    expect(tetromino.shape).toEqual(SHAPES.I);
    expect(tetromino.color).toBe('cyan');
  });

  test('should create O-shape tetromino', () => {
    const tetromino = new Tetromino('O');
    expect(tetromino.shape).toEqual(SHAPES.O);
    expect(tetromino.color).toBe('yellow');
  });

  test('should create T-shape tetromino', () => {
    const tetromino = new Tetromino('T');
    expect(tetromino.shape).toEqual(SHAPES.T);
    expect(tetromino.color).toBe('purple');
  });

  test('should have initial position at top center', () => {
    const tetromino = new Tetromino('I');
    expect(tetromino.x).toBe(3);
    expect(tetromino.y).toBe(0);
  });

  test('should rotate I-shape tetromino clockwise', () => {
    const tetromino = new Tetromino('I');
    const originalShape = tetromino.shape;
    tetromino.rotate();
    expect(tetromino.shape).not.toEqual(originalShape);
    expect(tetromino.shape[0].length).toBe(originalShape.length);
  });

  test('should have correct dimensions for each shape', () => {
    expect(SHAPES.I.length).toBe(4);
    expect(SHAPES.O.length).toBe(2);
    expect(SHAPES.T.length).toBe(3);
    expect(SHAPES.S.length).toBe(3);
    expect(SHAPES.Z.length).toBe(3);
    expect(SHAPES.J.length).toBe(3);
    expect(SHAPES.L.length).toBe(3);
  });
});
