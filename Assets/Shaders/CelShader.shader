Shader "Custom/CelShader"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        // _BaseMap("Base Map", 2D) = "white" {}
        _ShadowColor("Shadow Color", Color) = (0.05, 0.05, 0.05, 1)
        _Threshold("Threshold", Range(0, 1)) = 0.5
        _Smoothness("Band Smoothness", Range(0.001, 0.2)) = 0.02
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Blend One Zero
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float4 color : COLOR;
            };

            // TEXTURE2D(_BaseMap);
            // SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                // float4 _BaseMap_ST;
                float4 _ShadowColor;
                float _Threshold;
                float _Smoothness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformObjectToHClip(OUT.positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv = IN.uv;
                OUT.color = IN.color;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normal = normalize(IN.normalWS);
                float3 lightDirection = normalize(float3(0, 1, 0));

                float NdotL = saturate(dot(normal, lightDirection));
                float band = smoothstep(_Threshold - _Smoothness, _Threshold + _Smoothness, NdotL);

                float3 color = lerp(_ShadowColor.rgb, _BaseColor.rgb, band);

                // Optional height gradient
                float heightFactor = saturate(IN.positionWS.y * 0.1);
                color *= lerp(0.8, 1.2, heightFactor);

                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}
