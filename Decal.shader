Shader "Custom/DecalShader"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    { 
      _LightStrength("Point/Spot Light Strength", Range(0,1)) = 0.5
    }
 
    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" }
    ZWrite On
        Blend SrcAlpha OneMinusSrcAlpha
 
        // uncomment to have selective decals
        // Stencil {
        // Ref 5
        // Comp Equal
        // Fail zero
        // }
 
// Then add the following to the shader you want the decals to show up on, not this one!:
    //  Stencil {
    //       Ref 5
    //          Comp always
    //      Pass Replace
    //      }
        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // This line defines the name of the vertex shader. 
            #pragma vertex vert
            // This line defines the name of the fragment shader. 
            #pragma fragment frag
 
            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
 
            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS   : POSITION;   
                float2 texcoord : TEXCOORD;              
            };
 
            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
                float2 uv : TEXCOORD;
                float4 screenUV : TEXCOORD1;
                float3 ray : TEXCOORD2;
            };            
 
            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
 
                    
                // The TransformObjectToHClip function transforms vertex positions
                // from object space to homogenous space
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
 
                OUT.uv = IN.texcoord;
                OUT.screenUV = ComputeScreenPos(OUT.positionHCS);
                OUT.ray = TransformWorldToView(TransformObjectToWorld(IN.positionOS)) * float3(1, 1, -1);
                // Returning the output.
                return OUT;
            }
 
            
        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_DEFINE_INSTANCED_PROP(sampler2D, _MainTex)
        UNITY_DEFINE_INSTANCED_PROP(float4, _Tint)
        UNITY_INSTANCING_BUFFER_END(Props)
 
        float _LightStrength;
 
         // The fragment shader definition.            
        half4 frag(Varyings i) : SV_Target
        {
            //将ray打到远平面
            i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
 
            //Screenspace UV
            float2 uv = i.screenUV.xy / i.screenUV.w;
            // read depth
            float depth = SampleSceneDepth(uv);
            depth = Linear01Depth(depth, _ZBufferParams);
 
       
            // reconstruct world space
            float4 vpos = float4(i.ray * depth, 1);//得到视角空间具体位置
            float4 wpos = mul(unity_CameraToWorld, vpos);//再整回去
            float3 opos = TransformWorldToObject(float4(wpos)).xyz;
            clip(float3(0.5, 0.5, 0.5) - abs(opos.xyz));
 
            // offset uvs
            i.uv = opos.xz + 0.5;
 
            // add texture from decal script
            float4 col = tex2D(UNITY_ACCESS_INSTANCED_PROP(Props, _MainTex), i.uv);
 
            clip(col.a - 0.1);
            col *= col.a;
 
            // get directional shadows
            float4 shadowCoord = TransformWorldToShadowCoord(wpos);
            ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
            float shadowStrength = GetMainLightShadowStrength();
            float ShadowAtten = SampleShadowmap(shadowCoord, TEXTURE2D_ARGS(_MainLightShadowmapTexture,sampler_MainLightShadowmapTexture),shadowSamplingData, shadowStrength, false);
        
            Light light = GetMainLight();
            // multiply with light color and shadows, ambient
            col.rgb *= (light.color * ShadowAtten) + unity_AmbientSky;
 
            // extra lights (point/spot)
            float3 extraLights;
            int pixelLightCount = GetAdditionalLightsCount();
            for (int j = 0; j < pixelLightCount; ++j) {
                Light lightA = GetAdditionalLight(j, wpos);
                float3 attenuatedLightColor = lightA.color * (lightA.distanceAttenuation * lightA.shadowAttenuation);
                extraLights += attenuatedLightColor;
            }
            extraLights *= _LightStrength;
            col.rgb+= extraLights;
            // add tinting and transparency
            col.rgb *= _Tint.rgb;
            col *= _Tint.a;    
            return col;
            }
            ENDHLSL
        }
    }
}