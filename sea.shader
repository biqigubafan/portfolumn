Shader "Unlit/sea"
{
	Properties
	{
    	_lightPos("lightPos", Vector) = (0 , 1, 0, 0)

		 [Header(Foam)]
        _FoamTexture("Foam texture", 2D) = "white" {} 
        _FoamTextureSpeedX("Foam texture speed X", float) = 0
        _FoamTextureSpeedY("Foam texture speed Y", float) = 0
        _FoamLinesSpeed("Foam lines speed", float) = 0
        _FoamIntensity("Foam intensity", float) = 1
		_FoamThreshold("Foam threshold", float) = 0

		_RenderTexture("Render texture", 2D) = "black" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		Blend SrcAlpha OneMinusSrcAlpha 

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(4)
				float4 vertex : SV_POSITION;

				float3 worldNormal : TEXCOORD1;
				float4 projPos : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
			};

			
			sampler2D _ReflectTex;
			uniform float4 _lightPos;	

			sampler2D _FoamTexture;
			float4 _FoamTexture_ST;
			float _FoamTextureSpeedX;
			float _FoamTextureSpeedY;
			float _FoamLinesSpeed;
			float _FoamIntensity;
			float _FoamThreshold;

			uniform float3 _CamPosition;
			sampler2D _RenderTexture;
			uniform float _CamSize;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				
				o.projPos = ComputeScreenPos(o.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.worldNormal = UnityObjectToWorldNormal(v.normal); 
				COMPUTE_EYEDEPTH(o.projPos.z);
				return o;
			}
			
			fixed4 cosine_gradient(float x,  fixed4 phase, fixed4 amp, fixed4 freq, fixed4 offset){
				const float TAU = 2. * 3.14159265;
  				phase *= TAU;
  				x *= TAU;

  				return fixed4(
    				offset.r + amp.r * 0.5 * cos(x * freq.r + phase.r) + 0.5,
    				offset.g + amp.g * 0.5 * cos(x * freq.g + phase.g) + 0.5,
    				offset.b + amp.b * 0.5 * cos(x * freq.b + phase.b) + 0.5,
    				offset.a + amp.a * 0.5 * cos(x * freq.a + phase.a) + 0.5
  				);
			}
			fixed3 toRGB(fixed3 grad){
  				 return grad.rgb;
			}
			float2 rand(float2 st, int seed)
			{
				float2 s = float2(dot(st, float2(127.1, 311.7)) + seed, dot(st, float2(269.5, 183.3)) + seed);
				return -1 + 2 * frac(sin(s) * 43758.5453123);
			}
			float noise(float2 st, int seed)
			{
				st.y += _Time[1];

				float2 p = floor(st);
				float2 f = frac(st);
 
				float w00 = dot(rand(p, seed), f);
				float w10 = dot(rand(p + float2(1, 0), seed), f - float2(1, 0));
				float w01 = dot(rand(p + float2(0, 1), seed), f - float2(0, 1));
				float w11 = dot(rand(p + float2(1, 1), seed), f - float2(1, 1));
				
				float2 u = f * f * (3 - 2 * f);
 
				return lerp(lerp(w00, w10, u.x), lerp(w01, w11, u.x), u.y);
			}
			float3 swell(float3 normal , float3 pos , float anisotropy){
				float height = noise(pos.xz * 0.1,0);
				height *= anisotropy ;
				normal = normalize(
					cross ( 
						float3(0,ddy(height),1),
						float3(1,ddx(height),0)
					)
				);
				return normal;
			}

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);	
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = 0;

    			float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float partZ = i.projPos.z;
				float volmeZ = saturate((sceneZ - partZ)/10.0f);

				const fixed4 phases = fixed4(0.28, 0.50, 0.07, 0.);
				const fixed4 amplitudes = fixed4(4.02, 0.34, 0.65, 0.);
				const fixed4 frequencies = fixed4(0.00, 0.48, 0.08, 0.);
				const fixed4 offsets = fixed4(0.00, 0.16, 0.00, 0.);

				fixed4 cos_grad = cosine_gradient(1-volmeZ, phases, amplitudes, frequencies, offsets);
  				cos_grad = clamp(cos_grad, 0., 1.);
  				col.rgb = toRGB(cos_grad);
					
				half3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

				//各向异性
				float3 v = i.worldPos - _WorldSpaceCameraPos;
				float anisotropy = saturate(1/(ddy(length ( v.xz )))/5);

				//使用perlin生成高度图，再用ddy,ddx将高度图转化为法线形式，perlin函数随着时间发生变化
				float3 swelledNormal = swell(i.worldNormal , i.worldPos , anisotropy);

				//反射采样天空核，bling-phong
                //half3 reflDir = reflect(-worldViewDir, swelledNormal);
				//fixed4 reflectionColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0);
				half2 screenPos = i.projPos.xy / i.projPos.w;
				fixed4 reflectionColor = fixed4(tex2D(_ReflectTex, screenPos).rgb,1);
				
				//采样噪声图生成泡沫
				float2 rtUV = (i.worldPos.xz - _CamPosition.xz)/(2 * _CamSize);
				rtUV += 0.5;
				fixed4 rt = tex2D(_RenderTexture, rtUV);
				float foamDiff = saturate((sceneZ - i.projPos.w) / _FoamThreshold);
				foamDiff *= (1.0 - rt.b);
				float foamTex = tex2D(_FoamTexture, i.worldPos.xz * _FoamTexture_ST.xy + _Time.y * float2(_FoamTextureSpeedX, _FoamTextureSpeedY));
				float foam = step(foamDiff-saturate( sin( (foamDiff + _Time.y * _FoamLinesSpeed) * 8 * UNITY_PI )*(1-foamDiff)  ),0.07+foamTex*foamDiff);

				// fresnel reflect 
				float f0 = 0.02;
    			float vReflect = f0 + (1-f0) * pow(
					(1 - dot(worldViewDir,swelledNormal)),
				5);
				vReflect = saturate(vReflect * 2.0);

				//根据菲涅尔决定反射不反射
				col = lerp(col , reflectionColor , vReflect)+ foam * _FoamIntensity;

				//根据深浅决定深度
				float alpha = saturate(volmeZ);
				
  				col.a = alpha;

				return col;
			}
			ENDCG
		}
	}
}
