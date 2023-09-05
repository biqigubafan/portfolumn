Shader "Unlit/qiliu2"
{
    Properties
    {
        _MainTex ("Noise", 2d) = "white" {}
        _MaskTex ("Mask", 2d) = "white" {}
        [HDR]_Color1("Color1", Color) = (1.,1.,1.,0)
        [HDR]_Color2("Color2", Color) = (1.,1.,1.,0)
        _Min("Min", float) = 0.5
        _Max("Range", float) = 0.05
        _Cloundshape1("Cloundshape1", float) = 5
        _Cloundshape2("Cloundshape2", float) = 5
        _UVtilingOffset ("UVtilingandoffset", vector) = ( 1,  1, 0., 0.)
        _MasktilingOffset ("Masktilingandoffset", vector) = ( 1,  1, 0., 0.)
        _MaskUspeed("MaskUspeed", float) = 0
        _MaskVspeed("MaskVspeed", float) = 0
        _Params ("CloundsizeandFlux", vector) = ( 0.01,  1.5, 0., 0.)
        _Params2 ("CloundSpeed", vector) = ( 1.0,  1.0, 1.0, 1.0)
        _Cloudpow("Cloudpow", float) = 1
        _Minedge("Minedge", float) = 0
        _Maxedge("Maxedge", float) = 1
        [KeywordEnum(Cloud,Fire)] _ShaderEnum("Shape Type",int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
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
            #pragma shader_feature _SHADERENUM_FIRE _SHADERENUM_CLOUD
			#pragma multi_compile_fwdbase_fullshadows
			#pragma target 4.5



            //#pragma shader_feature _SHADERENUM_RED _SHADERENUM_GREEN _SHADERENUM_BLUE

            uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
            uniform sampler2D _MaskTex;
            float4 _Color1;
            float4 _Color2;
            float4 _Params;
            float4 _Params2;
            float4 _UVtilingOffset;
            float4 _MasktilingOffset;
            float _Cloundshape1;
            float _Cloundshape2;
            float _Min;
            float _Max;
            float _MaskUspeed;
            float _MaskVspeed;
            float _cloudpow;
            float _Minedge;
            float _Maxedge;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            float fbm( float2 p )
            {
                float2x2 m2=float2x2(0.8,-0.6,0.6,0.8);
                float f = 0.0;
                f += 0.5000*tex2D( _MainTex, p/256.0 ).x; p = mul(m2,p)*2.02;
                f += 0.2500*tex2D( _MainTex, p/256.0 ).x; p = mul(m2,p)*2.03;
                f += 0.1250*tex2D( _MainTex, p/256.0 ).x; p = mul(m2,p)*2.01;
                f += 0.0625*tex2D( _MainTex, p/256.0 ).x;
                return f/0.9375;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 q = i.uv+_UVtilingOffset.zw;
                q*=_UVtilingOffset.xy;
                //float2 p = -1.0 + 2.0 * q;
                //p.x *= iResolution.x/iResolution.y;
                //float2 mo = iMouse.xy/iResolution.xy;
	
                // camera
                //float3 col =  float3(0.,0.,0.);//texture( iChannel0, rd ).xyz;

                float col =  0;

                float3 blueSky = float3(0.3,.55,0.8);
                float3 redSky = float3(0.8,0.8,0.6);

                float cloudSize1 = _Params.x;
                float cloudSize2 = _Params.y;
                float cloudFlux1 = _Params.z;
                float cloudFlux2 = _Params.w;
                float2 cloudSpeed1= _Params2.xy;
                float2 cloudSpeed2= _Params2.zw;
                float Maxx=_Min+_Max;

                //float3 cloudColour = _Color.rgb;
        
                #if _SHADERENUM_CLOUD
		        float2 sc = cloudSize1 *_Time.y * q+cloudSpeed1*_Time.y;
		        float col1 = lerp( 0, 1, 0.5*smoothstep(_Min,Maxx,fbm(0.0002*sc+fbm(0.0001*sc*_Cloundshape1+_Time.y*cloudFlux1))));
        
                
                // cloud layer 2
                 
                sc = cloudSize2 *_Time.y * q+cloudSpeed2*_Time.y;
		        float col2 = lerp( 0, 1, 0.5*smoothstep(_Min,Maxx,fbm(0.0002*sc+fbm(0.0001*sc*_Cloundshape2+_Time.y*cloudFlux2))));
                col=max(col1,col2);
                #endif


                #if _SHADERENUM_FIRE
                // layer 1  
		        float2 sc = cloudSize1 *_Time.y * q+cloudSpeed1*_Time.y;
		        col = lerp( col, 1, 0.5*smoothstep(_Min,Maxx,fbm(0.0002*sc+fbm(0.0001*sc*_Cloundshape1+_Time.y*cloudFlux1))));
        
                
                // cloud layer 2           
                sc = cloudSize2 *_Time.y * q+cloudSpeed2*_Time.y;
		        col = lerp( col, 1, 0.5*smoothstep(_Min,Maxx,fbm(0.0002*sc+fbm(0.0001*sc*_Cloundshape2+_Time.y*cloudFlux2))));
                #endif

                

                col = clamp(col, 0., 1.);
                //col=pow(col,_cloudpow);
                col=(0.0 + (col - _Minedge) * (1.0) / (_Maxedge - _Minedge));
                col=saturate(col);
                //col = col*col*(3.0-2.0*col);

                float2 p = i.uv+_MasktilingOffset.zw;
                p*=_MasktilingOffset.xy;
                p.x+=_MaskUspeed*_Time.y;
                p.y+=_MaskVspeed*_Time.y;

               float4 fragColor = float4( lerp(_Color2.rgb, _Color1.rgb,col), col*tex2D(_MaskTex,p).r);

               return fragColor;
            }
            ENDCG
        }
    }
}
