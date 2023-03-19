Shader "Unlit/VolumetricLightingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Intensity("Intensity",float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define MAIN_LIGHT_CALCULATE_SHADOWS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
            #define STEP_TIME 64
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos:TEXCOORD1;
                float4 screenPos :TEXCOORD2;
            };

            TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float _Intensity;
            v2f vert (appdata v)
            {
                v2f o;
                
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                //计算屏幕坐标，范围（0，w),w存在w
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                //屏幕坐标（0，1)
                half2 screenPos = i.screenPos.xy / i.screenPos.w;
                
                float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture,sampler_CameraDepthTexture, screenPos).r;
                depth = Linear01Depth(depth, _ZBufferParams);

                
                //先假设都是能打到远平面上的，再乘线性（0，1）深度
                float2 positionNDC = screenPos * 2 - 1;
                //还原远平面到整数除法之前
                float3 farPosNDC = float3(positionNDC.xy,1)*_ProjectionParams.z;
                //再通过逆矩阵计算view空间坐标
                float4 viewPos = mul(unity_CameraInvProjection,farPosNDC.xyzz);
                //真正摄像机空间位置
                viewPos.xyz *= depth;
                //从摄像机空间还原到世界空间
                float4 worldPos = mul(UNITY_MATRIX_I_V,viewPos);
                
                //再采样距离上加噪声
                float noise = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, screenPos*3).r;
                float3 startPos = i.worldPos;
                float3 dir = normalize(worldPos - startPos);
                startPos += dir * noise;
                worldPos.xyz += dir * noise;
                float len = length(worldPos - startPos);
                float3 stepLen = dir * len / STEP_TIME;
                half3 color = 0;

                half3 sceneColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenPos).rgb;
                
                //每一步都通过光源的阴影贴图计算光照强度进行累加
                UNITY_LOOP
                for (int i = 0; i < STEP_TIME; i++)
                {
                    startPos += stepLen;
                    //根据世界坐标换算阴影贴图坐标，光源的！
                    float4 shadowPos = TransformWorldToShadowCoord(startPos);
                    float intensity = MainLightRealtimeShadow(shadowPos)*_Intensity;
                    color += intensity*_MainLightColor.rgb;
                }
                
                color /= STEP_TIME;
                color += sceneColor;
                return half4(color.xyz,1);
            }
            ENDHLSL
        }
    }
}