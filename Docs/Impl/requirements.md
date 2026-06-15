VRChatのアバター向けカスタムシェーダーに「SSAO」および「Contact Shadow（画面空間レイマーチング方式）」を実装するための仕様・設計ドキュメントとして整理しました。
Unityの組み込み機能（_CameraDepthTexture）を最大限活用し、GrabPass を使用しない軽量・高効率な設計をベースとしています。
------------------------------
## 仕様書：VRChatアバター向け画面空間疑似影（SSAO & Contact Shadow）実装仕様## 1. 共通システム要件
本機能は画面の深度バッファを利用するため、以下の共通前提条件を必要とします。
## 1.1 依存バッファ

* _CameraDepthTexture: カメラから見た画面全体の深度（Depth）情報。
* _CameraDepthTexture_TexelSize: 画面解像度の逆数（1ピクセルあたりのUV幅）。

## 1.2 頂点シェーダー（Vertex Shader）での準備
ピクセルシェーダー（PS）で画面空間のサンプリングを行うため、頂点空間から画面空間座標（Screen Position）を計算してPSへ渡します。

// 頂点シェーダーからピクセルシェーダーへの構造体（例）
struct v2f {
    float4 pos : SV_POSITION;
    float4 screenPos : TEXCOORD0; // 画面空間座標
    float3 worldPos : TEXCOORD1;  // 世界座標
    // ...その他のデータ
};

v2f vert(appdata_base v) {
    v2f o;
    o.pos = TransformObjectToHClip(v.vertex);
    // 画面空間座標の計算 (Unity標準マクロ)
    o.screenPos = ComputeScreenPos(o.pos);
    o.worldPos = TransformObjectToWorld(v.vertex);
    return o;
}

------------------------------
## 2. SSAO（Screen Space Ambient Occlusion）実装仕様## 2.1 アルゴリズム概要
現在のピクセルを中心として、画面空間上で円状にランダムサンプリングを行い、周囲のピクセル深度が「自身より手前にあるか」を判定して環境光を減衰させます。
## 2.2 主要パラメーター

* _SSAO_Radius: サンプリングを広げる画面空間上の半径。
* _SSAO_Samples: サンプリング数（負荷軽減のため 4 〜 8 を推奨）。
* _SSAO_Intensity: 影の濃さ（0 = 無効、1 = 最大）。
* _SSAO_Bias: 誤判定を防ぐための深度オフセット。

## 2.3 HLSL/Cg ロジック（ピクセルシェーダー内）

float CalculateSSAO(float4 screenPos) {
    // 投影空間の座標に変換 (w除算)
    float2 uv = screenPos.xy / screenPos.w;
    float currentDepth = LinearEyeDepth(screenPos.z / screenPos.w);

    // 擬似ランダムサンプリング用のオフセットベクトル（4方向の例）
    // 本来はサイン・コサインやノイズテクスチャで回転させるとノイズが分散します
    float2 offsets[4] = {
        float2(1, 0), float2(-1, 0), float2(0, 1), float2(0, -1)
    };

    float occlusion = 0.0;
    int sampleCount = 4;

    for (int i = 0; i < sampleCount; i++) {
        // サンプリング点のUV座標を計算
        float2 sampleUV = uv + offsets[i] * _SSAO_Radius * _CameraDepthTexture_TexelSize.xy;
        
        // サンプリング点の深度を取得
        float sampleDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampleUV));

        // 遮蔽判定：サンプリング点の手前の深さと自身の深さを比較
        // _SSAO_Bias で自己遮蔽（ジャギー）を防止
        if (sampleDepth + _SSAO_Bias < currentDepth) {
            // 近すぎる・遠すぎるオブジェクトによる異常な影（アーティファクト）を減衰
            float rangeCheck = smoothstep(0.0, 1.0, _SSAO_Radius / abs(currentDepth - sampleDepth));
            occlusion += rangeCheck;
        }
    }

    // 平均化して強度を適用
    occlusion = (occlusion / sampleCount) * _SSAO_Intensity;
    return 1.0 - occlusion; // 0(完全に影) 〜 1(日向) の係数を返す
}

------------------------------
## 3. Contact Shadow（接触影）実装仕様## 3.1 アルゴリズム概要
メインライトの方向（光が差し込む方向）に向かって、画面空間上で数ステップ分レイ（光線）を歩進させます（レイマーチング）。途中で画面の深度バッファが「レイの高さ」よりも手前を遮っていれば、光が届かない場所（＝影）と判定します。
## 3.2 主要パラメーター

