#!/usr/bin/env python3
"""
Eva Tetris - Multi-AI協調テトリスゲーム実装
PM自己紹介: 私は高速プロトタイパーAmpです。37秒以内に実行可能なTetrisのプロトタイプを生成します。

このファイルは Multi-AI Orchestrium の協調プロセスによって生成されました:
- Claude: アーキテクチャ設計
- Gemini: 要件調査
- Amp: プロジェクト計画
- Qwen: 高速プロトタイプ実装
- Codex: レビュー & 最適化推奨
- Cursor (統合担当): Codex推奨事項の反映 + テスト追加
"""

import pygame
import random
import sys
from typing import List, Dict, Tuple

# 定数定義
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 700
GRID_SIZE = 30
GRID_WIDTH = 10
GRID_HEIGHT = 20
SIDEBAR_WIDTH = 200

# 色の定義
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GRAY = (128, 128, 128)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
CYAN = (0, 255, 255)
MAGENTA = (255, 0, 255)
YELLOW = (255, 255, 0)
ORANGE = (255, 165, 0)

# テトリミノの形状
SHAPES = [
    [[1, 1, 1, 1]],  # I
    [[1, 1, 1], [0, 1, 0]],  # T
    [[1, 1, 1], [1, 0, 0]],  # L
    [[1, 1, 1], [0, 0, 1]],  # J
    [[1, 1], [1, 1]],  # O
    [[0, 1, 1], [1, 1, 0]],  # S
    [[1, 1, 0], [0, 1, 1]]   # Z
]

# 色のリスト
COLORS = [CYAN, MAGENTA, ORANGE, BLUE, YELLOW, GREEN, RED]

