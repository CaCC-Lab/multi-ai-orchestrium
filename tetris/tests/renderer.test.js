import { describe, test, expect } from '@jest/globals';
import { Renderer } from '../src/renderer.js';
import { Game } from '../src/game.js';

describe('Renderer', () => {
  test('should create renderer instance', () => {
    const renderer = new Renderer();
    expect(renderer).toBeDefined();
  });

  test('should render board as string', () => {
    const game = new Game();
    const renderer = new Renderer();
    const output = renderer.renderBoard(game);

    expect(typeof output).toBe('string');
    expect(output.length).toBeGreaterThan(0);
  });

  test('should include score in rendered output', () => {
    const game = new Game();
    game.score = 1000;
    const renderer = new Renderer();
    const output = renderer.renderGame(game);

    expect(output).toContain('1000');
  });

  test('should include level in rendered output', () => {
    const game = new Game();
    game.level = 5;
    const renderer = new Renderer();
    const output = renderer.renderGame(game);

    expect(output).toContain('5');
  });

  test('should show game over message when game ends', () => {
    const game = new Game();
    game.isGameOver = true;
    const renderer = new Renderer();
    const output = renderer.renderGame(game);

    expect(output.toLowerCase()).toContain('game over');
  });

  test('should render current tetromino on board', () => {
    const game = new Game();
    const renderer = new Renderer();
    const output = renderer.renderBoard(game);

    expect(output).toBeTruthy();
  });

  test('should display controls help', () => {
    const renderer = new Renderer();
    const help = renderer.renderControls();

    expect(help).toContain('←');
    expect(help).toContain('→');
    expect(help).toContain('↓');
  });
});
