Shader "Unlit/xier"
{
    Properties
    {
        [HDR] _MainColor1 ("Main Color1", Color) = (1.0, 1.0, 1.0, 1.0)
        [HDR] _MainColor2 ("Main Color2", Color) = (1.0, 1.0, 1.0, 1.0)
        _MaskTex1 ("узуж1", 2d) = "white" {}
        _MaskTex2 ("узуж2", 2d) = "white" {}
        _Screamsize ("Screamsize", vector) = ( 800,  400, 0., 0.)
        _Speed ("Speed", float) = 1
        _Coloroffset ("Coloroffset", float) = 1
        _Colorscale ("Colorscale", float) = 1
        _fortimes ("Fortimes", float) = 24
        _distance ("distance", float) = -2
        //_CubeMap ("Cubemap", CUBE) = "" {}
        //_Scale("Scale",float)=1.0
        [KeywordEnum(Cube,Sphere)] _ShaderEnum("Shape Type",int) = 0
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

            #pragma shader_feature _SHADERENUM_CUBE _SHADERENUM_SPHERE

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

           //float burn;
           float3 _MainColor1;
           float3 _MainColor2;
           uniform sampler2D _MaskTex1;
           uniform sampler2D _MaskTex2;
           float4 _Screamsize;
           float _Speed;
           float _Coloroffset;
           float _Colorscale;
           float _fortimes;
           float _distance;

            float2x2 rot(float a)
            {
                float s=sin(a), c=cos(a);
                return float2x2(s, c, -c, s);
            }

            float map(float3 p,inout float burn)
            {
                #if _SHADERENUM_CUBE
                    float d = max(max(abs(p.x), abs(p.y)), abs(p.z)) - .5;
                #endif

                #if _SHADERENUM_SPHERE
                    float d = length(p) - .5;
                #endif

                burn = d;
    
                float2x2 rm = rot(-_Speed*_Time.y/3. + length(p));
                p.xy = mul(p.xy,rm); 
                p.zy = mul(p.zy,rm);

                float3 q = abs(p) - _Speed*_Time.y;
                q = abs(q - round(q));
    
                rm = rot(_Speed*_Time.y);
                q.xy = mul(q.xy,rm); 
                q.zy = mul(q.zy,rm);
    
                d = min(d, min(min(length(q.xy), length(q.yz)), length(q.xz)) + .01);
    
                burn = pow(d - burn, 2.);
    
                return d;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 rd = normalize(float3(2*_Screamsize.x*i.uv.x-_Screamsize.x,2*_Screamsize.y*i.uv.y-_Screamsize.y, _Screamsize.y));
                float3 ro = float3(0.,0., _distance);
                float2x2 r1 = rot(_Speed*_Time.y/4.), r2 = rot(_Speed*_Time.y/2.);
                rd.xz = mul(rd.xz,r1);
                ro.xz = mul(ro.xz,r1); 
                rd.yz = mul(rd.yz,r2);
                ro.yz = mul(ro.yz, r2);
                
                float burn=0.;
                float t = .0;
                float ii = _fortimes;
                for(;ii-->0.;)t += map(ro+rd*t,burn) / 2.;


                float colorint = max(max(1.-burn,exp(-t/2.)),exp(-t));
                float3 finalcolor=lerp(_MainColor2,_MainColor1,colorint*_Colorscale- _Coloroffset);
                float desaturateDot3 = dot( finalcolor, float3( 0.299, 0.587, 0.114 ));
                float a= max( saturate(1.-burn) , saturate( exp(-t/2.) ) );
                float b= max(a,saturate( exp(-t) ));
                return  float4(finalcolor,b*tex2D( _MaskTex1, i.uv).r*tex2D( _MaskTex2, i.uv).r );
            }
            ENDCG
        }
    }
}
