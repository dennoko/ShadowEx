# ファイル構成

> 公式: https://lilxyzw.github.io/lilToon/ja_JP/dev/files.html

lilToon パッケージのディレクトリ構成と各ファイルの役割をまとめています。

---

## ディレクトリ構成

```
lilToon/
├── BaseShaderResources/      # メインシェーダーシステムのコアリソース
├── CustomShaderResources/    # カスタムシェーダー向けリソース
│   ├── BRP/                  # Built-in RP サブシェーダー
│   ├── HDRP/                 # HDRP サブシェーダー
│   ├── URP/                  # URP サブシェーダー
│   └── ShaderProperties/     # シェーダープロパティ定義
├── Editor/                   # エディター関連アセット
│   ├── GUI/                  # GUIリソース
│   ├── Language/             # 言語設定ファイル
│   └── *.cs                  # エディタースクリプト群
├── External/                 # 外部 SDK に依存するエディター拡張
├── Prefabs/                  # 組み込みプレハブ（ファーコライダー等）
├── Presets/                  # シェーダープリセット設定
├── Shader/                   # HLSL インクルードファイル・シェーダーファイル
└── Texture/                  # グラジエント・ノイズ・グリッタ等のテクスチャ
```

---

## Editor/ 内の C# スクリプト

| 役割 | 内容 |
|------|------|
| ShaderGUI 拡張 | マテリアルインスペクターの GUI 実装 |
| プロパティ検証 | シェーダープロパティの整合性チェック |
| 起動時初期化 | Unity 起動時の自動セットアップ |
| アセット処理 | インポート時のアセット処理フック |
| メニュー追加 | Unity エディターメニューへの項目追加 |
| プリセット管理 | マテリアルプリセットの適用・保存 |
| マテリアルプロパティ描画 | カスタムプロパティドロワー |

---

## Shader/ 内の主要 HLSL ファイル（40+ ファイル）

| カテゴリ | ファイル例 | 役割 |
|---------|-----------|------|
| 共通 | `lil_common.hlsl` | 設定・マクロ・入力・共通関数 |
| 共通 | `lil_common_appdata.hlsl` | appdata 構造体定義 |
| 共通 | `lil_common_vert.hlsl` | 頂点シェーダー共通処理 |
| 共通 | `lil_common_frag.hlsl` | ピクセルシェーダー共通処理 |
| パス別 | `lil_pass_forward.hlsl` | ForwardBase/UniversalForward パス |
| パス別 | `lil_pass_shadowcaster.hlsl` | ShadowCaster パス |
| パス別 | `lil_pass_meta.hlsl` | META パス |
| パイプライン別 | `lil_pipeline_brp.hlsl` | Built-in RP 固有処理 |
| パイプライン別 | `lil_pipeline_urp.hlsl` | URP 固有処理 |
| パイプライン別 | `lil_pipeline_hdrp.hlsl` | HDRP 固有処理 |

---

## Shader/ 内の主要シェーダーファイル

| ファイル | 用途 |
|---------|------|
| `ltspass_*.shader` | 各パスの実体シェーダー（他のシェーダーが UsePass で参照） |
| `lts_fur.shader` | ファーシェーダー |
| `lts_fur_cutout.shader` | ファー（カットアウト）シェーダー |
| `lts_gem.shader` | 宝石シェーダー |
| `lts_ref.shader` | 屈折シェーダー |
| `lts_ref_blur.shader` | ブラー屈折シェーダー |
| `lts_fakeshadow.shader` | フェイクシャドウシェーダー |
| `ltsmulti_*.shader` | マルチバリアント系シェーダー |

---

## Texture/ 内のテクスチャ（12+ ファイル）

| 種類 | 用途 |
|------|------|
| グラジエント | トゥーンシェーディングのカーブ |
| ノイズ | ディゾルブ・ファー等のノイズ |
| グリッタシェイプ | グリッタエフェクト用形状 |
| マットキャップ素材 | MatCap 用テクスチャ |

---

## その他のファイル

| ファイル | 内容 |
|---------|------|
| `CHANGELOG.md` | 変更履歴 |
| `LICENSE` | MIT ライセンス |
| `package.json` | UPM 設定 |
| `Third Party Notices` | サードパーティライセンス通知 |
