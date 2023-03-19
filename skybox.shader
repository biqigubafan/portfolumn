Shader "Unlit/SkyboxProc"
{
    Properties
    {
        [Header(Stars Settings)]
        _Stars("Stars Texture", 2D) = "black" {}
        _StarsCutoff("Stars Cutoff",  Range(0, 1)) = 0.08
        _StarsSpeed("Stars Move Speed",  Range(0, 1)) = 0.3 
        _StarsSkyColor("Stars Sky Color", Color) = (0.0,0.2,0.1,1)
 
 
        [Header(Horizon Settings)]
        _OffsetHorizon("Horizon Offset",  Range(-1, 1)) = 0
        _HorizonIntensity("Horizon Intensity",  Range(0, 10)) = 3.3
        _SunSet("Sunset/Rise Color", Color) = (1,0.8,1,1)
        _SunsetColorDay("Sunset Day Color", Color) = (1,0.8,1,1)
        _SunSetColorNight("Sunset Night Color", Color) = (1,0.8,1,1)
        _HorizonColorDay("Day Horizon Color", Color) = (0,0.8,1,1)
        _HorizonColorNight("Night Horizon Color", Color) = (0,0.8,1,1)
 
         [Header(Sun Settings)]
         _SunColor("Sun Color", Color) = (1,1,1,1)
        _SunRadius("Sun Radius",  Range(0, 2)) = 0.1
 
        [Header(Moon Settings)]
        _MoonColor("Moon Color", Color) = (1,1,1,1)
        _MoonRadius("Moon Radius",  Range(0, 2)) = 0.15
        _MoonOffset("Moon Crescent",  Range(-1, 1)) = -0.1
 
        [Header(Day Sky Settings)]
        _DayTopColor("Day Sky Color Top", Color) = (0.4,1,1,1)
        _DayBottomColor("Day Sky Color Bottom", Color) = (0,0.8,1,1)
 
        [Header(Main Cloud Settings)]
        _BaseNoise("Base Noise", 2D) = "black" {}
        _Distort("Distort", 2D) = "black" {}
        _SecNoise("Secondary Noise", 2D) = "black" {}
        _BaseNoiseScale("Base Noise Scale",  Range(0, 1)) = 0.2
        _DistortScale("Distort Noise Scale",  Range(0, 1)) = 0.06
        _SecNoiseScale("Secondary Noise Scale",  Range(0, 1)) = 0.05
        _Distortion("Extra Distortion",  Range(0, 1)) = 0.1
        _Speed("Movement Speed",  Range(0, 10)) = 1.4
        _CloudCutoff("Cloud Cutoff",  Range(0, 1)) = 0.3
        _Fuzziness("Cloud Fuzziness",  Range(0, 1)) = 0.04
        _FuzzinessUnder("Cloud Fuzziness Under",  Range(0, 1)) = 0.01
        [Toggle(FUZZY)] _FUZZY("Extra Fuzzy clouds", Float) = 1
 
        [Header(Day Clouds Settings)]
        _CloudColorDayEdge("Clouds Edge Day", Color) = (1,1,1,1)
        _CloudColorDayMain("Clouds Main Day", Color) = (0.8,0.9,0.8,1)
        _CloudColorDayUnder("Clouds Under Day", Color) = (0.6,0.7,0.6,1)
        _Brightness("Cloud Brightness",  Range(1, 10)) = 2.5
        [Header(Night Sky Settings)]
        _NightTopColor("Night Sky Color Top", Color) = (0,0,0,1)
        _NightBottomColor("Night Sky Color Bottom", Color) = (0,0,0.2,1)
 
        [Header(Night Clouds Settings)]
        _CloudColorNightEdge("Clouds Edge Night", Color) = (0,1,1,1)
        _CloudColorNightMain("Clouds Main Night", Color) = (0,0.2,0.8,1)
        _CloudColorNightUnder("Clouds Under Night", Color) = (0,0.2,0.6,1)

        [Header(scattering atomasphere)]
        _PlanetRadius("PlanetRadius",  Float) = 6371000.0
        _AtmosphereHeight("AtmosphereHeight",  Float) = 80000.0
        _DensityScaleHeight("DensityScaleHeight",  Vector) = (7994, 1200, 0, 0)
        _ExtinctionM("ExtinctionM",  Vector)=(0.00002, 0.00002, 0.00002, 0.0)
        _ScatteringM("ScatteringM",  Vector)=(0.00002, 0.00002, 0.00002, 0.0)
        _MieG("MieG",  Float) = 0.76
        _MieColor("MieColor",  Color)=(1, 1, 1, 1)
        //_DensityScaleHeight("DensityScaleHeight",  Color) = (7994, 1200, 0, 0)
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" }
            LOD 100
 
            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                // make fog work
                #pragma multi_compile_fog
                #pragma shader_feature FUZZY
                #include "UnityCG.cginc"
                #define PI 3.14159265359

                struct appdata
                {
                    float4 vertex : POSITION;
                    float3 uv : TEXCOORD0;
                };
 
                struct v2f
                {
                    float3 uv : TEXCOORD0;
                    UNITY_FOG_COORDS(1)
                    float4 vertex : SV_POSITION;
                    float3 worldPos : TEXCOORD1;
                };
 
                sampler2D _Stars, _BaseNoise, _Distort, _SecNoise;
 
                float _SunRadius, _MoonRadius, _MoonOffset, _OffsetHorizon;
                float4 _SunColor, _MoonColor;
                float4 _DayTopColor, _DayBottomColor, _NightBottomColor, _NightTopColor;
                float4 _HorizonColorDay, _HorizonColorNight, _SunSet,_SunsetColorDay,_SunsetColorNight;
                float _StarsCutoff, _StarsSpeed, _HorizonIntensity;
                float _BaseNoiseScale, _DistortScale, _SecNoiseScale, _Distortion;
                float _Speed, _CloudCutoff, _Fuzziness, _FuzzinessUnder, _Brightness;
                float4 _CloudColorDayEdge, _CloudColorDayMain, _CloudColorDayUnder;
                float4 _CloudColorNightEdge, _CloudColorNightMain, _CloudColorNightUnder, _StarsSkyColor;

                float _PlanetRadius;
                float2 _DensityScaleHeight;
                float3 _ExtinctionM, _ScatteringM;
                float _MieG;
                float _AtmosphereHeight;
                float4 _MieColor;

                float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius)
                {
	                rayOrigin -= sphereCenter;
	                float a = dot(rayDir, rayDir);
	                float b = 2.0 * dot(rayOrigin, rayDir);
	                float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
	                float d = b * b - 4 * a * c;
	                if (d < 0)
	                {
		                return -1;
	                }
	                else
	                {
		                d = sqrt(d);
		                return float2(-b - d, -b + d) / (2 * a);
	                }
                }

                void ComputeOutLocalDensity(float3 position, float3 lightDir, out float localDPA, out float DPC)
                {
	                float3 planetCenter = float3(0,-_PlanetRadius,0);
	                float height = distance(position,planetCenter) - _PlanetRadius;
	                localDPA = exp(-(height/_DensityScaleHeight));

	                DPC = 0;
                }

                float MiePhaseFunction(float cosAngle)
                {
	                // r
	                float phase = (3.0 / (16.0 * PI)) * (1 + (cosAngle * cosAngle));

	                // m
	                float g = _MieG;
	                float g2 = g * g;
	                phase = (1.0 / (4.0 * PI)) * ((3.0 * (1.0 - g2)) / (2.0 * (2.0 + g2))) * ((1 + cosAngle * cosAngle) / (pow((1 + g2 - 2 * g * cosAngle), 3.0 / 2.0)));
	                return phase;
                }

                float4 IntegrateInscattering(float3 rayStart,float3 rayDir,float rayLength, float3 lightDir,float sampleCount)
                {
	                float3 stepVector = rayDir * (rayLength / sampleCount);
	                float stepSize = length(stepVector);

	                float scatterMie = 0;

	                float densityCP = 0;
	                float densityPA = 0;
	                float localDPA = 0;

	                float prevLocalDPA = 0;
	                float prevTransmittance = 0;
	
	                ComputeOutLocalDensity(rayStart,lightDir, localDPA, densityCP);
	
	                densityPA += localDPA*stepSize;
	                prevLocalDPA = localDPA;

	                float Transmittance = exp(-(densityCP + densityPA)*_ExtinctionM)*localDPA;
	
	                prevTransmittance = Transmittance;
	

	                for(float i = 1.0; i < sampleCount; i += 1.0)
	                {
		                float3 P = rayStart + stepVector * i;
		
		                ComputeOutLocalDensity(P,lightDir,localDPA,densityCP);
		                densityPA += (prevLocalDPA + localDPA) * stepSize/2;

		                Transmittance = exp(-(densityCP + densityPA)*_ExtinctionM)*localDPA;

		                scatterMie += (prevTransmittance + Transmittance) * stepSize/2;
		
		                prevTransmittance = Transmittance;
		                prevLocalDPA = localDPA;
	                }

	                scatterMie = scatterMie * MiePhaseFunction(dot(rayDir,-lightDir.xyz));

	                float3 lightInscatter = _ScatteringM*scatterMie;

	                return float4(lightInscatter,1);
                }
 
                v2f vert(appdata v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.uv = v.uv;
                    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                    UNITY_TRANSFER_FOG(o,o.vertex);
                    return o;
                }
 
                fixed4 frag(v2f i) : SV_Target
                {   
                    //云，太阳，月亮，星空，黑夜，白夜
                    //难点，云
                    //y值根据相对地平线偏移
                    float horizon = abs((i.uv.y * _HorizonIntensity) - _OffsetHorizon);
 
                    //天空的UV为xz轴除以y轴
                    float2 skyUV = i.worldPos.xz / i.worldPos.y;
 
                    //三张噪声图乘来乘去
                    float baseNoise = tex2D(_BaseNoise, (skyUV - _Time.x) * _BaseNoiseScale).x;
                    float noise1 = tex2D(_Distort, ((skyUV + baseNoise) - (_Time.x * _Speed)) * _DistortScale);
                    float noise2 = tex2D(_SecNoise, ((skyUV + (noise1 * _Distortion)) - (_Time.x * (_Speed * 0.5))) * _SecNoiseScale);
 
                    float finalNoise = saturate(noise1 * noise2) * 3 * saturate(i.worldPos.y-500);//低处没有云，乘y，还没有结束，因为只有一个层次
 
                    
                    //两个层次就得做两个smoothstep,第二个的第二个参数还必须比第一个小
                      #if FUZZY
                        float clouds = saturate(smoothstep(_CloudCutoff * baseNoise, _CloudCutoff * baseNoise + _Fuzziness, finalNoise));
                        float cloudsunder = saturate(smoothstep(_CloudCutoff* baseNoise, _CloudCutoff * baseNoise + _FuzzinessUnder + _Fuzziness, noise2) * clouds);
 
                      #else
                        float clouds = saturate(smoothstep(_CloudCutoff, _CloudCutoff + _Fuzziness, finalNoise));
                        float cloudsunder = saturate(smoothstep(_CloudCutoff, _CloudCutoff + _Fuzziness + _FuzzinessUnder , noise2) * clouds);
 
 
                      #endif

                    //两个随机数可以整三个颜色的变换，但是得同时计算黑夜和白天的
                    float3 cloudsColored = lerp(_CloudColorDayEdge, lerp(_CloudColorDayUnder, _CloudColorDayMain, cloudsunder), clouds) * clouds;
                    float3 cloudsColoredNight = lerp(_CloudColorNightEdge, lerp(_CloudColorNightUnder,_CloudColorNightMain , cloudsunder), clouds) * clouds;

                    //小细节，黑夜云越低越黑
                    cloudsColoredNight *= horizon;
 
                    //然后是黑夜和白天的变换，全靠satu(sun,y)
                    cloudsColored = lerp(cloudsColoredNight, cloudsColored, saturate(_WorldSpaceLightPos0.y)); // lerp the night and day clouds over the light direction
                    cloudsColored += (_Brightness * cloudsColored* horizon); // add some extra brightness
 
 
                    float cloudsNegative = (1 - clouds) * horizon;
                    // sun
                    //float sun = distance(i.uv.xyz, _WorldSpaceLightPos0);
                    //float sunDisc = 1 - (sun / _SunRadius);
                    //sunDisc = saturate(sunDisc * 50);

                    //
                    //Mie scattering
                    float3 scatteringColor = 0;

                    float3 rayStart = float3(0,10,0);
                    rayStart.y = saturate(rayStart.y);
                    float3 rayDir = normalize(i.uv.xyz);

                    float3 planetCenter = float3(0, -_PlanetRadius, 0);
                    float2 intersection = RaySphereIntersection(rayStart,rayDir,planetCenter,_PlanetRadius + _AtmosphereHeight);
                    float rayLength = intersection.y;

                    /*
                        intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);
                        if (intersection.x > 0)
	                        rayLength = min(rayLength, intersection.x*100);
                      */
                    

                    float4 inscattering = IntegrateInscattering(rayStart, rayDir, rayLength, -_WorldSpaceLightPos0.xyz, 16);
                    float3 sunDisc = inscattering;











 
                    // (crescent) moon,算负方向距离，一大一小相减，减的时候要saturate
                    float moon = distance(i.uv.xyz, -_WorldSpaceLightPos0);
                    float crescentMoon = distance(float3(i.uv.x + _MoonOffset, i.uv.yz), -_WorldSpaceLightPos0);
                    float crescentMoonDisc = 1 - (crescentMoon / _MoonRadius);
                    crescentMoonDisc = saturate(crescentMoonDisc * 50);
                    float moonDisc = 1 - (moon / _MoonRadius);
                    moonDisc = saturate(moonDisc * 50);
                    moonDisc = saturate(moonDisc - crescentMoonDisc);
                    
                    //乘1-云浓度，在云后面不显
                    float3 sunAndMoon = sunDisc*lerp(_SunSet,_MieColor,_WorldSpaceLightPos0.y) + (moonDisc * _MoonColor);
                    sunAndMoon *= cloudsNegative;
 
                    //stars
                    float3 stars = tex2D(_Stars, skyUV + (_StarsSpeed * _Time.x));
                    stars *= step(0,-_WorldSpaceLightPos0.y);
                    stars = step(_StarsCutoff, stars);
                    stars += (baseNoise * _StarsSkyColor);
                    stars *= cloudsNegative;
                    
                    //记住核心，每一步两个都算了，然后都乘了saturate(+-_WorldSpaceLightPos0.y),还有一些只有白天才有的东西就只乘saturate(_WorldSpaceLightPos0.y)
                    // gradient day sky
                    float3 gradientDay = lerp(_DayBottomColor, _DayTopColor, saturate(horizon));
 
                    // gradient night sky
                    float3 gradientNight = lerp(_NightBottomColor, _NightTopColor, saturate(horizon));
 
                    float3 skyGradients = lerp(gradientNight, gradientDay, saturate(_WorldSpaceLightPos0.y)) * cloudsNegative;
 
                    // horizon glow / sunset/rise
                    float sunset = saturate((1 - horizon) * saturate(_WorldSpaceLightPos0.y * 5));
                    float sunset1 =  saturate((1 - horizon)*saturate(_WorldSpaceLightPos0.y * 5))* _SunsetColorDay;
                    float sunset2 =  saturate((1 - horizon)*saturate(-_WorldSpaceLightPos0.y * 5))* _SunsetColorNight;
                    float3 sunsetColoured = sunset * _SunSet;
 
                    
                    float3 sunset3 = lerp(_SunSet, _HorizonColorDay,_WorldSpaceLightPos0.y);
                    float3 horizonGlow = saturate((1 - horizon * (5*pow((1-_WorldSpaceLightPos0.y),3))) * saturate(_WorldSpaceLightPos0.y * 10)) * sunset3;//_HorizonColorDay;// 
                    float3 horizonGlowNight = saturate((1 - horizon * 8) * saturate(-_WorldSpaceLightPos0.y * 10)) * _HorizonColorNight;//
                    horizonGlow += horizonGlowNight;

                    sunsetColoured=lerp(sunsetColoured, sunset1+sunset2, saturate(pow(abs(_WorldSpaceLightPos0.y),2)));
                    
 
                    // pragma multi_compile_fog UNITY_FOG_COORDS(1) UNITY_TRANSFER_FOG(o,o.vertex) UNITY_APPLY_FOG(i.fogCoord, combined)
 
                    float3 combined = skyGradients + sunAndMoon + sunsetColoured + stars + cloudsColored + horizonGlow;
                    UNITY_APPLY_FOG(i.fogCoord, combined);
                    return float4(combined,1);
 
           }
           ENDCG
       }
        }
}