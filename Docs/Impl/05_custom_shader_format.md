# カスタムシェーダーのファイル仕様

> 公式: https://lilxyzw.github.io/lilToon/ja_JP/dev/custom_shader_format.html

---

## ファイル形式の概要

| 拡張子 | 役割 |
|--------|------|
| `.lilcontainer` | シェーダーのエントリーポイント。ShaderLab に独自仕様を追加した形式 |
| `.lilblock` | プロパティ・サブシェーダー・パス等のブロックを定義するファイル |

`.lilcontainer` は基本的に ShaderLab と同じ記述方法ですが、
いくつかの独自キーワードが追加されています。

---

## .lilcontainer の基本テンプレート

```hlsl
Shader "*LIL_SHADER_NAME*"
{
    Properties
    {
        lilProperties "Default"
        lilProperties "DefaultOpaque"
        lilProperties "Properties.lilblock"
    }

    HLSLINCLUDE
    ENDHLSL

    lilSubShaderTags {"RenderType" = "Opaque" "Queue" = "Geometry"}
    lilSubShaderBRP  "DefaultMulti"
    lilSubShaderURP  "DefaultMulti"
    lilSubShaderHDRP "DefaultMulti"

    CustomEditor "*LIL_EDITOR_NAME*"
}
```

`*LIL_SHADER_NAME*` と `*LIL_EDITOR_NAME*` は `lilCustomShaderDatas.lilblock` の
`Replace` タグまたは `ShaderName` / `EditorName` タグで自動置換されます。

---

## .lilcontainer 独自キーワード

### Properties ブロック内

| キーワード | 説明 |
|-----------|------|
| `lilProperties "キーワード"` | 指定したキーワードのプロパティを挿入 |
| `lilSkipSettings` | シェーダー設定の挿入をスキップ |

### SubShader / Pass 定義

| キーワード | 説明 |
|-----------|------|
| `lilSubShaderTags {}` | SubShader 内の Tags ブロックを指定 |
| `lilSubShaderInsert "キーワード"` | Unity ライブラリの `#include` 直後に処理を挿入 |
| `lilSubShaderInsertPost "キーワード"` | `vert()` 定義の後に処理を挿入（ジオメトリシェーダー定義に使用） |
| `lilPassShaderName "シェーダー名"` | UsePass で読み込むソースシェーダー名を指定 |
| `lilSubShaderBRP "キーワード"` | Built-in RP の SubShader を挿入 |
| `lilSubShaderURP "キーワード"` | URP の SubShader を挿入 |
| `lilSubShaderHDRP "キーワード"` | HDRP の SubShader を挿入 |

---

## lilCustomShaderDatas.lilblock

シェーダーのメタデータと置換設定をまとめるファイルです。
`.lilcontainer` と同じ階層に配置します。

### 対応タグ一覧

| タグ | 説明 | 例 |
|------|------|-----|
| `ShaderName` | シェーダー名（共通設定） | `ShaderName "MyPackage/Custom"` |
| `EditorName` | エディター名（共通設定） | `EditorName "MyPackage.CustomInspector"` |
| `Replace` | 文字列置換 | `Replace "*LIL_SHADER_NAME*" "MyShader"` |
| `InsertPassPre` | パスの前に挿入 | `InsertPassPre "PassName"` |
| `InsertPassPost` | パスの後に挿入 | `InsertPassPost "PassName"` |
| `InsertUsePassPre` | UsePass の前に挿入 | `InsertUsePassPre "PassName"` |
| `InsertUsePassPost` | UsePass の後に挿入 | `InsertUsePassPost "PassName"` |

> `InsertPass` は後に記述したものが優先されます。

### 記述例

```
ShaderName "TemplateFull"
EditorName "lilToon.TemplateFullInspector"
Replace "From" "To"
```

---

## Pragma ディレクティブ

カスタムシェーダー向けの `#pragma` 拡張です：

### マルチコンパイル系

| ディレクティブ | 説明 |
|--------------|------|
| `#pragma lil_multi_compile_forward` | Forward パス用マルチコンパイル |
| `#pragma lil_multi_compile_forwardadd` | ForwardAdd パス用マルチコンパイル |
| `#pragma lil_multi_compile_shadowcaster` | ShadowCaster パス用マルチコンパイル |

### スキップ系（バリアント削減）

| ディレクティブ | 説明 |
|--------------|------|
| `#pragma lil_skip_variants_shadows` | シャドウ関連バリアントをスキップ |
| `#pragma lil_skip_variants_lightmaps` | ライトマップ関連バリアントをスキップ |

---

## lilSubShader キーワード一覧

`lilSubShaderBRP` / `lilSubShaderURP` / `lilSubShaderHDRP` に指定できる値：

| キーワード | 説明 |
|-----------|------|
| `Default` | 標準シェーダー |
| `DefaultFakeShadow` | フェイクシャドウ |
| `DefaultFur` | ファー |
| `DefaultGem` | 宝石 |
| `DefaultRefraction` | 屈折 |
| `DefaultRefractionBlur` | ブラー屈折 |
| `DefaultTessellation` | テッセレーション |
| `DefaultLite` | Lite バージョン |
| `DefaultMulti` | マルチバリアント |
| `DefaultMultiOutline` | マルチ（アウトライン付き） |
| `DefaultMultiFur` | マルチ（ファー） |
| `DefaultMultiRefraction` | マルチ（屈折） |
| `DefaultMultiGem` | マルチ（宝石） |
| `DefaultUsePass` 系 | UsePass を使うバリアント |

---

## lilProperties キーワード一覧

`lilProperties` に指定できる値：

| キーワード | 説明 |
|-----------|------|
| `Default` | 全プロパティ |
| `DefaultLite` | Lite 版プロパティ |
| `DefaultOpaque` | 不透明用プロパティ |
| `DefaultCutout` | カットアウト用プロパティ |
| `DefaultTransparent` | 透明用プロパティ |
| `DefaultFurCutout` | ファー（カットアウト）用 |
| `DefaultFurTransparent` | ファー（透明）用 |
| `DefaultRefraction` | 屈折用 |
| `DefaultGem` | 宝石用 |
| `DefaultFakeShadow` | フェイクシャドウ用 |
