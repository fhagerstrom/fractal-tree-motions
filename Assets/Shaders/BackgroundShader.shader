Shader "Custom/BackgroundShader"
{
    Properties
    {
        _TopColor("Top Color", Color) = (0.1, 0.2, 0.5, 1)
        _BottomColor("Bottom Color", Color) = (0.5, 0.7, 1.0, 1)
        _NoiseScale("Noise Scale", Float) = 2.0
        _NoiseStrength("Noise Strength", Float) = 0.25
        _Bands("Bands", Float) = 30.0

    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _TopColor;
                float4 _BottomColor;
                float _NoiseScale;
                float _NoiseStrength;
                float _Bands;
            CBUFFER_END

            // Hash function
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            // Value Noise
            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                float a = hash(i);
                float b = hash(i + float2(1.0, 0.0));
                float c = hash(i + float2(0.0, 1.0));
                float d = hash(i + float2(1.0, 1.0));

                float2 u = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv;

                float t = _Time.y * 0.1;

                float n1 = noise(uv * _NoiseScale + t);
                float n2 = noise(uv * (_NoiseScale * 0.5) - t * 0.5);
                float n = (n1 + n2) * 0.5;

                float warp = (n - 0.5) * 0.2;
                float gradient = saturate((uv.y + uv.x * 0.3) + warp);

                gradient = floor(gradient * _Bands) / _Bands;

                float4 color = lerp(_BottomColor, _TopColor, gradient);

                color.rgb += (n - 0.5) * _NoiseStrength;

                float horizon = smoothstep(0.1, 0.35, uv.y) * (1.0 - smoothstep(0.35, 0.6, uv.y));
                color.rgb += horizon * 0.1;

                float2 centerUV = uv - 0.5;
                float vignette = 1.0 - dot(centerUV, centerUV) * 1.5;
                color.rgb *= vignette;

                return color;
            }
            ENDHLSL
        }
    }
}
