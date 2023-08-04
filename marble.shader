Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _CubeMap ("Cubemap", CUBE) = "" {}
        _Scale("Scale",float)=1.0
        [KeywordEnum(Red,green,Blue)] _ShaderEnum("Color Type",int) = 0
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

            #pragma shader_feature _SHADERENUM_RED _SHADERENUM_GREEN _SHADERENUM_BLUE

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

            samplerCUBE _CubeMap;
            float _Scale;

            float2 cmul( float2 a, float2 b )  { return float2( a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x ); }
            float2 csqr( float2 a )  { return float2( a.x*a.x - a.y*a.y, 2.*a.x*a.y  ); }


            float2x2 rot(float a) {
	            return float2x2(cos(a),sin(a),-sin(a),cos(a));	
            }

            float2 iSphere( in float3 ro, in float3 rd, in float4 sph )//from iq
            {
	            float3 oc = ro - sph.xyz;
	            float b = dot( oc, rd );
	            float c = dot( oc, oc ) - sph.w*sph.w;
	            float h = b*b - c;
	            if( h<0.0 ) return float2(-1.0,-1.0);
	            h = sqrt(h);
	            return float2(-b-h, -b+h );
            }

            float map(in float3 p) {
	
	            float res = 0.;
	
                float3 c = p;
	            for (int i = 0; i < 10; ++i) {
                    p =.7*abs(p)/dot(p,p) -.7;
                    p.yz= csqr(p.yz);
                    p=p.zxy;
                    res += exp(-19. * abs(dot(p,c)));
        
	            }
	            return res/2.;
            }



            float3 raymarch( in float3 ro, float3 rd, float2 tminmax )
            {
                float t = tminmax.x;
                float dt = .02;
                //float dt = .2 - .195*cos(iTime*.05);//animated
                float3 col= float3(0.,0.,0.);
                float c = 0.;
                for( int i=0; i<128; i++ )
	            {
                    t+=dt*exp(-2.*c);
                    if(t>tminmax.y)break;
                
                    c = map(ro+t*rd);               
                    
                    #if _SHADERENUM_RED
                        col = .99*col+ .08*float3(c, 0, 0);//green
                    #endif

                    #if _SHADERENUM_GREEN
                        col = .99*col+ .08*float3(c*c*c, c, c*c);//green
                    #endif

                    #if _SHADERENUM_BLUE
                        col = .99*col+ .08*float3(c*c*c, c*c*c, c);//green
                    #endif
                    
                    //col = .99*col+ .08*float3(c*c*c, c*c, c);//blue
                }    
                return col;
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
                float time = _Time.y*2;
                float2 q = i.uv;    //fragCoord.xy / iResolution.xy;
                float2 p = -1.0 + 2.0 * q;
                p*= _Scale;
                float2 m = float2(0.,0.);
	            //if( iMouse.z>0.0 )m = iMouse.xy/iResolution.xy*3.14;
                m-=.5;

                // camera

                float3 ro = float3(4.,4.,4.);//初始表面点
                ro.yz=mul(ro.yz,rot(m.y));
                ro.xz=mul(ro.xz,rot(m.x+ 0.1*time));
                float3 ta = float3( 0.0 , 0.0, 0.0 );
                float3 ww = normalize( ta - ro );
                float3 uu = normalize( cross(ww,float3(0.0,1.0,0.0) ) );
                float3 vv = normalize( cross(uu,ww));
                float3 rd = normalize( p.x*uu + p.y*vv + 4.0*ww );

    
                float2 tmm = iSphere( ro, rd, float4(0.,0.,0.,2.) );

	            // raymarch
                float3 col = raymarch(ro,rd,tmm);
                if (tmm.x<0.)col = float3(0.0,0.0,0.0);//texCUBE(_CubeMap, rd).rgb;
                else {
                    float3 nor=(ro+tmm.x*rd)/2.;
                    nor = reflect(rd, nor);        
                    float fre = pow(.5+ clamp(dot(nor,rd),0.0,1.0), 3. )*1.3;
                    col += texCUBE(_CubeMap, nor).rgb * fre;
    
                }
	
	            // shade
    
                col =  .5 *(log(1.+col));
                col = clamp(col,0.,1.);
                #if _SHADERENUM_RED
                      float4 fragColor = float4( col, col.r );
                #endif

                #if _SHADERENUM_GREEN
                      float4 fragColor = float4( col, col.g );
                #endif

                #if _SHADERENUM_BLUE
                      float4 fragColor = float4( col, col.b );
                #endif
                return fragColor;
            }
            ENDCG
        }
    }
}
