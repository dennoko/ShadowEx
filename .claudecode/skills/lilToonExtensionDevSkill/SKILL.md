# lilToon 拡張シェーダー開発スキル

このスキルは lilToon カスタムシェーダーの実装を支援します。
テンプレートプロジェクトを使った拡張シェーダー開発の全工程をカバーします。

## トリガー条件

以下の場面でこのスキルを参照してください：

- lilToon カスタムシェーダーを新規作成・編集するとき
- `custom.hlsl` / `custom_insert.hlsl` / `custom_insert_post.hlsl` を実装するとき
- `.lilcontainer` / `.lilblock` ファイルを編集するとき
- `CustomInspector.cs` を実装するとき
- ジオメトリシェーダーを追加するとき
- 実装完了後の確認を行うとき

---

## ドキュメント一覧

| ファイル | 内容 |
|---------|------|
| [01_file_structure.md](01_file_structure.md) | lilToon パッケージのディレクトリ・ファイル構成 |
| [02_shader_structure.md](02_shader_structure.md) | シェーダーバリエーション・パス・Include の内部構造 |
| [03_custom_shader.md](03_custom_shader.md) | カスタムシェーダーの作り方（手順・マクロ・Inspector 拡張） |
| [04_utilities.md](04_utilities.md) | HLSL ユーティリティ マクロ・関数・構造体リファレンス |
| [05_custom_shader_format.md](05_custom_shader_format.md) | `.lilcontainer` / `.lilblock` ファイルの仕様 |
| [06_geometry_shader.md](06_geometry_shader.md) | ジオメトリシェーダーの挿入方法 |
| [07_checklist.md](07_checklist.md) | 実装後エラー防止チェックリスト |

---

## 開発の流れ

1. **テンプレートのリネーム** — ルートフォルダ名と下記4箇所の名前を揃える
2. **プロパティ定義** — `lilCustomShaderProperties.lilblock` に ShaderLab プロパティを追加、`custom.hlsl` に `LIL_CUSTOM_PROPERTIES` / `LIL_CUSTOM_TEXTURES` を定義
3. **HLSL 実装** — `custom.hlsl` に頂点/ピクセル処理マクロを記述、パス別処理は `custom_insert.hlsl`
4. **Inspector 拡張** — `CustomInspector.cs` の `LoadCustomProperties()` / `DrawCustomProperties()` を実装
5. **不要バリエーション削除** — 使わない `.lilcontainer` と `ReplaceToCustomShaders()` の対応行を削除
6. **チェックリスト確認** — [07_checklist.md](07_checklist.md) の全項目を上から確認

---

## 重要な注意点

### 名前の4箇所整合性（最頻出バグ）

以下がすべて同じシェーダー名を指していることを確認する。1箇所でもずれると Inspector が壊れる：

| ファイル | 編集箇所 |
|---------|---------|
| `Shaders/lilCustomShaderDatas.lilblock` | `ShaderName "..."` |
| `Shaders/lilCustomShaderDatas.lilblock` | `EditorName "名前空間.クラス名"` |
| `Editor/*.asmdef` | `"name": "..."` とファイル名（拡張子なし） |
| `Editor/CustomInspector.cs` | クラス名と `shaderName` 定数 |

### LIL_CUSTOM_PROPERTIES の書式

```hlsl
// 最終行以外の全行末にバックスラッシュが必要
#define LIL_CUSTOM_PROPERTIES \
    float4 _CustomColor;      \
    float  _CustomStrength;
//  ↑ 最終行は \ なし（あるとコンパイルエラー）
```

バックスラッシュの後に空白・コメントを入れない。

### テクスチャは LIL_CUSTOM_TEXTURES に分離

```hlsl
// テクスチャは LIL_CUSTOM_TEXTURES に書く（LIL_CUSTOM_PROPERTIES に混在させない）
#define LIL_CUSTOM_TEXTURES \
    TEXTURE2D(_CustomMask);
```

### ジオメトリシェーダーを使う場合

詳細は [06_geometry_shader.md](06_geometry_shader.md) を参照。要点：

- `custom.hlsl` に `#define LIL_CUSTOM_VERT_COPY` が必要
- `lilCustomShaderDatas.lilblock` の `Replace` でプラグマ行を置換（インデントと `\r\n` が完全一致必須）
- `ltspass_*.lilcontainer` すべてに `lilSubShaderInsertPost` を追加
- ジオメトリシェーダー内のテクスチャサンプリングは `LIL_SAMPLE_2D_LOD()` を使用（通常の `LIL_SAMPLE_2D` は不可）
- ファー用パスとの競合を避けるため `#if !defined(LIL_PASS_FORWARD_FUR_INCLUDED)` で囲む

---

## よくあるエラー早見表

| エラー・症状 | 確認箇所 |
|-------------|---------|
| シェーダーが一覧に出ない | `ShaderName` タグと `shaderName` 定数が一致しているか |
| Inspector が紫（エラー表示） | HLSL コンパイルエラー → コンソールで詳細確認 |
| Inspector がデフォルトのまま | `EditorName` タグとクラス名（名前空間含む）が一致しているか |
| カスタムプロパティが表示されない | `LoadCustomProperties()` の `FindProperty()` 名を確認 |
| `\` 付近でコンパイルエラー | バックスラッシュ後の空白・最終行の余分な `\` を確認 |
| ジオメトリシェーダーが無効 | `Replace` のインデント・改行コードが lilToon 生成コードと一致しているか |
