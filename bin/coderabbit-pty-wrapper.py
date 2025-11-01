#!/usr/bin/env python3
"""
CodeRabbit PTY Wrapper - TTY制約を回避するためのPTYエミュレーター
"""
import sys
import pty
import os
import subprocess

def run_with_pty(command):
    """PTY経由でコマンドを実行"""
    try:
        # PTYを作成してコマンドを実行
        master, slave = pty.openpty()

        # 子プロセスを起動
        process = subprocess.Popen(
            command,
            stdin=slave,
            stdout=slave,
            stderr=slave,
            close_fds=True
        )

        # slaveは子プロセスが使用するので閉じる
        os.close(slave)

        # masterから出力を読み取ってstdoutに書き込む
        try:
            while True:
                try:
                    data = os.read(master, 1024)
                    if not data:
                        break
                    os.write(sys.stdout.fileno(), data)
                except OSError:
                    break
        finally:
            os.close(master)

        # プロセスの終了を待つ
        return process.wait()

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: coderabbit-pty-wrapper.py <command> [args...]", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1:]
    exit_code = run_with_pty(command)
    sys.exit(exit_code)
