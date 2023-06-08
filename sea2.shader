Shader "Unlit/sea2"
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
		_ZThreshold("Z threshold", float) = 10
		_Wavedir1("Wave1dir1", Vector) = (1, 0, 1 ,0)
		_Wavedir2("Wave1dir2", Vector) = (1, 0, 1 ,0)
		_Wavedir3("Wave1dir3", Vector) = (1, 0, 1 ,0)
		_Waveparam1("Waveparam1", Vector) = (1, 0, 1 ,0)
		_Waveparam2("Waveparam2", Vector) = (1, 0, 1 ,0)
		_Waveparam3("Waveparam3", Vector) = (1, 0, 1 ,0)

		_RenderTexture("Render texture", 2D) = "black" {}

		[Header(Caustics)]
		_CausticsTex("Caustics (RGB)", 2D) = "white" {}
        
		// Tiling X, Tiling Y, Offset X, Offset Y
		_Caustics1_ST("Caustics 1 ST", Vector) = (1,1,0,0)
		_Caustics2_ST("Caustics 1 ST", Vector) = (1,1,0,0)
		// Speed X, Speed Y
		_Caustics1_Speed("Caustics 1 Speed", Vector) = (1, 1, 0 ,0)
		_Caustics2_Speed("Caustics 2 Speed", Vector) = (1, 1, 0 ,0)
		_CausticsThreshold("Caustics threshold", float) = 0

		//_TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
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
			#define PI 3.1415926
			
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

			sampler2D _CausticsTex;
			float4 _Caustics1_ST;
			float4 _Caustics2_ST;
			float4 _Caustics1_Speed;
			float4 _Caustics2_Speed;
			float _CausticsThreshold;

			sampler2D _FoamTexture;
			float4 _FoamTexture_ST;
			float _FoamTextureSpeedX;
			float _FoamTextureSpeedY;
			float _FoamLinesSpeed;
			float _FoamIntensity;
			float _FoamThreshold;
			float _ZThreshold;
			float4 _Wavedir1,_Wavedir2,_Wavedir3,_Waveparam1,_Waveparam2,_Waveparam3;

			uniform float3 _CamPosition;
			sampler2D _RenderTexture;
			uniform float _CamSize;

			void GerstnerWave_float (
				float4 waveDir, float4 waveParam, float3 p, out float3 delta_pos, out float3 delta_normalWS
			) {
				// waveParam : steepness, waveLength, speed, amplify
				float steepness = waveParam.x;
				float wavelength = waveParam.y;
				float speed = waveParam.z;
				float amplify = waveParam.w;
				float2 d = normalize(waveDir.xz);

				float w = 2 * 3.1415 / wavelength;
				float f = w * (dot(d, p.xz) - _Time.y * speed);
				float sinf = sin(f);
				float cosf = cos(f);

				steepness = clamp(steepness, 0, 1 / (w*amplify));

				delta_normalWS = float3(
					- amplify * w * d.x * cosf,
					- steepness * amplify * w * sinf,
					- amplify * w * d.y * cosf
				);

				delta_pos = float3(
					steepness * amplify * d.x * cosf,
					amplify * sinf,
					steepness * amplify * d.y * cosf
				);
			}

			v2f vert (appdata v)
			{
				v2f o;
				//o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				
				
				//范围（0，w)
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.worldNormal = UnityObjectToWorldNormal(v.normal); 
				float3 delta_pos1=0, delta_pos2=0, delta_pos3=0;
				float3 delta_normalWS1=0, delta_normalWS2=0, delta_normalWS3=0;
				GerstnerWave_float(_Wavedir1,_Waveparam1,o.worldPos,delta_pos1,delta_normalWS1);
				GerstnerWave_float(_Wavedir2,_Waveparam2,o.worldPos,delta_pos2,delta_normalWS2);
				GerstnerWave_float(_Wavedir3,_Waveparam3,o.worldPos,delta_pos3,delta_normalWS3);

				o.worldPos+=delta_pos1;
				o.worldPos-=delta_pos2;
				o.worldPos+=delta_pos3;

				o.vertex=mul(unity_MatrixVP, float4(o.worldPos, 1.0));
				o.projPos = ComputeScreenPos(o.vertex);

				COMPUTE_EYEDEPTH(o.projPos.z);
				UNITY_TRANSFER_FOG(o,o.vertex);
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
				float volmeZ = saturate((sceneZ - partZ)/_ZThreshold);

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
				float foam = step(foamDiff-saturate( sin( (foamDiff + _Time.y * _FoamLinesSpeed) * 1.5 * UNITY_PI )*(1-foamDiff)  ),0.07+foamTex*foamDiff);

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

				fixed2 uv1 = i.worldPos.xz * _Caustics1_ST.xy + _Caustics1_ST.zw;
				uv1 += _Caustics1_Speed * _Time.y;
				fixed2 uv2 = i.worldPos.xz * _Caustics2_ST.xy + _Caustics2_ST.zw;
				uv1 += _Caustics2_Speed * _Time.y;
				fixed3 caustics1 = tex2D(_CausticsTex, uv1).rgb;
				fixed3 caustics2 = tex2D(_CausticsTex, uv2).rgb;
				float causticsDiff = 1-saturate((sceneZ - i.projPos.w) / _CausticsThreshold);

				// Add
				col.rgb += min(caustics1,caustics2)*causticsDiff;

				return col;
			}
			ENDCG
		}
	}
}
