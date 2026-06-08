# 🎵 song — Claude Code 作曲ワークフロー

Claude Code を「プロの音楽プロデューサー」として使い、ざっくりした一言から
**破綻のない構成・歌詞・スタイルプロンプト**を設計させるためのリポジトリです。

2 つの出力経路を備えています:

- **Path A — Suno 連携（GPU 不要・今すぐ動く）**
  Claude が歌詞とスタイルプロンプトを `songs/<曲名>.md` に書き出し、
  そのまま Suno AI の Custom モードにコピペすれば曲になります。
- **Path B — ACE-Step 自動レンダリング（GPU + ローカルサーバーが必要）**
  同じ `.md` ファイルを `scripts/acestep.sh` に渡すと、ACE-Step の API に
  投げて `songs/<曲名>.wav` を出力します。

> このリポジトリ自体は GPU を必要としません。Path A はどこでも動きます。
> Path B は手元に GPU と ACE-Step サーバーがあるときだけ使います。

---

## 使い方（一番かんたん：Path A / Suno）

Claude Code をこのリポジトリで起動して、自然言語で頼むだけ:

```
ノリの良いシティポップ作って
```

`music` スキルが起動し、Claude が:

1. ジャンル・BPM・キー・構成を設計し
2. `[Verse]` `[Chorus]` などのタグ付き歌詞を執筆し
3. スタイルプロンプトを組み立て
4. `songs/<曲名>.md` に保存します。

できたファイルの **`style`** を Suno の「Style of Music」へ、**`# LYRICS`
以下**を「Lyrics」へコピペして生成してください。

サンプル: [`songs/midnight-signal.md`](songs/midnight-signal.md)

### 修正・リペイントもチャットで

- 「2番の歌詞だけ変えて」→ `[Verse 2]` だけ書き換え
- 「間奏をもっと激しく」→ `[Bridge]` とスタイルプロンプトを調整
- 「もっとアップテンポに」→ BPM を引き上げ

Claude は毎回 `songs/<曲名>.md` を直接編集するので、ファイルが常に最新の
正本になります。

---

## 使い方（自動化：Path B / ACE-Step）

### 1. ACE-Step サーバーを起動（GPU 環境）

付属のセットアップスクリプトが、ACE-Step のクローン・venv 作成・依存導入・
API サーバー起動までまとめて行います（GPU 必須・冪等）:

```bash
scripts/setup_acestep.sh            # 導入（初回のみ）＋サーバー起動
# scripts/setup_acestep.sh --install  # 導入だけ
# scripts/setup_acestep.sh --start    # 起動だけ（導入済み前提）
```

設定は環境変数で上書きできます:

| 変数 | 既定値 | 説明 |
| --- | --- | --- |
| `ACESTEP_HOME` | `./.acestep` | クローン/インストール先 |
| `ACESTEP_REPO` | 公式リポジトリ | 取得元 Git URL |
| `ACESTEP_PORT` | `7865` | API/Gradio ポート |
| `ACESTEP_HOST` | `0.0.0.0` | バインドアドレス |

> 手動で入れたい場合は [ACE-Step](https://github.com/ace-step/ACE-Step) 本家の
> README に従ってサーバーを起動してください（既定 `http://localhost:7865`）。
> ACE-Step の起動エントリ名はバージョンで変わることがあるため、スクリプトは
> 代表的な起動方法を順に試します。

### 2. レンダリング

```bash
.claude/skills/music/scripts/acestep.sh songs/midnight-signal.md
# → songs/midnight-signal.wav を出力
```

設定は環境変数で上書きできます:

| 変数 | 既定値 | 説明 |
| --- | --- | --- |
| `ACESTEP_API_URL` | `http://localhost:7865` | サーバーのベース URL |
| `ACESTEP_ENDPOINT` | `/generate` | 生成エンドポイント |
| `ACESTEP_STEPS` | `60` | 推論ステップ数 |

> ACE-Step のサーバー実装によって API 形式が異なります。Gradio の `/call/`
> 形式を使う場合は `ACESTEP_ENDPOINT` とスクリプト内のペイロードを合わせて
> ください（`.md` の解析部分はそのまま使えます）。

---

## リポジトリ構成

```
.
├── README.md
├── .claude/
│   └── skills/
│       └── music/                  # Claude Code Agent Skill 本体
│           ├── SKILL.md            # プロデューサーとしての振る舞い・手順
│           ├── references/
│           │   ├── song-structure.md   # 構成タグ / 編曲パターン / 作詞のコツ
│           │   ├── genres.md            # ジャンル別 BPM・楽器チートシート
│           │   └── suno-prompting.md    # スタイルプロンプトの型と注意点
│           └── scripts/
│               └── acestep.sh      # ACE-Step API 呼び出しスクリプト
├── scripts/
│   └── setup_acestep.sh            # ACE-Step の導入＋サーバー起動（GPU環境用）
├── templates/
│   └── suno-song.md                # 出力ファイルのテンプレート
└── songs/                          # 生成した曲（.md / .wav）の置き場
    └── midnight-signal.md          # サンプル
```

---

## スキルの仕組み

`.claude/skills/music/SKILL.md` が Claude Code の Agent Skill です。このリポジ
トリ内で Claude Code を起動すると自動で読み込まれます。グローバルに使いたい
場合は `music` フォルダを `~/.claude/skills/` にコピーしてください。

スキルは「作曲して」系の依頼を検知すると、上記の手順でプロデューサーとして
振る舞い、Path A/B のどちらかで曲を仕上げます。