* _ContactShadow_Steps: レイマーチングのループ回数（4 〜 6 を推奨）。
* _ContactShadow_Length: レイを伸ばす最大距離。
* _ContactShadow_Thickness: 遮蔽物と判定する厚みの閾値（裏側の突き抜け防止）。

## 3.3 HLSL/Cg ロジック（ピクセルシェーダー内）

float CalculateContactShadow(float4 screenPos, float3 worldPos) {
    // 画面空間の基本UVと深度
    float2 uv = screenPos.xy / screenPos.w;
    float currentDepth = LinearEyeDepth(screenPos.z / screenPos.w);

    // メインライトの方向を画面空間（UV空間）のベクトルに変換
    // ※Unity環境に応じて _MainLightPosition.xyz または _WorldSpaceLightPos0.xyz を使用
    float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
    
    // 世界座標の少し先（ライト方向）の位置をクリップ空間に変換し、画面空間の移動量を割り出す
    float4 rayStartCS = TransformWorldToHClip(worldPos);
    float4 rayEndCS   = TransformWorldToHClip(worldPos + lightDir * _ContactShadow_Length);
    
    float2 rayStartUV = rayStartCS.xy / rayStartCS.w;
    float2 rayEndUV   = rayEndCS.xy / rayEndCS.w;
    float2 rayDirUV   = (rayEndUV - rayStartUV) / _ContactShadow_Steps;

    // 深度方向（リニア深度空間）の1ステップあたりの移動量
    float startLinearDepth = LinearEyeDepth(rayStartCS.z / rayStartCS.w);
    float endLinearDepth   = LinearEyeDepth(rayEndCS.z / rayEndCS.w);
    float stepDepth = (endLinearDepth - startLinearDepth) / _ContactShadow_Steps;

    float shadow = 1.0; // 1 = 影なし

    // レイマーチング ループ
    for (int i = 1; i <= _ContactShadow_Steps; i++) {
        float2 sampleUV = uv + rayDirUV * i;
        float testRayDepth = currentDepth + stepDepth * i;

        // 画面外に出ていたらループを抜ける
        if (sampleUV.x < 0 || sampleUV.x > 1 || sampleUV.y < 0 || sampleUV.y > 1) break;

        // その点の実際の深度バッファ
        float sceneDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampleUV));

        // 判定：レイの仮想の深さよりも、実際のオブジェクト（sceneDepth）が手前（カメラ寄り）にあるか
        if (sceneDepth < testRayDepth) {
            // 厚みの概念を入れ、背景の壁などが遥か手前にある場合の誤判定（不正な影）を防ぐ
            if (testRayDepth - sceneDepth < _ContactShadow_Thickness) {
                shadow = 0.0; // 遮蔽物を検知（影確定）
                break;        // 早期抜け（これ以上計算しない）
            }
        }
    }

    return shadow;
}

------------------------------
## 4. パフォーマンス最適化と統合（Integration）## 4.1 ピクセルシェーダーでの最終適用
計算された2つの影係数は、最終的なカラー出力直前でライティング（環境光・ディフューズ）に乗算します。

fixed4 frag(v2f i) : SV_Target {
    // ベースカラーや通常のライティング計算
    fixed4 col = tex2D(_MainTex, i.screenPos.xy / i.screenPos.w);
    float3 lighting = CalculateStandardLighting(i); // 既存のライト計算

    // 本仕様の影を計算
    float ssao = CalculateSSAO(i.screenPos);
    float contactShadow = CalculateContactShadow(i.screenPos, i.worldPos);

    // 適用
    lighting *= ssao;          // 環境光や全体に効かせる
    lighting *= contactShadow; // メインライトによる局所的な影

    col.rgb *= lighting;
    return col;
}

## 4.2 VRChat向けの軽量化テクニック

   1. ループ回数の制限: _SSAO_Samples と _ContactShadow_Steps は合計で最大でも「12」以下に収まるように調整してください。これ以上増やすと、多人数インスタンスで顕著な重さの原因になります。
   2. ディザリング（Dithering）の導入: サンプリング数が少ないと影にハッキリとした「帯（バンディング）」が見えてしまいます。画面空間のピクセル座標（i.pos.xy）を元にした疑似ランダムノイズ（ディザ）をサンプリングベクトルに加算することで、少ないループ数でも影をきれいにボカす（グラデーションに見せる）ことができます。

------------------------------
このドキュメントをベースに、まずは数点の固定サンプルから実装を始めるとデバッグがスムーズです。実際のコードに組み込むにあたって、「ノイズ（ディザリング）を適用して影を滑らかにする具体的なコード」や、「Fallback（深度バッファが取得できないワールドでの挙動制御）」の処理も追加で必要であれば、続けて組み方をご提案できますが、いかがでしょうか？

