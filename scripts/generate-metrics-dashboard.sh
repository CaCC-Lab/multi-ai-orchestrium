#!/usr/bin/env bash
# generate-metrics-dashboard.sh - メトリクスダッシュボード生成
# Phase 2.1.3実装

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# worktree-metrics.shのロード
if [[ -f "$SCRIPT_DIR/orchestrate/lib/worktree-metrics.sh" ]]; then
    source "$SCRIPT_DIR/orchestrate/lib/worktree-metrics.sh"
fi

OUTPUT_DIR="${PROJECT_ROOT}/logs/worktree-metrics"
OUTPUT_FILE="${OUTPUT_DIR}/dashboard.html"

# メトリクスデータを収集
echo "📊 Collecting metrics data..."
METRICS_JSON=$(generate_metrics_summary 7)

# メトリクスJSONファイルとして保存
METRICS_JSON_FILE="${OUTPUT_DIR}/metrics-data.json"
mkdir -p "$OUTPUT_DIR"
echo "$METRICS_JSON" > "$METRICS_JSON_FILE"

echo "🎨 Generating HTML dashboard..."

# HTMLダッシュボード生成（JSON読み込み方式）
cat > "$OUTPUT_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Worktree Metrics Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container { max-width: 1400px; margin: 0 auto; }
        
        header {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        h1 { color: #2d3748; font-size: 2.5em; margin-bottom: 10px; }
        .subtitle { color: #718096; font-size: 1.1em; }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .metric-card {
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        
        .metric-card:hover { transform: translateY(-5px); }
        
        .metric-title {
            color: #718096;
            font-size: 0.9em;
            font-weight: 600;
            text-transform: uppercase;
            margin-bottom: 10px;
        }
        
        .metric-value { color: #2d3748; font-size: 2.5em; font-weight: bold; }
        .metric-unit { color: #a0aec0; font-size: 0.9em; }
        
        .status {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: 600;
            margin-top: 10px;
        }
        
        .status-success { background: #c6f6d5; color: #22543d; }
        .status-warning { background: #feebc8; color: #7c2d12; }
        
        .trend-chart {
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        
        .trend-list { list-style: none; margin-top: 15px; }
        
        .trend-item {
            padding: 12px;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .trend-date { color: #4a5568; font-weight: 500; }
        
        .trend-bar {
            flex: 1;
            height: 8px;
            background: #e2e8f0;
            border-radius: 4px;
            margin: 0 15px;
            overflow: hidden;
        }
        
        .trend-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            border-radius: 4px;
        }
        
        .trend-percent { color: #2d3748; font-weight: 600; min-width: 50px; text-align: right; }
        
        footer {
            background: white;
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            color: #718096;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🚀 Worktree Metrics Dashboard</h1>
            <p class="subtitle">Git Worktrees統合システム - パフォーマンス & リソース監視</p>
        </header>
        
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-title">📁 Disk Usage</div>
                <div class="metric-value" id="disk-usage">-</div>
                <div class="metric-unit">MB</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-title">💾 Memory Usage</div>
                <div class="metric-value" id="memory-usage">-</div>
                <div class="metric-unit">%</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-title">⏱️ Avg Execution</div>
                <div class="metric-value" id="avg-execution">-</div>
                <div class="metric-unit">sec</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-title">✅ Success Rate</div>
                <div class="metric-value" id="success-rate">-</div>
                <div class="metric-unit">%</div>
                <span class="status status-success" id="status-badge">-</span>
            </div>
        </div>
        
        <div class="trend-chart">
            <h2 style="color: #2d3748; margin-bottom: 20px;">📈 Success Rate Trend (Last 7 Days)</h2>
            <ul class="trend-list" id="trend-list"></ul>
        </div>
        
        <footer>
            <p>Generated: <span id="generated-at">-</span></p>
            <p style="margin-top: 10px; font-size: 0.9em;">Multi-AI Orchestrium v3.0 | Phase 2.1.3</p>
        </footer>
    </div>
    
    <script>
        // JSONファイルからメトリクスを読み込み
        fetch('metrics-data.json')
            .then(response => response.json())
            .then(data => {
                // リソース使用量
                const diskMB = Math.round(data.current_resources.disk_usage_bytes / 1024 / 1024);
                document.getElementById('disk-usage').textContent = diskMB;
                
                const memPercent = Math.round(
                    (data.current_resources.memory_usage_kb / data.current_resources.memory_total_kb) * 100
                );
                document.getElementById('memory-usage').textContent = memPercent;
                
                // 平均実行時間
                const avgExec = data.workflow_metrics.multi_ai_full_orchestrate_avg_sec;
                document.getElementById('avg-execution').textContent = avgExec;
                
                // 成功率
                const latest = data.success_trend[data.success_trend.length - 1];
                const rate = latest ? latest.success_rate : 0;
                document.getElementById('success-rate').textContent = rate;
                
                const badge = document.getElementById('status-badge');
                if (rate >= 90) {
                    badge.textContent = 'Healthy';
                    badge.className = 'status status-success';
                } else {
                    badge.textContent = 'Warning';
                    badge.className = 'status status-warning';
                }
                
                // トレンドチャート
                const list = document.getElementById('trend-list');
                data.success_trend.forEach(item => {
                    const date = item.date;
                    const formatted = `${date.substring(0,4)}-${date.substring(4,6)}-${date.substring(6,8)}`;
                    
                    const li = document.createElement('li');
                    li.className = 'trend-item';
                    li.innerHTML = `
                        <span class="trend-date">${formatted}</span>
                        <div class="trend-bar"><div class="trend-bar-fill" style="width: ${item.success_rate}%"></div></div>
                        <span class="trend-percent">${item.success_rate}%</span>
                    `;
                    list.appendChild(li);
                });
                
                document.getElementById('generated-at').textContent = data.generated_at;
            })
            .catch(err => console.error('Failed to load metrics:', err));
    </script>
</body>
</html>
HTMLEOF

echo "✅ Dashboard generated: $OUTPUT_FILE"
echo "📊 Metrics data saved: $METRICS_JSON_FILE"
echo ""
echo "🌐 Open dashboard:"
echo "   file://$OUTPUT_FILE"
