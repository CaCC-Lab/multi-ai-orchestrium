#!/usr/bin/env python3
"""
Eva Tetris テストスイート

Multi-AI Orchestrium統合テスト
Codexレビューの推奨事項に基づくテストケース
"""

import unittest
import sys
from unittest.mock import Mock, patch
import pygame

# eva_tetris.pyをインポート
sys.path.insert(0, '.')
from eva_tetris import TetrisGame, SHAPES, COLORS, GRID_WIDTH, GRID_HEIGHT


class TestTetrisGameInitialization(unittest.TestCase):
    """ゲーム初期化のテスト"""
    
    def setUp(self):
        """テスト前の準備"""
        pygame.init()
    
    def tearDown(self):
        """テスト後のクリーンアップ"""
        pygame.quit()
    
    def test_game_initialization(self):
        """ゲームが正しく初期化されるか"""
        game = TetrisGame()
        
        self.assertIsNotNone(game.board)
        self.assertEqual(len(game.board), GRID_HEIGHT)
        self.assertEqual(len(game.board[0]), GRID_WIDTH)
        self.assertEqual(game.score, 0)
        self.assertEqual(game.level, 1)
        self.assertEqual(game.lines_cleared, 0)
        self.assertFalse(game.game_over)
    
    def test_board_is_empty_on_start(self):
        """初期状態のボードが空か"""
        game = TetrisGame()
        
        for row in game.board:
            for cell in row:
                self.assertEqual(cell, 0)


class TestTetrisGameMechanics(unittest.TestCase):
    """ゲームメカニクスのテスト"""
    
    def setUp(self):
        pygame.init()
        self.game = TetrisGame()
    
    def tearDown(self):
        pygame.quit()
    
    def test_new_piece_generation(self):
        """新しいピースが正しく生成されるか"""
        piece = self.game.new_piece()
        
        self.assertIn('shape', piece)
        self.assertIn('color', piece)
        self.assertIn('x', piece)
        self.assertIn('y', piece)
        self.assertIn(piece['shape'], SHAPES)
        self.assertIn(piece['color'], COLORS)
    
    def test_piece_rotation(self):
        """ピースの回転が正しく動作するか"""
        # I字型テトリミノ（横棒）をテスト
        original = [[1, 1, 1, 1]]
        rotated = self.game.rotate_piece(original)
        
        # 90度回転で縦棒になる
        expected = [[1], [1], [1], [1]]
        self.assertEqual(rotated, expected)
    
    def test_collision_detection_boundary(self):
        """境界での衝突検出が正しく動作するか"""
        piece = self.game.new_piece()
        
        # 左端を超える移動
        piece['x'] = 0
        self.assertTrue(self.game.is_collision(piece, -1, 0))
        
        # 右端を超える移動
        piece['x'] = GRID_WIDTH - len(piece['shape'][0])
        self.assertTrue(self.game.is_collision(piece, 1, 0))
    
    def test_merge_piece(self):
        """ピースが正しくボードに固定されるか"""
        # シンプルな2x2ブロック（O字型）でテスト
        self.game.current_piece = {
            'shape': [[1, 1], [1, 1]],
            'color': COLORS[4],  # Yellow
            'x': 4,
            'y': 0
        }
        
        self.game.merge_piece()
        
        # ブロックが固定されていることを確認
        self.assertEqual(self.game.board[0][4], COLORS[4])
        self.assertEqual(self.game.board[0][5], COLORS[4])
        self.assertEqual(self.game.board[1][4], COLORS[4])
        self.assertEqual(self.game.board[1][5], COLORS[4])


class TestCodexRecommendations(unittest.TestCase):
    """Codexレビュー推奨事項のテスト"""
    
    def setUp(self):
        pygame.init()
        self.game = TetrisGame()
    
    def tearDown(self):
        pygame.quit()
    
    def test_hard_drop_does_not_overwrite_blocks(self):
        """
        Codex Critical Issue修正テスト:
        ハードドロップ時に既存のブロックを上書きしないか
        """
        # ボード下部に既存ブロックを配置
        for x in range(GRID_WIDTH):
            self.game.board[GRID_HEIGHT - 1][x] = COLORS[0]
        
        # 上部にピースを配置してハードドロップ
        self.game.current_piece = {
            'shape': [[1, 1], [1, 1]],
            'color': COLORS[4],
            'x': 4,
            'y': 0
        }
        
        original_bottom_row = self.game.board[GRID_HEIGHT - 1].copy()
        self.game.hard_drop()
        
        # 最下行が上書きされていないことを確認
        self.assertEqual(self.game.board[GRID_HEIGHT - 1], original_bottom_row)
    
    def test_level_affects_drop_speed(self):
        """
        Codex Major Issue修正テスト:
        レベル上昇時に落下速度が動的に変更されるか
        """
        # レベル1の速度
        level1_interval = self.game.get_drop_interval()
        self.assertEqual(level1_interval, 1000)
        
        # レベル5の速度
        self.game.level = 5
        level5_interval = self.game.get_drop_interval()
        self.assertEqual(level5_interval, 600)
        
        # レベル10の速度
        self.game.level = 10
        level10_interval = self.game.get_drop_interval()
        self.assertEqual(level10_interval, 100)  # 最小値
        
        # レベル20の速度（最小値を超えない）
        self.game.level = 20
        level20_interval = self.game.get_drop_interval()
        self.assertEqual(level20_interval, 100)
    
    def test_timer_reset_on_game_reset(self):
        """
        Codex Minor Issue修正テスト:
        ゲームリセット時にタイマーがリセットされるか
        """
        # タイマーを進める
        self.game.drop_time = 5000
        
        # ゲームリセット
        self.game.reset_game()
        
        # タイマーがリセットされていることを確認
        self.assertEqual(self.game.drop_time, 0)


