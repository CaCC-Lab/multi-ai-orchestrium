# Security Rules Reference - Claude Security Review

**Version**: 1.0.0
**Last Updated**: 2025-10-25
**Status**: Complete
**OWASP Version**: Top 10 2021
**CWE Version**: 4.13

## 目次

1. [概要](#概要)
2. [OWASP Top 10 2021マッピング](#owasp-top-10-2021マッピング)
3. [CWE IDリファレンス](#cwe-idリファレンス)
4. [カスタムルール定義](#カスタムルール定義)
5. [CVSS v3.1スコアリング](#cvss-v31スコアリング)
6. [セキュリティテスト戦略](#セキュリティテスト戦略)
7. [修復ガイドライン](#修復ガイドライン)

---

## 概要

Claude Security Reviewは、OWASP Top 10とCWE（Common Weakness Enumeration）に基づくセキュリティ脆弱性を検出します。このドキュメントは、すべてのセキュリティルールの詳細仕様とカスタマイズ方法を提供します。

### サポートされる脆弱性タイプ

| カテゴリ | 脆弱性数 | CVSS範囲 | 検出方法 |
|---------|---------|---------|---------|
| **インジェクション** | 3 | 6.1 - 9.8 | パターンマッチング + AI分析 |
| **暗号化の失敗** | 2 | 7.5 - 9.8 | パターンマッチング |
| **アクセス制御** | 1 | 7.5 | パターンマッチング |
| **データ整合性** | 1 | 9.8 | パターンマッチング |

**合計**: 7つのコアルール + 拡張可能なカスタムルール

---

## OWASP Top 10 2021マッピング

### A01:2021 - Broken Access Control

#### CWE-22: Path Traversal

**説明**: ディレクトリトラバーサル攻撃により、アプリケーションのルートディレクトリ外のファイルにアクセスする脆弱性。

**CVSS v3.1 ベーススコア**: 7.5 (High)
- **攻撃ベクトル (AV)**: Network (N)
- **攻撃の複雑さ (AC)**: Low (L)
- **必要な特権 (PR)**: None (N)
- **ユーザー操作 (UI)**: None (N)
- **影響範囲 (S)**: Unchanged (U)
- **機密性への影響 (C)**: High (H)
- **完全性への影響 (I)**: None (N)
- **可用性への影響 (A)**: None (N)

**検出パターン**:
```regex
\.\./|\.\.\\\\|readFile.*\$|open.*\$
```

**脆弱なコード例**:
```python
# 脆弱 - ディレクトリトラバーサル可能
import os
filename = request.args.get('file')
with open(f'/var/www/files/{filename}', 'r') as f:
    content = f.read()
```

**安全なコード例**:
```python
# 安全 - パス正規化とベースディレクトリチェック
import os
filename = request.args.get('file')
base_dir = '/var/www/files/'
file_path = os.path.join(base_dir, os.path.basename(filename))

# ディレクトリトラバーサルを防ぐ
if not os.path.commonpath([base_dir, file_path]) == base_dir:
    raise ValueError("Invalid file path")

with open(file_path, 'r') as f:
    content = f.read()
```

**OWASP参照**: [A01:2021-Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control/)

---

### A02:2021 - Cryptographic Failures

#### CWE-798: Hardcoded Credentials

**説明**: パスワード、APIキー、秘密鍵をソースコードに直接埋め込む脆弱性。

**CVSS v3.1 ベーススコア**: 9.8 (Critical)
- **攻撃ベクトル (AV)**: Network (N)
- **攻撃の複雑さ (AC)**: Low (L)
- **必要な特権 (PR)**: None (N)
- **ユーザー操作 (UI)**: None (N)
- **影響範囲 (S)**: Unchanged (U)
- **機密性への影響 (C)**: High (H)
- **完全性への影響 (I)**: High (H)
- **可用性への影響 (A)**: High (H)

**検出パターン**:
```regex
password\s*=\s*['"]|api_key\s*=\s*['"]|secret\s*=\s*['"]|token\s*=\s*['"]
```

**脆弱なコード例**:
```python
# 脆弱 - ハードコードされた認証情報
DATABASE_PASSWORD = "SuperSecret123!"
API_KEY = "sk-1234567890abcdef"
SECRET_TOKEN = "my-secret-token"
```

**安全なコード例**:
```python
# 安全 - 環境変数から取得
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_PASSWORD = os.environ.get('DATABASE_PASSWORD')
API_KEY = os.environ.get('API_KEY')
SECRET_TOKEN = os.environ.get('SECRET_TOKEN')

# 環境変数が未設定の場合エラー
if not all([DATABASE_PASSWORD, API_KEY, SECRET_TOKEN]):
    raise ValueError("Missing required environment variables")
```

**追加の推奨事項**:
- AWS Secrets Manager、HashiCorp Vault等のシークレット管理サービスの使用
- `.env`ファイルを`.gitignore`に追加
- コミット前のシークレットスキャン (git-secrets, truffleHog)

**OWASP参照**: [A02:2021-Cryptographic Failures](https://owasp.org/Top10/A02_2021-Cryptographic_Failures/)

---

#### CWE-327: Use of a Broken or Risky Cryptographic Algorithm

**説明**: MD5、SHA-1、DES等の脆弱な暗号化アルゴリズムの使用。

**CVSS v3.1 ベーススコア**: 7.5 (High)
- **攻撃ベクトル (AV)**: Network (N)
- **攻撃の複雑さ (AC)**: Low (L)
- **必要な特権 (PR)**: None (N)
- **ユーザー操作 (UI)**: None (N)
- **影響範囲 (S)**: Unchanged (U)
- **機密性への影響 (C)**: High (H)
- **完全性への影響 (I)**: None (N)
- **可用性への影響 (A)**: None (N)

**検出パターン**:
```regex
MD5|SHA1(?!256)|DES|RC4
```

**脆弱なコード例**:
```python
# 脆弱 - MD5の使用（衝突攻撃に脆弱）
import hashlib
password_hash = hashlib.md5(password.encode()).hexdigest()

# 脆弱 - SHA-1の使用
signature = hashlib.sha1(data.encode()).hexdigest()

# 脆弱 - DESの使用
from Crypto.Cipher import DES
cipher = DES.new(key, DES.MODE_ECB)
```

**安全なコード例**:
```python
# 安全 - パスワードハッシュにはbcrypt/argon2を使用
import bcrypt
password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt())

# 安全 - SHA-256以上を使用
import hashlib
signature = hashlib.sha256(data.encode()).hexdigest()

# 安全 - AESの使用
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes

key = get_random_bytes(32)  # 256-bit key
cipher = AES.new(key, AES.MODE_GCM)
```

**推奨アルゴリズム**:
- **ハッシュ**: SHA-256, SHA-3, BLAKE2
- **パスワードハッシュ**: bcrypt, Argon2, scrypt
- **対称暗号**: AES-256 (GCM/CBC mode)
- **非対称暗号**: RSA-2048+, ECDSA (P-256+), Ed25519

**OWASP参照**: [A02:2021-Cryptographic Failures](https://owasp.org/Top10/A02_2021-Cryptographic_Failures/)

---

### A03:2021 - Injection

#### CWE-89: SQL Injection

**説明**: SQLクエリに外部入力を直接埋め込むことで、データベースへの不正アクセスを許す脆弱性。

**CVSS v3.1 ベーススコア**: 9.8 (Critical)
- **攻撃ベクトル (AV)**: Network (N)
- **攻撃の複雑さ (AC)**: Low (L)
- **必要な特権 (PR)**: None (N)
- **ユーザー操作 (UI)**: None (N)
- **影響範囲 (S)**: Unchanged (U)
- **機密性への影響 (C)**: High (H)
- **完全性への影響 (I)**: High (H)
- **可用性への影響 (A)**: High (H)

**検出パターン**:
```regex
exec.*sql|query.*\$|SELECT.*FROM|INSERT.*INTO|UPDATE.*SET|DELETE.*FROM
```

**脆弱なコード例**:
```python
# 脆弱 - 文字列連結によるSQL構築
user_id = request.args.get('id')
query = f"SELECT * FROM users WHERE id = {user_id}"
cursor.execute(query)

# 攻撃例: id = "1 OR 1=1" → 全ユーザーデータ取得
```

**安全なコード例**:
```python
# 安全 - パラメータ化クエリ（プレースホルダー）
user_id = request.args.get('id')
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))

# ORMの使用も推奨
from sqlalchemy import select
stmt = select(User).where(User.id == user_id)
result = session.execute(stmt)
```

**多層防御戦略**:
1. **プリペアドステートメント**: 必須
2. **入力検証**: ホワイトリスト方式
3. **最小権限の原則**: DB接続は必要最小限の権限
4. **エスケープ処理**: 動的SQLが避けられない場合のみ
5. **WAF (Web Application Firewall)**: 追加防御層

**OWASP参照**: [A03:2021-Injection](https://owasp.org/Top10/A03_2021-Injection/)

---

#### CWE-77/78: Command Injection

**説明**: OSコマンドに外部入力を直接埋め込むことで、任意のコマンド実行を許す脆弱性。

**CVSS v3.1 ベーススコア**: 9.8 (Critical)
- **攻撃ベクトル (AV)**: Network (N)
- **攻撃の複雑さ (AC)**: Low (L)
- **必要な特権 (PR)**: None (N)
- **ユーザー操作 (UI)**: None (N)
- **影響範囲 (S)**: Unchanged (U)
- **機密性への影響 (C)**: High (H)
- **完全性への影響 (I)**: High (H)
- **可用性への影響 (A)**: High (H)

**検出パターン**:
```regex
exec\(|system\(|popen\(|shell_exec|passthru
```

**脆弱なコード例**:
```python
# 脆弱 - shellによるコマンド実行
import subprocess
filename = request.args.get('file')
subprocess.call(f"cat {filename}", shell=True)

# 攻撃例: file = "data.txt; rm -rf /" → システムファイル削除
```

**安全なコード例**:
```python
# 安全 - shell=False + 引数リスト
import subprocess
filename = request.args.get('file')

# ファイル名のバリデーション
if not re.match(r'^[a-zA-Z0-9_.-]+$', filename):
    raise ValueError("Invalid filename")

# shell=Falseで配列として渡す
subprocess.call(['cat', filename])

# さらに安全: Pythonのネイティブ関数を使用
with open(filename, 'r') as f:
    content = f.read()
```

**推奨事項**:
- **避けるべき関数**: `os.system()`, `subprocess.call(shell=True)`, `eval()`, `exec()`
- **推奨**: ネイティブライブラリ関数の使用
- **必要な場合**: 厳格なホワイトリスト検証 + `shell=False`

**OWASP参照**: [A03:2021-Injection](https://owasp.org/Top10/A03_2021-Injection/)

---

#### CWE-79: Cross-Site Scripting (XSS)

**説明**: Webページに悪意あるスクリプトを注入し、他のユーザーのブラウザで実行させる脆弱性。

**CVSS v3.1 ベーススコア**: 6.1 (Medium)
- **攻撃ベクトル (AV)**: Network (N)
- **攻撃の複雑さ (AC)**: Low (L)
- **必要な特権 (PR)**: None (N)
- **ユーザー操作 (UI)**: Required (R)
- **影響範囲 (S)**: Changed (C)
- **機密性への影響 (C)**: Low (L)
- **完全性への影響 (I)**: Low (L)
- **可用性への影響 (A)**: None (N)

**検出パターン**:
```regex
innerHTML|document\.write|eval\(|dangerouslySetInnerHTML
```

**脆弱なコード例**:
```javascript
// 脆弱 - DOMベースXSS
const username = new URLSearchParams(window.location.search).get('name');
document.getElementById('greeting').innerHTML = `Hello, ${username}!`;

// 攻撃例: ?name=<script>alert(document.cookie)</script>

// 脆弱 - Reactでの危険なHTML挿入
function UserComment({ comment }) {
  return <div dangerouslySetInnerHTML={{ __html: comment }} />;
}
```

**安全なコード例**:
```javascript
// 安全 - textContentの使用
const username = new URLSearchParams(window.location.search).get('name');
document.getElementById('greeting').textContent = `Hello, ${username}!`;

// 安全 - Reactの自動エスケープ
function UserComment({ comment }) {
  return <div>{comment}</div>;
}

// 安全 - DOMPurifyによるサニタイゼーション
import DOMPurify from 'dompurify';
function UserComment({ comment }) {
  const clean = DOMPurify.sanitize(comment);
  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

**XSS対策まとめ**:
- **出力エスケープ**: HTMLコンテキスト、JavaScript、CSS、URL
- **Content Security Policy (CSP)**: `script-src 'self'`
- **HTTPOnlyクッキー**: セッショントークン
- **入力検証**: ホワイトリスト方式

**OWASP参照**: [A03:2021-Injection](https://owasp.org/Top10/A03_2021-Injection/)

---

### A08:2021 - Software and Data Integrity Failures

#### CWE-502: Deserialization of Untrusted Data

**説明**: 信頼できないデータのデシリアライゼーションにより、任意のコード実行を許す脆弱性。

**CVSS v3.1 ベーススコア**: 9.8 (Critical)
- **攻撃ベクトル (AV)**: Network (N)
- **攻撃の複雑さ (AC)**: Low (L)
- **必要な特権 (PR)**: None (N)
- **ユーザー操作 (UI)**: None (N)
- **影響範囲 (S)**: Unchanged (U)
- **機密性への影響 (C)**: High (H)
- **完全性への影響 (I)**: High (H)
- **可用性への影響 (A)**: High (H)

**検出パターン**:
```regex
unserialize|pickle\.loads|yaml\.load(?!_safe)|eval
```

**脆弱なコード例**:
```python
# 脆弱 - Pickleによるデシリアライゼーション
import pickle
user_data = request.cookies.get('session')
session = pickle.loads(base64.b64decode(user_data))

# 脆弱 - yaml.load
import yaml
config = yaml.load(request.data)

# 脆弱 - PHP unserialize
<?php
$data = unserialize($_POST['data']);
?>
```

**安全なコード例**:
```python
# 安全 - JSONの使用（シンプルなデータ構造のみ）
import json
user_data = request.cookies.get('session')
session = json.loads(base64.b64decode(user_data))

# 安全 - yaml.safe_load
import yaml
config = yaml.safe_load(request.data)

# 安全 - 署名付きシリアライゼーション
from itsdangerous import URLSafeSerializer
s = URLSafeSerializer(SECRET_KEY)
session = s.loads(user_data)
```

**推奨事項**:
- **JSONの使用**: 可能な限りJSONを選択
- **署名検証**: `itsdangerous`, JWT等
- **ホワイトリスト**: 許可されたクラスのみデシリアライゼーション
- **入力検証**: デシリアライゼーション前のスキーマ検証

**OWASP参照**: [A08:2021-Software and Data Integrity Failures](https://owasp.org/Top10/A08_2021-Software_and_Data_Integrity_Failures/)

---

## CWE IDリファレンス

### サポートされるCWE一覧

| CWE ID | 名称 | OWASP 2021 | 重要度 | 検出精度 |
|--------|------|-----------|--------|---------|
| CWE-22 | Path Traversal | A01 | High | 85% |
| CWE-77 | Command Injection (Neutral) | A03 | Critical | 90% |
| CWE-78 | OS Command Injection | A03 | Critical | 90% |
| CWE-79 | Cross-Site Scripting (XSS) | A03 | Medium | 80% |
| CWE-89 | SQL Injection | A03 | Critical | 92% |
| CWE-327 | Broken Crypto Algorithm | A02 | High | 95% |
| CWE-502 | Deserialization | A08 | Critical | 88% |
| CWE-798 | Hardcoded Credentials | A02 | Critical | 70% |

**検出精度**: パターンマッチングのみの精度（AI分析で向上）

### 将来追加予定のCWE

| CWE ID | 名称 | OWASP 2021 | 優先度 | 実装予定 |
|--------|------|-----------|--------|---------|
| CWE-90 | LDAP Injection | A03 | High | v1.1 |
| CWE-611 | XML External Entity (XXE) | A05 | High | v1.1 |
| CWE-918 | Server-Side Request Forgery | A10 | High | v1.2 |
| CWE-287 | Improper Authentication | A07 | Critical | v1.2 |
| CWE-798 | Hardcoded Credentials | A02 | Critical | v1.0 |

---

## カスタムルール定義

### 基本構文

セキュリティルールは`claude-security-review.sh`の`SECURITY_RULES`連想配列で定義されます。

**フォーマット**:
```bash
SECURITY_RULES[rule_key]="CWE-ID|Description|regex_pattern"
```

**パラメータ**:
- `rule_key`: 一意のルール識別子（英数字とアンダースコア）
- `CWE-ID`: CWE識別子（複数の場合はカンマ区切り）
- `Description`: 人間が読める脆弱性の説明
- `regex_pattern`: 検出用の正規表現パターン

### カスタムルール追加例

#### 例1: LDAP Injection検出

```bash
# scripts/claude-security-review.sh に追加

# ルール定義
SECURITY_RULES[ldap_injection]="CWE-90|LDAP Injection|ldapsearch.*\$|ldap_bind.*\$|ldap_search.*\$"

# 検出関数（オプション: より精密な検出が必要な場合）
check_ldap_injection() {
    local code_diff="$1"
    local output_file="$2"
    local findings=0

    # LDAPクエリ構築パターンを検索
    local matches=$(echo "$code_diff" | grep -iE "ldap.*\\\$|ldap.*format|ldap.*%" || true)

    if [[ -n "$matches" ]]; then
        findings=$(echo "$matches" | wc -l)
        echo "### 🔴 LDAP Injection (CWE-90)" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Matches found**: $findings" >> "$output_file"
        echo "" >> "$output_file"
        echo '```' >> "$output_file"
        echo "$matches" | head -10 >> "$output_file"
        echo '```' >> "$output_file"
        echo "" >> "$output_file"

        # VibeLogger記録
        vibe_vulnerability_found "LDAP Injection" "High" "CWE-90" "$findings"
    fi

    echo "$findings"
}

# check_security_patterns()の後に追加
total_vulnerabilities=$((total_vulnerabilities + $(check_ldap_injection "$diff_content" "$output_file")))
```

**検出される脆弱なコード**:
```python
# 脆弱 - LDAP Injection
import ldap
username = request.form['username']
filter_str = f"(uid={username})"  # ❌
conn.search_s(base_dn, ldap.SCOPE_SUBTREE, filter_str)
```

**安全なコード**:
```python
# 安全 - エスケープ処理
from ldap.filter import escape_filter_chars
username = request.form['username']
filter_str = f"(uid={escape_filter_chars(username)})"  # ✅
conn.search_s(base_dn, ldap.SCOPE_SUBTREE, filter_str)
```

#### 例2: Server-Side Request Forgery (SSRF) 検出

```bash
# ルール定義
SECURITY_RULES[ssrf]="CWE-918|Server-Side Request Forgery|requests\.get.*\$|urllib\.request.*\$|file_get_contents.*\$|curl.*\$"

# 検出関数
check_ssrf() {
    local code_diff="$1"
    local output_file="$2"
    local findings=0

    # HTTP/URLリクエスト関数 + 変数展開を検索
    local matches=$(echo "$code_diff" | grep -iE "(requests\.|urllib\.|curl|file_get_contents).*(\\\$|\{)" || true)

    if [[ -n "$matches" ]]; then
        findings=$(echo "$matches" | wc -l)
        echo "### 🟠 Server-Side Request Forgery (CWE-918)" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Severity**: High" >> "$output_file"
        echo "**Matches found**: $findings" >> "$output_file"
        echo "" >> "$output_file"
        echo '```' >> "$output_file"
        echo "$matches" | head -10 >> "$output_file"
        echo '```' >> "$output_file"
        echo "" >> "$output_file"
        echo "**Remediation**: URLホワイトリスト検証、プライベートIPアドレスのブロック" >> "$output_file"
        echo "" >> "$output_file"

        vibe_vulnerability_found "SSRF" "High" "CWE-918" "$findings"
    fi

    echo "$findings"
}
```

**検出される脆弱なコード**:
```python
# 脆弱 - SSRF
import requests
url = request.args.get('url')
response = requests.get(url)  # ❌ 内部ネットワークへのアクセス可能
```

**安全なコード**:
```python
# 安全 - URLホワイトリスト
import requests
from urllib.parse import urlparse

url = request.args.get('url')
parsed = urlparse(url)

# ホワイトリスト検証
ALLOWED_HOSTS = ['api.example.com', 'cdn.example.com']
if parsed.hostname not in ALLOWED_HOSTS:
    raise ValueError("Unauthorized URL")

# プライベートIPブロック
import ipaddress
ip = ipaddress.ip_address(parsed.hostname)
if ip.is_private:
    raise ValueError("Private IP access forbidden")

response = requests.get(url, timeout=5)  # ✅
```

#### 例3: XML External Entity (XXE) 検出

```bash
# ルール定義
SECURITY_RULES[xxe]="CWE-611|XML External Entity|<!ENTITY|SYSTEM|PUBLIC|XMLParser|etree\.parse"

# 検出関数
check_xxe() {
    local code_diff="$1"
    local output_file="$2"
    local findings=0

    # XML解析 + ENTITY定義を検索
    local matches=$(echo "$code_diff" | grep -iE "(<!ENTITY|XMLParser|etree\.parse|dom\.parse)" || true)

    if [[ -n "$matches" ]]; then
        findings=$(echo "$matches" | wc -l)
        echo "### 🔴 XML External Entity (CWE-611)" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Severity**: Critical" >> "$output_file"
        echo "**Matches found**: $findings" >> "$output_file"
        echo "" >> "$output_file"
        echo '```' >> "$output_file"
        echo "$matches" | head -10 >> "$output_file"
        echo '```' >> "$output_file"
        echo "" >> "$output_file"
        echo "**Remediation**: 外部エンティティの無効化、安全なXMLパーサーの使用" >> "$output_file"
        echo "" >> "$output_file"

        vibe_vulnerability_found "XXE" "Critical" "CWE-611" "$findings"
    fi

    echo "$findings"
}
```

**検出される脆弱なコード**:
```python
# 脆弱 - XXE
from lxml import etree
xml_data = request.data
tree = etree.parse(xml_data)  # ❌ 外部エンティティ有効
```

**安全なコード**:
```python
# 安全 - 外部エンティティ無効化
from lxml import etree
parser = etree.XMLParser(resolve_entities=False, no_network=True)
xml_data = request.data
tree = etree.parse(xml_data, parser)  # ✅
```

### カスタムルールのベストプラクティス

1. **明確なCWE IDの指定**: 既存のCWEを参照
2. **正確な正規表現**: 偽陽性を最小化
3. **重要度の適切な設定**: CVSS v3.1に基づく
4. **修復ガイダンス**: 安全なコード例を提供
5. **テスト**: 既知の脆弱なコードでルールを検証

---

## CVSS v3.1スコアリング

### CVSS v3.1メトリクス

**ベーススコア計算式**:
```
Impact = 1 - [(1 - C) × (1 - I) × (1 - A)]
Exploitability = 8.22 × AV × AC × PR × UI

If (Scope = Unchanged):
  BaseScore = Roundup(Minimum[(Impact + Exploitability), 10])
If (Scope = Changed):
  BaseScore = Roundup(Minimum[1.08 × (Impact + Exploitability), 10])
```

### メトリクス定義

#### 攻撃ベクトル (AV)

| 値 | スコア | 説明 | 例 |
|----|-------|------|-----|
| Network (N) | 0.85 | ネットワーク経由で攻撃可能 | Webアプリケーション脆弱性 |
| Adjacent (A) | 0.62 | 隣接ネットワークから攻撃可能 | Wi-Fi攻撃 |
| Local (L) | 0.55 | ローカルアクセスが必要 | ローカル権限昇格 |
| Physical (P) | 0.20 | 物理アクセスが必要 | USBマルウェア |

#### 攻撃の複雑さ (AC)

| 値 | スコア | 説明 |
|----|-------|------|
| Low (L) | 0.77 | 特別な条件不要 |
| High (H) | 0.44 | 特別な条件が必要（タイミング、競合状態等） |

#### 必要な特権 (PR)

| 値 | Scope=Unchanged | Scope=Changed | 説明 |
|----|----------------|---------------|------|
| None (N) | 0.85 | 0.85 | 認証不要 |
| Low (L) | 0.62 | 0.68 | 基本ユーザー権限 |
| High (H) | 0.27 | 0.50 | 管理者権限 |

#### ユーザー操作 (UI)

| 値 | スコア | 説明 | 例 |
|----|-------|------|-----|
| None (N) | 0.85 | ユーザー操作不要 | SQLインジェクション |
| Required (R) | 0.62 | ユーザー操作が必要 | XSS（クリックが必要） |

#### 影響範囲 (S)

| 値 | 説明 |
|----|------|
| Unchanged (U) | 脆弱性の影響が脆弱なコンポーネントに限定 |
| Changed (C) | 脆弱性の影響が他のコンポーネントに及ぶ |

#### CIA影響

| 値 | スコア | 説明 |
|----|-------|------|
| High (H) | 0.56 | 完全な損失 |
| Low (L) | 0.22 | 部分的な損失 |
| None (N) | 0.00 | 影響なし |

### スコアリング例

#### SQL Injection (CWE-89)

```
AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H = 9.8 (Critical)

理由:
- AV:N - Web経由でリモート攻撃可能
- AC:L - 特別な条件不要
- PR:N - 認証不要
- UI:N - ユーザー操作不要
- S:U - 影響範囲は変わらない
- C:H - 全データ読み取り可能
- I:H - 全データ改ざん可能
- A:H - データベース停止可能
```

#### XSS (CWE-79)

```
AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N = 6.1 (Medium)

理由:
- AV:N - Web経由でリモート攻撃可能
- AC:L - 特別な条件不要
- PR:N - 認証不要
- UI:R - 被害者のクリックが必要
- S:C - 他のユーザーに影響が及ぶ
- C:L - セッションCookie等の限定的な情報漏洩
- I:L - 限定的なDOM改ざん
- A:N - 可用性への影響なし
```

### 重要度分類

| CVSSスコア | 重要度 | 対応期限 | 例 |
|-----------|--------|---------|-----|
| 9.0 - 10.0 | **Critical** | 即座（24時間以内） | SQL Injection, Command Injection |
| 7.0 - 8.9 | **High** | 1週間以内 | Path Traversal, Insecure Crypto |
| 4.0 - 6.9 | **Medium** | 1ヶ月以内 | XSS, Information Disclosure |
| 0.1 - 3.9 | **Low** | 次回リリース時 | Minor Configuration Issues |

---

## セキュリティテスト戦略

### 段階的セキュリティテスト

```
Phase 1: 静的解析 (SAST)
  ├─ Claude Security Review (本ツール)
  ├─ Semgrep
  └─ SonarQube

Phase 2: 動的解析 (DAST)
  ├─ OWASP ZAP
  ├─ Burp Suite
  └─ Nikto

Phase 3: 侵入テスト
  ├─ 手動セキュリティテスト
  ├─ ペネトレーションテスト
  └─ Red Team評価

Phase 4: 継続的監視
  ├─ Runtime Application Self-Protection (RASP)
  ├─ Security Information and Event Management (SIEM)
  └─ Intrusion Detection System (IDS)
```

### CI/CD統合

**推奨ワークフロー**:
```yaml
# .github/workflows/security.yml
name: Security Checks

on: [push, pull_request]

jobs:
  sast:
    runs-on: ubuntu-latest
    steps:
      - name: Claude Security Review
        run: bash scripts/claude-security-review.sh --severity High

      - name: Semgrep
        run: semgrep --config=auto .

      - name: Dependency Check
        run: safety check

  dast:
    runs-on: ubuntu-latest
    needs: sast
    steps:
      - name: ZAP Scan
        run: docker run -v $(pwd):/zap/wrk/:rw owasp/zap2docker-stable zap-baseline.py -t https://testsite.com
```

### ゲート基準

**本番デプロイ前の必須条件**:
- ❌ Critical脆弱性: 0件
- ⚠️ High脆弱性: 0件（例外承認プロセスあり）
- ✅ Medium脆弱性: リスク受容またはWAF軽減策
- ✅ Low脆弱性: バックログに追加

---

## 修復ガイドライン

### 優先順位付けフレームワーク

**リスクスコア** = CVSS × 脆弱性の数 × 公開度

| 要因 | 係数 |
|------|------|
| CVSSスコア | 0.1 - 1.0 |
| 脆弱性の数 | 実数 |
| 公開度 | Internet-facing: 1.5, Internal: 1.0, Isolated: 0.5 |

**例**:
```
SQL Injection: 9.8 × 3箇所 × 1.5 (Internet-facing) = 44.1 (最優先)
XSS: 6.1 × 10箇所 × 1.5 = 91.5 (最優先)
Hardcoded Secret: 9.8 × 1箇所 × 1.0 (Internal) = 9.8 (高優先)
```

### 修復ワークフロー

```
1. トリアージ (1-2日)
   ├─ 脆弱性の検証
   ├─ 誤検出の除外
   └─ 優先順位付け

2. 修復実装 (重要度により異なる)
   ├─ Critical: 即座
   ├─ High: 1週間
   ├─ Medium: 1ヶ月
   └─ Low: バックログ

3. テスト (1-3日)
   ├─ 単体テスト
   ├─ セキュリティテスト再実行
   └─ 回帰テスト

4. デプロイ (1日)
   ├─ ステージング検証
   ├─ 本番デプロイ
   └─ ポストデプロイ監視

5. 検証 (1週間)
   ├─ 脆弱性スキャン再実行
   ├─ ログ監視
   └─ クローズ判定
```

### 文書化要件

**修復記録に含めるべき情報**:
- 脆弱性ID (CWE-XX)
- 検出日時
- 重要度 (CVSSスコア)
- 影響範囲
- 修復内容
- テスト結果
- 修復完了日時
- レビュアー承認

---

## 付録

### A. セキュリティチェックリスト

#### コミット前チェック

- [ ] ハードコードされた認証情報の削除
- [ ] デバッグコード/ログの削除
- [ ] 機密情報のコメントアウト削除
- [ ] 環境変数からのシークレット読み込み確認
- [ ] `.env`ファイルの`.gitignore`追加確認

#### プルリクエストレビュー

- [ ] Claude Security Review実行 (--severity High)
- [ ] SQL Injection対策確認（パラメータ化クエリ）
- [ ] XSS対策確認（出力エスケープ）
- [ ] Command Injection対策確認（shell=False）
- [ ] 入力検証の実装確認
- [ ] エラーハンドリングの適切性確認

#### 本番デプロイ前

- [ ] Critical/High脆弱性: 0件
- [ ] SARIF形式レポートのGitHub Security Tabアップロード
- [ ] セキュリティテスト結果の文書化
- [ ] インシデント対応計画の確認
- [ ] ロールバック手順の確認

### B. 参考資料

**OWASP**:
- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)

**CWE**:
- [CWE List](https://cwe.mitre.org/data/index.html)
- [CWE Top 25 Most Dangerous Weaknesses](https://cwe.mitre.org/top25/)

**CVSS**:
- [CVSS v3.1 Specification](https://www.first.org/cvss/v3.1/specification-document)
- [CVSS Calculator](https://www.first.org/cvss/calculator/3.1)

**ツール**:
- [Semgrep](https://semgrep.dev/)
- [OWASP ZAP](https://www.zaproxy.org/)
- [Burp Suite](https://portswigger.net/burp)

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-25
**Maintained By**: Multi-AI Orchestrium Security Team
