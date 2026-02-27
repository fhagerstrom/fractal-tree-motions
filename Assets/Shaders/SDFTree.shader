Shader "Custom/SDFTree"
{
    Properties
    {
        // // _BaseMap("Base Map", 2D) = "white" {}
        // _Threshold("Threshold", Range(0, 1)) = 0.5
        // _Smoothness("Band Smoothness", Range(0.001, 0.2)) = 0.02
        // _BranchCount("Branch Count", Range(1, 256)) = 256

        _TreeScale("Tree Scale", Float) = 1.0
        _Color("Color", Color) = (0, 0.5, 0, 1)
        _ShadowColor("Shadow Color", Color) = (0.05, 0.05, 0.05, 1)
        _LightDirection("Light Direction", Vector) = (0.3, 0.8, 0.0, 0)
        _Bands("Cel Shading Bands", Float) = 3.0
        _Edge("Edge", Float) = 0.01

        // CIRCLE SHAPE TESTING
        // _Center("Center (XY)", Vector) = (0, 0, 0, 0)
        // _Radius("Radius", Float) = 1.0
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
                // float3 normalOS : NORMAL;
                // float4 color : COLOR;
                // float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 positionOS : TEXCOORD1;
                // float2 uv : TEXCOORD2;
                // float4 color : COLOR;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _ShadowColor;
                float _Bands;
                float _Edge;
                int _BranchCount;
                float _TreeScale;
                float3 _LightDirection;

            CBUFFER_END
            
            float4 _BranchDataA[512]; // xy = start, zw = end
            float4 _BranchDataB[512]; // x = radius

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz); 
                OUT.positionWS = positionWS;
                OUT.positionOS = IN.positionOS.xyz;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                return OUT;
            }

            float sdCircle(float2 pos, float2 center, float radius)
            {
                return length(pos - center) - radius;
            }

            float sdCapsule(float2 pos, float2 a, float2 b, float radius)
            {
                float2 pa = pos - a; // Vector from point to a
                float2 ba = b - a; // Vector along capsule
                float height = saturate(dot(pa, ba) / dot(ba, ba)); // Project point onto capsule line and clamp to [0, 1]
                return length(pa - ba * height) - radius; // Distance from point to capsule surface
            }

            float sdTree(float2 pos)
            {
                float minDist = 1e5;

                float2 start;
                float2 end;
                float radius;

                for(int i = 0; i < _BranchCount; i++)
                {
                    start = _BranchDataA[i].xy;
                    end = _BranchDataA[i].zw;
                    radius = _BranchDataB[i].x;

                    float d = sdCapsule(pos, start, end, radius);
                    minDist = min(minDist, d);
                }

                return minDist;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 p = IN.positionOS.xy * _TreeScale; // Scale the tree in 2D object space

                float minDist = sdTree(p);

                float edgeWidth = fwidth(minDist) * _Edge;
                float mask = 1.0 - smoothstep(-edgeWidth, edgeWidth, minDist);

                if(mask <= 0.001)
                {
                    discard;
                }

                float eps = fwidth(minDist); // Epsilon - Small offset for gradient estimation

                // Sample SDF around current point
                float dx = sdTree(p + float2(eps, 0)) - minDist;
                float dy = sdTree(p + float2(0, eps)) - minDist;

                // Surface normal is the gradient of the SDF
                float2 normal2D = normalize(float2(dx, dy));

                // Convert normal to 3D
                float3 normalWS = normalize(float3(normal2D, 0));

                // CEL SHADING
                float ndotl = saturate(dot(normalWS, _LightDirection));
                float bands = _Bands;
                float cel = floor(ndotl * bands) / bands;

                float3 shadowColor = _ShadowColor.rgb;
                float3 litColor = _Color.rgb;

                float rimLighting = 1.0 - saturate(dot(normalWS, float3(0, 0, 1))); // Rim lighting

                // rimLighting = pow(rimLighting, 3.0); // Exponentiate for sharper rim

                float3 celColor = lerp(shadowColor, litColor, cel);

                // celColor += rimLighting * 0.2;

                return float4(celColor * mask, 1);

                // Debug draw
                // return float4(_BranchCount / 256.0, 0, 0, 1);
            }
            ENDHLSL
        }
    }
}