class TetrisGame:
    """Tetrisゲームのメインクラス"""
    
    def __init__(self):
        """ゲームの初期化"""
        pygame.init()
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("Eva Tetris - Multi-AI協調テトリスゲーム")
        self.clock = pygame.time.Clock()
        self.font = pygame.font.SysFont(None, 36)
        self.small_font = pygame.font.SysFont(None, 24)
        
        self.reset_game()
        
    def reset_game(self):
        """ゲーム状態をリセット"""
        self.board = [[0 for _ in range(GRID_WIDTH)] for _ in range(GRID_HEIGHT)]
        self.current_piece = self.new_piece()
        self.next_piece = self.new_piece()
        self.game_over = False
        self.score = 0
        self.level = 1
        self.lines_cleared = 0
        self.drop_time = 0  # Codex推奨: タイマーリセット
        
    def new_piece(self) -> Dict:
        """新しいテトリミノを生成"""
        shape_idx = random.randint(0, len(SHAPES) - 1)
        return {
            'shape': SHAPES[shape_idx],
            'color': COLORS[shape_idx],
            'x': GRID_WIDTH // 2 - len(SHAPES[shape_idx][0]) // 2,
            'y': 0
        }
    
    def rotate_piece(self, shape: List[List[int]]) -> List[List[int]]:
        """ピースを回転（転置して各行を反転させることで90度回転）"""
        return [[shape[y][x] for y in range(len(shape)-1, -1, -1)] for x in range(len(shape[0]))]
    
    def is_collision(self, piece: Dict, x_offset: int = 0, y_offset: int = 0) -> bool:
        """衝突チェック"""
        shape = piece['shape']
        for y, row in enumerate(shape):
            for x, cell in enumerate(row):
                if cell:
                    pos_x, pos_y = piece['x'] + x + x_offset, piece['y'] + y + y_offset
                    if (pos_x < 0 or pos_x >= GRID_WIDTH or 
                        pos_y >= GRID_HEIGHT or 
                        (pos_y >= 0 and self.board[pos_y][pos_x])):
                        return True
        return False
    
    def merge_piece(self):
        """ピースをボードに固定"""
        for y, row in enumerate(self.current_piece['shape']):
            for x, cell in enumerate(row):
                if cell:
                    pos_x, pos_y = self.current_piece['x'] + x, self.current_piece['y'] + y
                    if 0 <= pos_y < GRID_HEIGHT and 0 <= pos_x < GRID_WIDTH:
                        self.board[pos_y][pos_x] = self.current_piece['color']
    
    def clear_lines(self):
        """揃ったラインを消去"""
        lines_to_clear = []
        for y in range(GRID_HEIGHT):
            if all(self.board[y]):
                lines_to_clear.append(y)
        
        for line in lines_to_clear:
            del self.board[line]
            self.board.insert(0, [0 for _ in range(GRID_WIDTH)])
        
        # スコア計算
        if lines_to_clear:
            self.lines_cleared += len(lines_to_clear)
            self.score += [100, 300, 500, 800][min(len(lines_to_clear)-1, 3)] * self.level
            self.level = self.lines_cleared // 10 + 1
    
    def get_drop_interval(self) -> int:
        """Codex推奨: レベルに応じた落下速度を動的に計算"""
        return max(100, 1000 - (self.level - 1) * 100)
    
    def draw_board(self):
        """ボードを描画"""
        # メインゲームエリア
        game_area = pygame.Rect(
            (SCREEN_WIDTH - SIDEBAR_WIDTH) // 2 - (GRID_SIZE * GRID_WIDTH) // 2,
            50,
            GRID_SIZE * GRID_WIDTH,
            GRID_SIZE * GRID_HEIGHT
        )
        
        # ゲームボードの背景
        pygame.draw.rect(self.screen, GRAY, game_area)
        pygame.draw.rect(self.screen, WHITE, game_area, 2)
        
        # 固定されたブロックを描画
        for y in range(GRID_HEIGHT):
            for x in range(GRID_WIDTH):
                if self.board[y][x]:
                    rect = pygame.Rect(
                        game_area.left + x * GRID_SIZE,
                        game_area.top + y * GRID_SIZE,
                        GRID_SIZE - 1, GRID_SIZE - 1
                    )
                    pygame.draw.rect(self.screen, self.board[y][x], rect)
                    pygame.draw.rect(self.screen, WHITE, rect, 1)
        
        # 現在のピースを描画
        if not self.game_over:
            for y, row in enumerate(self.current_piece['shape']):
                for x, cell in enumerate(row):
                    if cell:
                        rect = pygame.Rect(
                            game_area.left + (self.current_piece['x'] + x) * GRID_SIZE,
                            game_area.top + (self.current_piece['y'] + y) * GRID_SIZE,
                            GRID_SIZE - 1, GRID_SIZE - 1
                        )
                        pygame.draw.rect(self.screen, self.current_piece['color'], rect)
                        pygame.draw.rect(self.screen, WHITE, rect, 1)
    
    def draw_sidebar(self):
        """サイドバーを描画"""
        sidebar = pygame.Rect(
            (SCREEN_WIDTH - SIDEBAR_WIDTH) // 2 + (GRID_SIZE * GRID_WIDTH) // 2 + 20,
            50,
            SIDEBAR_WIDTH - 20, GRID_HEIGHT * GRID_SIZE
        )
        
        # サイドバーの背景
        pygame.draw.rect(self.screen, (50, 50, 50), sidebar)
        pygame.draw.rect(self.screen, WHITE, sidebar, 2)
        
        # 次のピースを表示
        next_text = self.font.render("Next:", True, WHITE)
        self.screen.blit(next_text, (sidebar.left + 10, sidebar.top + 20))
        
        # 次のピースを描画
        for y, row in enumerate(self.next_piece['shape']):
            for x, cell in enumerate(row):
                if cell:
                    rect = pygame.Rect(
                        sidebar.left + 40 + x * GRID_SIZE,
                        sidebar.top + 70 + y * GRID_SIZE,
                        GRID_SIZE - 1, GRID_SIZE - 1
                    )
                    pygame.draw.rect(self.screen, self.next_piece['color'], rect)
                    pygame.draw.rect(self.screen, WHITE, rect, 1)
        
        # スコア情報を表示
        score_text = self.small_font.render(f"Score: {self.score}", True, WHITE)
        level_text = self.small_font.render(f"Level: {self.level}", True, WHITE)
        lines_text = self.small_font.render(f"Lines: {self.lines_cleared}", True, WHITE)
        
        self.screen.blit(score_text, (sidebar.left + 10, sidebar.top + 150))
        self.screen.blit(level_text, (sidebar.left + 10, sidebar.top + 180))
        self.screen.blit(lines_text, (sidebar.left + 10, sidebar.top + 210))
        
        # 操作説明
        controls = [
            "Controls:",
            "← → : Move",
            "↑ : Rotate",
            "↓ : Soft Drop",
            "Space : Hard Drop",
            "R : Restart",
            "Q : Quit"
        ]
        
        for i, text in enumerate(controls):
            ctrl_text = self.small_font.render(text, True, WHITE)
            self.screen.blit(ctrl_text, (sidebar.left + 10, sidebar.top + 280 + i * 25))
        
        # AI協調情報
        ai_info = [
            "Multi-AI Team:",
            "PM: Amp",
            "Architect: Claude",
            "Research: Gemini",
            "Proto: Qwen",
            "Review: Codex",
            "Integration: Cursor"
        ]
        
        for i, text in enumerate(ai_info):
            color = YELLOW if i == 0 else WHITE
            ai_text = self.small_font.render(text, True, color)
            self.screen.blit(ai_text, (sidebar.left + 10, sidebar.top + 460 + i * 22))
    
    def draw_game_over(self):
        """ゲームオーバー表示"""
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))
        
        game_over_text = self.font.render("GAME OVER", True, RED)
        restart_text = self.small_font.render("Press R to Restart", True, WHITE)
        
        game_over_rect = game_over_text.get_rect(center=(SCREEN_WIDTH//2, SCREEN_HEIGHT//2))
        restart_rect = restart_text.get_rect(center=(SCREEN_WIDTH//2, SCREEN_HEIGHT//2 + 50))
        
        self.screen.blit(game_over_text, game_over_rect)
        self.screen.blit(restart_text, restart_rect)
    
    def update(self):
        """ゲーム状態を更新"""
        if self.game_over:
            return
            
        # ピースを下に移動
        if not self.is_collision(self.current_piece, 0, 1):
            self.current_piece['y'] += 1
        else:
            # ピースを固定して新しいピースを生成
            self.merge_piece()
            self.clear_lines()
            
            self.current_piece = self.next_piece
            self.next_piece = self.new_piece()
            
            # 新しいピースの位置に衝突があればゲームオーバー
            if self.is_collision(self.current_piece):
                self.game_over = True
    
    def move(self, dx: int):
        """ピースを横に移動"""
        if not self.is_collision(self.current_piece, dx, 0):
            self.current_piece['x'] += dx
    
    def rotate(self):
        """ピースを回転"""
        original_shape = self.current_piece['shape']
        self.current_piece['shape'] = self.rotate_piece(original_shape)
        if self.is_collision(self.current_piece):
            self.current_piece['shape'] = original_shape
    
    def hard_drop(self):
        """
        Codex推奨修正: ハードドロップ時のブロック上書きバグ修正
        
        元のバグ: 衝突するまで移動した後、そのままupdate()を呼ぶと
        ピースがスタックに重なった状態でmerge_piece()が実行され、
        既存のブロックを上書きしてしまう。
        
        修正: 衝突する直前（1行上）で停止してからupdate()を呼ぶ。
        """
        # 衝突するまで下に移動
        while not self.is_collision(self.current_piece, 0, 1):
            self.current_piece['y'] += 1
        # この時点でcurrent_piece['y']は「次に移動すると衝突する」位置
        # つまり正しい着地位置なので、そのままupdate()を呼んでOK
        self.update()
    
    def run(self):
        """ゲームループ"""
        self.drop_time = 0  # Codex推奨: 明示的な初期化
        
        while True:
            dt = self.clock.tick(60)
            self.drop_time += dt
            
            # Codex推奨: 動的な落下速度計算
            drop_interval = self.get_drop_interval()
            
            # イベント処理
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_q:
                        pygame.quit()
                        sys.exit()
                    
                    if self.game_over and event.key == pygame.K_r:
                        self.reset_game()
                        self.drop_time = 0  # Codex推奨: リセット時のタイマークリア
                    
                    if not self.game_over:
                        if event.key == pygame.K_LEFT:
                            self.move(-1)
                        elif event.key == pygame.K_RIGHT:
                            self.move(1)
                        elif event.key == pygame.K_DOWN:
                            if not self.is_collision(self.current_piece, 0, 1):
                                self.current_piece['y'] += 1
                        elif event.key == pygame.K_UP:
                            self.rotate()
                        elif event.key == pygame.K_SPACE:
                            self.hard_drop()
                            self.drop_time = 0  # Codex推奨: ハードドロップ後のタイマーリセット
                        elif event.key == pygame.K_r and not self.game_over:
                            self.reset_game()
                            self.drop_time = 0
            
            # ピースの自動落下
            if not self.game_over and self.drop_time > drop_interval:
                self.drop_time = 0
                self.update()
            
            # 画面描画
            self.screen.fill(BLACK)
            
            # タイトル
            title = self.font.render("Eva Tetris", True, CYAN)
            self.screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 10))
            
            self.draw_board()
            self.draw_sidebar()
            
            if self.game_over:
                self.draw_game_over()
            
            pygame.display.flip()

def main():
    """メイン関数"""
    try:
        game = TetrisGame()
        game.run()
    except KeyboardInterrupt:
        print("\nGame interrupted by user.")
        pygame.quit()
        sys.exit()
    except Exception as e:
        print(f"An error occurred: {e}")
        pygame.quit()
        sys.exit()

if __name__ == "__main__":
    main()
