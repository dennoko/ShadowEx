# lilToon 拡張シェーダー開発ドキュメント

このディレクトリには lilToon の拡張シェーダー開発に必要な情報をまとめています。
公式サイトを参照しなくてもこのテンプレートプロジェクト内で完結することを目的としています。

## ドキュメント一覧

| ファイル | 内容 | 対応公式ページ |
|---------|------|---------------|
| [01_file_structure.md](01_file_structure.md) | lilToon のディレクトリ・ファイル構成 | files.html |
| [02_shader_structure.md](02_shader_structure.md) | シェーダーバリエーション・パス・Include の内部構造 | shader_structure.html |
| [03_custom_shader.md](03_custom_shader.md) | カスタムシェーダーの作り方（手順・マクロ・Inspector 拡張） | custom_shader.html |
| [04_utilities.md](04_utilities.md) | HLSL ユーティリティ マクロ・関数・構造体リファレンス | utilities.html |
| [05_custom_shader_format.md](05_custom_shader_format.md) | .lilcontainer / .lilblock ファイルの仕様 | custom_shader_format.html |
| [06_geometry_shader.md](06_geometry_shader.md) | ジオメトリシェーダーの挿入方法（GeometryFX 実装解説） | ― |

## 開発の流れ（概要）

1. **テンプレートを複製** — ルートフォルダ名・シェーダー名を変更
2. **プロパティを定義** — `lilCustomShaderProperties.lilblock` に ShaderLab プロパティを追加
3. **HLSL を実装** — `custom.hlsl` に変数定義・頂点/ピクセル処理のマクロを記述
4. **Inspector を拡張** — `Editor/CustomInspector.cs` のクラス名と GUI を実装
5. **バリエーションを削除** — 不要なシェーダーバリエーションを除去してビルドを軽量化

詳細は各ドキュメントを参照してください。
