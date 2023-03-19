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

                //������Ļ���꣬��Χ��0��w),w����w
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                //��Ļ���꣨0��1)
                half2 screenPos = i.screenPos.xy / i.screenPos.w;
                
                float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture,sampler_CameraDepthTexture, screenPos).r;
                depth = Linear01Depth(depth, _ZBufferParams);

                
                //�ȼ��趼���ܴ�Զƽ���ϵģ��ٳ����ԣ�0��1�����
                float2 positionNDC = screenPos * 2 - 1;
                //��ԭԶƽ�浽��������֮ǰ
                float3 farPosNDC = float3(positionNDC.xy,1)*_ProjectionParams.z;
                //��ͨ����������view�ռ�����
                float4 viewPos = mul(unity_CameraInvProjection,farPosNDC.xyzz);
                //����������ռ�λ��
                viewPos.xyz *= depth;
                //��������ռ仹ԭ������ռ�
                float4 worldPos = mul(UNITY_MATRIX_I_V,viewPos);
                
                //�ٲ��������ϼ�����
                float noise = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, screenPos*3).r;
                float3 startPos = i.worldPos;
                float3 dir = normalize(worldPos - startPos);
                startPos += dir * noise;
                worldPos.xyz += dir * noise;
                float len = length(worldPos - startPos);
                float3 stepLen = dir * len / STEP_TIME;
                half3 color = 0;

                half3 sceneColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenPos).rgb;
                
                //ÿһ����ͨ����Դ����Ӱ��ͼ�������ǿ�Ƚ����ۼ�
                UNITY_LOOP
                for (int i = 0; i < STEP_TIME; i++)
                {
                    startPos += stepLen;
                    //�����������껻����Ӱ��ͼ���꣬��Դ�ģ�
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