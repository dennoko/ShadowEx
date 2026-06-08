# 実装後エラー防止チェックリスト

実装が完了したら以下の項目を上から順に確認してください。

---

## 1. テンプレートのリネーム

### 1-1. ファイル・フォルダ名

- [ ] ルートフォルダ名を変更した（`Template` → 任意名）
- [ ] `Editor/TemplateFull.asmdef` のファイル名を変更した

### 1-2. 名前の 4 箇所整合性チェック

以下の 4 箇所がすべて**同じシェーダー名**を指しているか確認する。
1 箇所でもずれるとシェーダーが見つからず Inspector が壊れる。

| ファイル | 編集箇所 | 現在の値 |
|---------|---------|---------|
| `Shaders/lilCustomShaderDatas.lilblock` | `ShaderName "..."` | `TemplateFull` |
| `Shaders/lilCustomShaderDatas.lilblock` | `EditorName "..."` | `lilToon.TemplateFullInspector` |
| `Editor/TemplateFull.asmdef` | `"name": "..."` | `TemplateFull` |
| `Editor/CustomInspector.cs` | `class TemplateFullInspector` のクラス名 | `TemplateFullInspector` |
| `Editor/CustomInspector.cs` | `shaderName = "..."` 定数 | `TemplateFull` |

- [ ] `ShaderName` = `shaderName` 定数（完全一致）
- [ ] `EditorName` = `名前空間.クラス名`（例: `lilToon.MyInspector`）
- [ ] asmdef の `"name"` = asmdef のファイル名（拡張子なし）

---

## 2. プロパティ定義の整合性

### 2-1. プロパティ ↔ HLSL 変数の対応

`lilCustomShaderProperties.lilblock` に追加したプロパティごとに確認する。

- [ ] 通常変数（Float / Vector / Int）は `custom.hlsl` の `LIL_CUSTOM_PROPERTIES` に定義されているか
- [ ] テクスチャ（2D）は `custom.hlsl` の `LIL_CUSTOM_TEXTURES` に `TEXTURE2D(...)` で定義されているか
- [ ] テクスチャを `LIL_CUSTOM_PROPERTIES` に誤って書いていないか

### 2-2. LIL_CUSTOM_PROPERTIES の書式

- [ ] マクロ継続の `\` は**最後の行以外**すべての行末にあるか
- [ ] `\` の後に空白・コメントが混入していないか（コンパイルエラーの原因）
- [ ] プロパティ名の大文字小文字が `.lilblock` と `custom.hlsl` で一致しているか

```hlsl
// 正しい例（最後の行だけ \ なし）
#define LIL_CUSTOM_PROPERTIES \
    float4 _CustomColor;      \
    float  _CustomStrength;

// 誤り例（最後の行にも \ がある → 空定義を連結してエラー）
#define LIL_CUSTOM_PROPERTIES \
    float _CustomStrength; \
