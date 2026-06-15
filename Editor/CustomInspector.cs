#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace lilToon
{
    // シェーダー名の変更は以下 3 箇所をすべて揃えること:
    //   1. この class 名（TemplateFullInspector → 任意名）
    //   2. 下の shaderName 定数
    //   3. Shaders/lilCustomShaderDatas.lilblock の ShaderName タグ・EditorName タグ
    //   4. Editor/TemplateFull.asmdef の name フィールドとファイル名自体
    public class ShadowExInspector : lilToonInspector
    {
        // Custom properties（画面空間疑似影）
        // SSAO
        MaterialProperty ssaoEnable;
        MaterialProperty ssaoRadius;
        MaterialProperty ssaoSamples;
        MaterialProperty ssaoIntensity;
        MaterialProperty ssaoBias;
        // Contact Shadow
        MaterialProperty contactEnable;
        MaterialProperty contactSteps;
        MaterialProperty contactLength;
        MaterialProperty contactThickness;
        MaterialProperty contactIntensity;
        // 影の外観（色・馴染み・距離フェード）
        MaterialProperty shadowColor;
        MaterialProperty colorBlend;
        MaterialProperty shadowLift;
        MaterialProperty fadeStart;
        MaterialProperty fadeEnd;

        private static bool isShowCustomProperties;
        private const string shaderName = "ShadowEx";

        protected override void LoadCustomProperties(MaterialProperty[] props, Material material)
        {
            isCustomShader = true;

            // If you want to change rendering modes in the editor, specify the shader here
            ReplaceToCustomShaders();
            isShowRenderMode = !material.shader.name.Contains("Optional");

            // If not, set isShowRenderMode to false
            //isShowRenderMode = false;

            //LoadCustomLanguage("");

            // FindProperty 名は lilCustomShaderProperties.lilblock のプロパティ名と完全一致させること
            ssaoEnable       = FindProperty("_SSAO_Enable", props);
            ssaoRadius       = FindProperty("_SSAO_Radius", props);
            ssaoSamples      = FindProperty("_SSAO_Samples", props);
            ssaoIntensity    = FindProperty("_SSAO_Intensity", props);
            ssaoBias         = FindProperty("_SSAO_Bias", props);

            contactEnable    = FindProperty("_ContactShadow_Enable", props);
            contactSteps     = FindProperty("_ContactShadow_Steps", props);
            contactLength    = FindProperty("_ContactShadow_Length", props);
            contactThickness = FindProperty("_ContactShadow_Thickness", props);
            contactIntensity = FindProperty("_ContactShadow_Intensity", props);

            shadowColor = FindProperty("_ShadowEx_ShadowColor", props);
            colorBlend  = FindProperty("_ShadowEx_ColorBlend",  props);
            shadowLift  = FindProperty("_ShadowEx_ShadowLift",  props);
            fadeStart   = FindProperty("_ShadowEx_FadeStart",   props);
            fadeEnd     = FindProperty("_ShadowEx_FadeEnd",     props);
        }

        protected override void DrawCustomProperties(Material material)
        {
            // GUIStyles Name   Description
            // ---------------- ------------------------------------
            // boxOuter         outer box
            // boxInnerHalf     inner box
            // boxInner         inner box without label
            // customBox        box (similar to unity default box)
            // customToggleFont label for box
            //
            // Helper methods:
            //   Foldout(label, key, isOpen)      : 折りたたみセクション（bool を返す）
            //   DrawLine()                        : 区切り線
            //   DrawWebButton(label, url)         : Web リンクボタン
            //   LoadCustomLanguage(guid)          : 言語ファイル読み込み（Editor/lang_custom.txt の GUID）
            //   m_MaterialEditor.ShaderProperty() : 通常プロパティの描画
            //   m_MaterialEditor.TexturePropertySingleLine() : テクスチャ + インラインプロパティ

            isShowCustomProperties = Foldout("Screen Space Shadow", "Screen Space Shadow", isShowCustomProperties);
            if(isShowCustomProperties)
            {
                EditorGUILayout.BeginVertical(boxOuter);
                EditorGUILayout.LabelField("Screen Space Shadow", customToggleFont);
                EditorGUILayout.BeginVertical(boxInnerHalf);

                // SSAO
                m_MaterialEditor.ShaderProperty(ssaoEnable, "SSAO Enable");
                if(ssaoEnable.floatValue > 0.5f)
                {
                    EditorGUI.indentLevel++;
                    m_MaterialEditor.ShaderProperty(ssaoRadius, "Radius (m)");
                    m_MaterialEditor.ShaderProperty(ssaoSamples, "Samples");
                    m_MaterialEditor.ShaderProperty(ssaoIntensity, "Intensity");
                    m_MaterialEditor.ShaderProperty(ssaoBias, "Bias");
                    EditorGUI.indentLevel--;
                }

                DrawLine();

                // Contact Shadow
                m_MaterialEditor.ShaderProperty(contactEnable, "Contact Shadow Enable");
                if(contactEnable.floatValue > 0.5f)
                {
                    EditorGUI.indentLevel++;
                    m_MaterialEditor.ShaderProperty(contactSteps, "Steps");
                    m_MaterialEditor.ShaderProperty(contactLength, "Length");
                    m_MaterialEditor.ShaderProperty(contactThickness, "Thickness");
                    m_MaterialEditor.ShaderProperty(contactIntensity, "Intensity");
                    EditorGUI.indentLevel--;
                }

                DrawLine();

                // 影の外観
                EditorGUILayout.LabelField("影の外観", EditorStyles.boldLabel);
                EditorGUI.indentLevel++;
                m_MaterialEditor.ShaderProperty(shadowColor, "Shadow Color");
                m_MaterialEditor.ShaderProperty(colorBlend,  "Color Blend（メインカラーと混色）");
                m_MaterialEditor.ShaderProperty(shadowLift,  "Shadow Lift（馴染み・最暗部の持ち上げ）");
                EditorGUI.indentLevel--;

                DrawLine();

                // 距離フェード
                EditorGUILayout.LabelField("距離フェード", EditorStyles.boldLabel);
                EditorGUI.indentLevel++;
                m_MaterialEditor.ShaderProperty(fadeStart, "Fade Start (m)");
                m_MaterialEditor.ShaderProperty(fadeEnd,   "Fade End (m)");
                EditorGUI.indentLevel--;

                // 軽量化の注意（Samples + Steps の合計が多いと多人数インスタンスで重くなる）
                EditorGUILayout.HelpBox(
                    "Samples + Steps の合計は 12 以下を推奨。深度テクスチャが無いワールドでは効果が出ません。",
                    MessageType.Info);

                EditorGUILayout.EndVertical();
                EditorGUILayout.EndVertical();
            }
        }

        protected override void ReplaceToCustomShaders()
        {
            lts         = Shader.Find(shaderName + "/lilToon");
            ltsc        = Shader.Find("Hidden/" + shaderName + "/Cutout");
            ltst        = Shader.Find("Hidden/" + shaderName + "/Transparent");
            ltsot       = Shader.Find("Hidden/" + shaderName + "/OnePassTransparent");
            ltstt       = Shader.Find("Hidden/" + shaderName + "/TwoPassTransparent");

            ltso        = Shader.Find("Hidden/" + shaderName + "/OpaqueOutline");
            ltsco       = Shader.Find("Hidden/" + shaderName + "/CutoutOutline");
            ltsto       = Shader.Find("Hidden/" + shaderName + "/TransparentOutline");
            ltsoto      = Shader.Find("Hidden/" + shaderName + "/OnePassTransparentOutline");
            ltstto      = Shader.Find("Hidden/" + shaderName + "/TwoPassTransparentOutline");

            ltsoo       = Shader.Find(shaderName + "/[Optional] OutlineOnly/Opaque");
            ltscoo      = Shader.Find(shaderName + "/[Optional] OutlineOnly/Cutout");
            ltstoo      = Shader.Find(shaderName + "/[Optional] OutlineOnly/Transparent");

            ltstess     = Shader.Find("Hidden/" + shaderName + "/Tessellation/Opaque");
            ltstessc    = Shader.Find("Hidden/" + shaderName + "/Tessellation/Cutout");
            ltstesst    = Shader.Find("Hidden/" + shaderName + "/Tessellation/Transparent");
            ltstessot   = Shader.Find("Hidden/" + shaderName + "/Tessellation/OnePassTransparent");
            ltstesstt   = Shader.Find("Hidden/" + shaderName + "/Tessellation/TwoPassTransparent");

            ltstesso    = Shader.Find("Hidden/" + shaderName + "/Tessellation/OpaqueOutline");
            ltstessco   = Shader.Find("Hidden/" + shaderName + "/Tessellation/CutoutOutline");
            ltstessto   = Shader.Find("Hidden/" + shaderName + "/Tessellation/TransparentOutline");
            ltstessoto  = Shader.Find("Hidden/" + shaderName + "/Tessellation/OnePassTransparentOutline");
            ltstesstto  = Shader.Find("Hidden/" + shaderName + "/Tessellation/TwoPassTransparentOutline");

            ltsl        = Shader.Find(shaderName + "/lilToonLite");
            ltslc       = Shader.Find("Hidden/" + shaderName + "/Lite/Cutout");
            ltslt       = Shader.Find("Hidden/" + shaderName + "/Lite/Transparent");
            ltslot      = Shader.Find("Hidden/" + shaderName + "/Lite/OnePassTransparent");
            ltsltt      = Shader.Find("Hidden/" + shaderName + "/Lite/TwoPassTransparent");

            ltslo       = Shader.Find("Hidden/" + shaderName + "/Lite/OpaqueOutline");
            ltslco      = Shader.Find("Hidden/" + shaderName + "/Lite/CutoutOutline");
            ltslto      = Shader.Find("Hidden/" + shaderName + "/Lite/TransparentOutline");
            ltsloto     = Shader.Find("Hidden/" + shaderName + "/Lite/OnePassTransparentOutline");
            ltsltto     = Shader.Find("Hidden/" + shaderName + "/Lite/TwoPassTransparentOutline");

            // 削除した特殊系バリエーション（Refraction / Fur / FurOnly / Gem / FakeShadow / Overlay）は
            // Shader.Find() しない（探すと null が入り続けるため）。

            ltsm        = Shader.Find(shaderName + "/lilToonMulti");
            ltsmo       = Shader.Find("Hidden/" + shaderName + "/MultiOutline");
            // MultiRefraction / MultiFur / MultiGem も削除済みのため参照しない。
        }

        // You can create a menu like this
        /*
        [MenuItem("Assets/ShadowEx/Convert material to custom shader", false, 1100)]
        private static void ConvertMaterialToCustomShaderMenu()
        {
            if(Selection.objects.Length == 0) return;
            ShadowExInspector inspector = new ShadowExInspector();
            for(int i = 0; i < Selection.objects.Length; i++)
            {
                if(Selection.objects[i] is Material)
                {
                    inspector.ConvertMaterialToCustomShader((Material)Selection.objects[i]);
                }
            }
        }
        */
    }
}
#endif