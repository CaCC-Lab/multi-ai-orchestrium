export class Renderer {
  constructor() {
    this.cellChar = '█';
    this.emptyChar = '·';
  }

  renderBoard(game) {
    const displayGrid = this.createDisplayGrid(game);
    let output = '';

    output += '┌' + '─'.repeat(game.board.width * 2) + '┐\n';

    for (let y = 0; y < game.board.height; y++) {
      output += '│';
      for (let x = 0; x < game.board.width; x++) {
        output += displayGrid[y][x] ? this.cellChar + ' ' : this.emptyChar + ' ';
      }
      output += '│\n';
    }

    output += '└' + '─'.repeat(game.board.width * 2) + '┘\n';

    return output;
  }

  createDisplayGrid(game) {
    const grid = game.board.grid.map(row => [...row]);

    if (game.currentTetromino) {
      const blocks = game.currentTetromino.getBlocks();
      for (const block of blocks) {
        if (block.y >= 0 && block.y < game.board.height &&
            block.x >= 0 && block.x < game.board.width) {
          grid[block.y][block.x] = 1;
        }
      }
    }

    return grid;
  }

  renderGame(game) {
    let output = '\n';

    output += '╔════════════════════════════╗\n';
    output += '║       TETRIS GAME          ║\n';
    output += '╚════════════════════════════╝\n\n';

    output += this.renderBoard(game);

    output += '\n';
    output += `Score: ${game.score}\n`;
    output += `Level: ${game.level}\n`;
    output += `Lines: ${game.linesCleared}\n`;

    if (game.isGameOver) {
      output += '\n';
      output += '╔════════════════════════════╗\n';
      output += '║        GAME OVER!          ║\n';
      output += '╚════════════════════════════╝\n';
    }

    return output;
  }

  renderControls() {
    return `
Controls:
  ←  Move Left
  →  Move Right
  ↓  Soft Drop
  ↑  Rotate
  Space  Hard Drop
  Q  Quit
`;
  }

  clear() {
    console.clear();
  }

  render(game) {
    this.clear();
    console.log(this.renderGame(game));
    console.log(this.renderControls());
  }
}
