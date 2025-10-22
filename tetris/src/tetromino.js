export const SHAPES = {
  I: [
    [0, 0, 0, 0],
    [1, 1, 1, 1],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
  ],
  O: [
    [1, 1],
    [1, 1],
  ],
  T: [
    [0, 1, 0],
    [1, 1, 1],
    [0, 0, 0],
  ],
  S: [
    [0, 1, 1],
    [1, 1, 0],
    [0, 0, 0],
  ],
  Z: [
    [1, 1, 0],
    [0, 1, 1],
    [0, 0, 0],
  ],
  J: [
    [1, 0, 0],
    [1, 1, 1],
    [0, 0, 0],
  ],
  L: [
    [0, 0, 1],
    [1, 1, 1],
    [0, 0, 0],
  ],
};

const COLORS = {
  I: 'cyan',
  O: 'yellow',
  T: 'purple',
  S: 'green',
  Z: 'red',
  J: 'blue',
  L: 'orange',
};

export class Tetromino {
  constructor(type) {
    this.type = type;
    this.shape = JSON.parse(JSON.stringify(SHAPES[type]));
    this.color = COLORS[type];
    this.x = 3;
    this.y = 0;
  }

  rotate() {
    const newShape = [];
    const rows = this.shape.length;
    const cols = this.shape[0].length;

    for (let i = 0; i < cols; i++) {
      newShape[i] = [];
      for (let j = 0; j < rows; j++) {
        newShape[i][j] = this.shape[rows - 1 - j][i];
      }
    }

    this.shape = newShape;
  }

  moveDown() {
    this.y++;
  }

  moveUp() {
    this.y--;
  }

  moveLeft() {
    this.x--;
  }

  moveRight() {
    this.x++;
  }

  getBlocks() {
    const blocks = [];
    for (let y = 0; y < this.shape.length; y++) {
      for (let x = 0; x < this.shape[y].length; x++) {
        if (this.shape[y][x]) {
          blocks.push({ x: this.x + x, y: this.y + y });
        }
      }
    }
    return blocks;
  }
}