class TestLineClearingAndScoring(unittest.TestCase):
    """ライン消去とスコアリングのテスト"""
    
    def setUp(self):
        pygame.init()
        self.game = TetrisGame()
    
    def tearDown(self):
        pygame.quit()
    
    def test_single_line_clear(self):
        """1ライン消去が正しく動作するか"""
        # 最下行を埋める
        for x in range(GRID_WIDTH):
            self.game.board[GRID_HEIGHT - 1][x] = COLORS[0]
        
        initial_score = self.game.score
        self.game.clear_lines()
        
        # ライン消去後のスコア確認
        self.assertEqual(self.game.lines_cleared, 1)
        self.assertEqual(self.game.score, initial_score + 100)
        
        # 最下行が空になっていることを確認
        for x in range(GRID_WIDTH):
            self.assertEqual(self.game.board[GRID_HEIGHT - 1][x], 0)
    
    def test_multiple_line_clear(self):
        """複数ライン消去が正しく動作するか"""
        # 最下4行を埋める
        for y in range(GRID_HEIGHT - 4, GRID_HEIGHT):
            for x in range(GRID_WIDTH):
                self.game.board[y][x] = COLORS[0]
        
        initial_score = self.game.score
        self.game.clear_lines()
        
        # テトリス（4ライン消去）のスコア確認
        self.assertEqual(self.game.lines_cleared, 4)
        self.assertEqual(self.game.score, initial_score + 800)
    
    def test_level_progression(self):
        """レベル進行が正しく動作するか"""
        self.assertEqual(self.game.level, 1)
        
        # 10ライン消去でレベル2に
        self.game.lines_cleared = 10
        self.game.clear_lines()
        self.assertEqual(self.game.level, 2)
        
        # 20ライン消去でレベル3に
        self.game.lines_cleared = 20
        self.game.clear_lines()
        self.assertEqual(self.game.level, 3)


class TestGameOverCondition(unittest.TestCase):
    """ゲームオーバー条件のテスト"""
    
    def setUp(self):
        pygame.init()
        self.game = TetrisGame()
    
    def tearDown(self):
        pygame.quit()
    
    def test_game_over_when_top_blocked(self):
        """最上段がブロックされた時にゲームオーバーになるか"""
        # 最上段をブロックで埋める
        for y in range(5):
            for x in range(GRID_WIDTH):
                self.game.board[y][x] = COLORS[0]
        
        # 新しいピースを生成してupdate
        self.game.current_piece = self.game.new_piece()
        
        # 衝突するまで下に移動
        while not self.game.is_collision(self.game.current_piece, 0, 1):
            self.game.current_piece['y'] += 1
        
        self.game.update()
        
        # ゲームオーバーになっているはず
        self.assertTrue(self.game.game_over)


def run_tests():
    """テストスイート実行"""
    # テストスイートを作成
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # すべてのテストクラスを追加
    suite.addTests(loader.loadTestsFromTestCase(TestTetrisGameInitialization))
    suite.addTests(loader.loadTestsFromTestCase(TestTetrisGameMechanics))
    suite.addTests(loader.loadTestsFromTestCase(TestCodexRecommendations))
    suite.addTests(loader.loadTestsFromTestCase(TestLineClearingAndScoring))
    suite.addTests(loader.loadTestsFromTestCase(TestGameOverCondition))
    
    # テスト実行
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # 結果サマリー
    print("\n" + "="*70)
    print("テスト結果サマリー")
    print("="*70)
    print(f"実行テスト数: {result.testsRun}")
    print(f"成功: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"失敗: {len(result.failures)}")
    print(f"エラー: {len(result.errors)}")
    print("="*70)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
