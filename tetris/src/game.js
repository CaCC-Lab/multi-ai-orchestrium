import { Board } from './board.js';
import { Tetromino } from './tetromino.js';

export class Game {
  constructor() {
    this.board = new Board();
    this.currentTetromino = null;
    this.nextTetromino = null;
    this.score = 0;
    this.level = 1;
    this.linesCleared = 0;
    this.isGameOver = false;

    this.spawnTetromino();
  }

  spawnTetromino() {
    const types = ['I', 'O', 'T', 'S', 'Z', 'J', 'L'];
    const randomType = types[Math.floor(Math.random() * types.length)];
    const tetromino = new Tetromino(randomType);

    if (this.board.isCollision(tetromino)) {
      this.isGameOver = true;
    }

    if (this.currentTetromino === null) {
      this.currentTetromino = tetromino;
    } else {
      this.currentTetromino = tetromino;
    }

    return tetromino;
  }

  moveDown() {
    this.currentTetromino.moveDown();

    if (this.board.isCollision(this.currentTetromino)) {
      this.currentTetromino.moveUp();
      this.lockTetromino();
      return false;
    }

    return true;
  }

  moveLeft() {
    this.currentTetromino.moveLeft();

    if (this.board.isCollision(this.currentTetromino)) {
      this.currentTetromino.moveRight();
      return false;
    }

    return true;
  }

  moveRight() {
    this.currentTetromino.moveRight();

    if (this.board.isCollision(this.currentTetromino)) {
      this.currentTetromino.moveLeft();
      return false;
    }

    return true;
  }

  rotate() {
    const originalShape = JSON.parse(JSON.stringify(this.currentTetromino.shape));
    this.currentTetromino.rotate();

    if (this.board.isCollision(this.currentTetromino)) {
      this.currentTetromino.shape = originalShape;
      return false;
    }

    return true;
  }

  hardDrop() {
    while (this.moveDown()) {
    }
  }

  lockTetromino() {
    this.board.merge(this.currentTetromino);
    this.clearLines();
    this.spawnTetromino();
  }

  clearLines() {
    const lines = this.board.clearLines();

    if (lines > 0) {
      this.linesCleared += lines;
      this.updateScore(lines);
      this.updateLevel();
    }

    return lines;
  }

  updateScore(linesCleared) {
    const points = {
      1: 100,
      2: 300,
      3: 500,
      4: 800,
    };

    this.score += (points[linesCleared] || 0) * this.level;
  }

  updateLevel() {
    this.level = Math.floor(this.linesCleared / 10) + 1;
  }

  checkGameOver() {
    if (this.board.isGameOver()) {
      this.isGameOver = true;
    }
  }

  reset() {
    this.board.reset();
    this.score = 0;
    this.level = 1;
    this.linesCleared = 0;
    this.isGameOver = false;
    this.spawnTetromino();
  }
}
