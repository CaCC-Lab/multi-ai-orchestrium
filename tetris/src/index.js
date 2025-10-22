import { Game } from './game.js';
import { Renderer } from './renderer.js';
import readline from 'readline';

class TetrisApp {
  constructor() {
    this.game = new Game();
    this.renderer = new Renderer();
    this.gameLoop = null;
    this.speed = 1000;
    this.paused = false;

    readline.emitKeypressEvents(process.stdin);
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(true);
    }

    this.setupKeyboardInput();
  }

  setupKeyboardInput() {
    process.stdin.on('keypress', (str, key) => {
      if (key.ctrl && key.name === 'c') {
        this.quit();
      }

      if (this.game.isGameOver) {
        if (key.name === 'r') {
          this.restart();
        }
        return;
      }

      switch (key.name) {
        case 'left':
          this.game.moveLeft();
          this.render();
          break;
        case 'right':
          this.game.moveRight();
          this.render();
          break;
        case 'down':
          this.game.moveDown();
          this.render();
          break;
        case 'up':
          this.game.rotate();
          this.render();
          break;
        case 'space':
          this.game.hardDrop();
          this.render();
          break;
        case 'p':
          this.togglePause();
          break;
        case 'q':
          this.quit();
          break;
      }
    });
  }

  start() {
    this.render();
    this.gameLoop = setInterval(() => {
      if (!this.paused && !this.game.isGameOver) {
        this.game.moveDown();
        this.render();
      }

      if (this.game.isGameOver) {
        clearInterval(this.gameLoop);
        this.render();
        console.log('\nPress R to restart or Q to quit');
      }
    }, this.speed / this.game.level);
  }

  render() {
    this.renderer.render(this.game);
  }

  togglePause() {
    this.paused = !this.paused;
    this.render();
    if (this.paused) {
      console.log('\n⏸️  PAUSED - Press P to resume');
    }
  }

  restart() {
    if (this.gameLoop) {
      clearInterval(this.gameLoop);
    }
    this.game = new Game();
    this.start();
  }

  quit() {
    if (this.gameLoop) {
      clearInterval(this.gameLoop);
    }
    console.clear();
    console.log('\nThanks for playing Tetris!\n');
    process.exit(0);
  }
}

console.log('╔════════════════════════════╗');
console.log('║    Welcome to TETRIS!      ║');
console.log('╚════════════════════════════╝');
console.log('\nStarting game in 2 seconds...\n');

setTimeout(() => {
  const app = new TetrisApp();
  app.start();
}, 2000);
