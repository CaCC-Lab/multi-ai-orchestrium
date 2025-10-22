export class Board {
  constructor(width = 10, height = 20) {
    this.width = width;
    this.height = height;
    this.grid = this.createEmptyGrid();
  }

  createEmptyGrid() {
    const grid = [];
    for (let y = 0; y < this.height; y++) {
      grid[y] = [];
      for (let x = 0; x < this.width; x++) {
        grid[y][x] = 0;
      }
    }
    return grid;
  }

  isCollision(tetromino) {
    const blocks = tetromino.getBlocks();

    for (const block of blocks) {
      if (block.x < 0 || block.x >= this.width) {
        return true;
      }

      if (block.y < 0 || block.y >= this.height) {
        return true;
      }

      if (this.grid[block.y] && this.grid[block.y][block.x] !== 0) {
        return true;
      }
    }

    return false;
  }

  merge(tetromino) {
    const blocks = tetromino.getBlocks();

    for (const block of blocks) {
      if (block.y >= 0 && block.y < this.height && block.x >= 0 && block.x < this.width) {
        this.grid[block.y][block.x] = 1;
      }
    }
  }

  clearLines() {
    let linesCleared = 0;

    for (let y = this.height - 1; y >= 0; y--) {
      if (this.grid[y].every(cell => cell !== 0)) {
        this.grid.splice(y, 1);
        this.grid.unshift(new Array(this.width).fill(0));
        linesCleared++;
        y++;
      }
    }

    return linesCleared;
  }

  isGameOver() {
    return this.grid[0].some(cell => cell !== 0);
  }

  reset() {
    this.grid = this.createEmptyGrid();
  }
}