```

---

## 3. 頂点シェーダー入力の確認

- [ ] 頂点シェーダー・ジオメトリシェーダーで参照する `input.normalOS` 等に対応する
  `LIL_REQUIRE_APP_*` が `custom.hlsl` で定義されているか

| 使う変数 | 必要な define |
|---------|--------------|
| `input.positionOS` | `LIL_REQUIRE_APP_POSITION` |
| `input.uv0` | `LIL_REQUIRE_APP_TEXCOORD0` |
| `input.normalOS` | `LIL_REQUIRE_APP_NORMAL` |
| `input.tangentOS` | `LIL_REQUIRE_APP_TANGENT` |
| `input.color` | `LIL_REQUIRE_APP_COLOR` |

---

## 4. ピクセルシェーダー挿入の確認

- [ ] `BEFORE_xx` / `OVERRIDE_xx` の `xx` が正しいキーワードか（タイポチェック）
- [ ] `fd.col`・`fd.emissionColor` 等のメンバー名が正しいか（`04_utilities.md` 参照）
- [ ] `OVERRIDE_OUTPUT` を使う場合、戻り値の型が `float4` になっているか

---

## 5. Inspector の整合性

- [ ] `LoadCustomProperties()` で `FindProperty("_変数名", props)` している名前が
  `.lilblock` のプロパティ名と完全一致しているか
- [ ] `DrawCustomProperties()` に描画処理を実装しているか（空のまま忘れていないか）
- [ ] カスタムセクションの折りたたみ変数（`isShowCustomProperties` 等）を宣言しているか
- [ ] `ReplaceToCustomShaders()` の `Shader.Find()` で参照しているシェーダー名が
  実際に残している `.lilcontainer` と一致しているか

---

## 6. 不要バリエーションの削除

使わない `.lilcontainer` を削除した場合の確認：

- [ ] `ReplaceToCustomShaders()` の対応する行を削除またはコメントアウトしたか
  （削除したシェーダーを `Shader.Find()` で探し続けると null が入り続ける）
- [ ] 削除したパスを参照している他の `.lilcontainer` が残っていないか
  （`lilPassShaderName` で削除済みパスを指定している場合エラー）

---

## 7. ジオメトリシェーダーを使う場合の追加確認

通常の拡張シェーダーを作るだけなら不要。`06_geometry_shader.md` の実装をした場合のみ確認する。

- [ ] `custom.hlsl` に `#define LIL_CUSTOM_VERT_COPY` があるか
- [ ] `ltspass_*.lilcontainer` すべてに `lilSubShaderInsertPost "lilCustomShaderInsertPost.lilblock"` を追加したか
- [ ] `lilCustomShaderInsertPost.lilblock` が `#include "custom_insert_post.hlsl"` を含んでいるか
- [ ] `lilCustomShaderDatas.lilblock` に `#pragma geometry geomCustom` を追加する `Replace` があるか
- [ ] `Replace` 文字列のインデント（スペース12個）と改行コード（`\r\n`）が lilToon の生成コードと完全一致しているか
- [ ] `[maxvertexcount(N)]` の N が実際に出力する頂点数以上になっているか
- [ ] `geomCustom()` の先頭に `#if !defined(LIL_PASS_FORWARD_FUR_INCLUDED)` で囲んであるか
  （ファー用パスでは lilToon 側が既にジオメトリシェーダーを持つため競合する）
- [ ] ジオメトリシェーダー内でテクスチャをサンプリングする場合、`LIL_SAMPLE_2D_LOD()` を使っているか
  （ジオメトリシェーダーでは通常の `LIL_SAMPLE_2D()` は使用不可）
- [ ] テッセレーションも併用する場合、`domainCustom()` を定義して `Replace` で `domain` → `domainCustom` に切り替えているか

---

## 8. Unity エディターでの動作確認

- [ ] Unity のコンソールにコンパイルエラー・警告が出ていないか
- [ ] シェーダーが Unity のシェーダー選択リストに表示されるか
- [ ] マテリアルにシェーダーを割り当てて Inspector が正しく表示されるか
- [ ] カスタムプロパティのセクションが折りたたみ付きで表示されるか
- [ ] レンダリングモード（Opaque / Cutout / Transparent）の切り替えが正常に動作するか
- [ ] 実機（または Game ビュー）でシェーダーエフェクトが意図通りに表示されるか

---

## よくあるエラーと原因早見表

| エラー・症状 | まず確認すること |
|-------------|----------------|
| シェーダーが一覧に出ない | `ShaderName` タグと `shaderName` 定数が一致しているか |
| Inspector が紫（エラー表示） | HLSL コンパイルエラー → コンソールで詳細確認 |
| Inspector が lilToon デフォルトのまま | `EditorName` タグとクラス名（名前空間含む）が一致しているか |
| カスタムプロパティが表示されない | `LoadCustomProperties()` の `FindProperty()` プロパティ名を確認 |
| `\` 付近でコンパイルエラー | バックスラッシュ後の空白・最終行の余分な `\` を確認 |
| ジオメトリシェーダーが無効 | `Replace` のインデント・改行コードが lilToon 生成コードと一致しているか |
| ジオメトリシェーダーでテクスチャがおかしい | `LIL_SAMPLE_2D_LOD()` を使っているか（LOD 引数が必要） |
| テッセレーション + ジオメトリが壊れる | `domainCustom()` を定義して `Replace` で切り替えているか |
