Shader "Fluid/Smoke"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainTex2 ("Texture", 2D) = "white" {}
    }
    SubShader
    {
		
		//Pass0:Advection
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

			sampler2D VelocityTex;
			sampler2D VelocityDensityTex;
			float4 VelocityTex_TexelSize;
			float dt;
			float dissipation;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

			float4 bilerp(sampler2D sam, float2 p) {
				float4 st;
				st.xy = floor(p - 0.5) + 0.5;
				st.zw = st.xy + 1.0;

				float4 uv = st * VelocityTex_TexelSize.xyxy;
				float4 a = tex2D(sam, uv.xy);
				float4 b = tex2D(sam, uv.zy);
				float4 c = tex2D(sam, uv.xw);
				float4 d = tex2D(sam, uv.zw);
				float2 f = p - st.xy;
				return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
			}

            fixed4 frag (v2f i) : SV_Target
            {
				
				float2 coord = i.uv* VelocityTex_TexelSize.zw - dt * tex2D(VelocityTex, i.uv);
				float4 col = dissipation * bilerp(VelocityDensityTex, coord);
				col.a = 1.0;
				return col;
            }
            ENDCG
        }
		
		//Pass1:Splash
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D VelocityDensityTex;
			float3 color;
			float2 pointerpos;
			float radius;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float isColor;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			float3 hsv2rgb(float3 c) {
				float3 rgb = clamp(abs(fmod(c.x*6.0 + float3(0.0, 4.0, 2.0), 6) - 3.0) - 1.0, 0, 1);
				rgb = rgb * rgb*(3.0 - 2.0*rgb);
				return c.z * lerp(float3(1, 1, 1), rgb, c.y);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float2 p = i.uv - pointerpos.xy / _ScreenParams.xy;
				p.x *= (_ScreenParams.x / _ScreenParams.y);
				half3 splat = exp(-dot(p, p) / radius)*color *(1-isColor)+ exp(-dot(p, p) / radius)*hsv2rgb(float3(frac(_Time.x*5), 1,0.3))*isColor;
				half3 base = tex2D(VelocityDensityTex,i.uv).rgb;
				return half4(base + splat,1.);
			}
			ENDCG
		}

		//Pass2:Curl
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D VelocityTex;
			float4 VelocityTex_TexelSize;
			float2 TexelSize;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float L = tex2D(VelocityTex,i.uv - float2(VelocityTex_TexelSize.x,0.0f)).y;
				float R = tex2D(VelocityTex,i.uv + float2(VelocityTex_TexelSize.x, 0.0f)).y;
				float T = tex2D(VelocityTex, i.uv + float2(0.0f, VelocityTex_TexelSize.y)).x;
				float B = tex2D(VelocityTex, i.uv - float2(0.0f, VelocityTex_TexelSize.y)).x;
				float vorticity = 0.5f*(R - L - T + B);
				return float4(vorticity,0.,0.,1.);
			}
			ENDCG
		}

		//Pass3:Vorticity
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D VelocityTex;
			sampler2D CurlTex;
			float4 CurlTex_TexelSize;
			uniform half curl;
			uniform half dt;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float L = tex2D(CurlTex,i.uv - float2(CurlTex_TexelSize.x,0.0f)).x;
				float R = tex2D(CurlTex,i.uv + float2(CurlTex_TexelSize.x, 0.0f)).x;
				float T = tex2D(CurlTex, i.uv + float2(0.0f, CurlTex_TexelSize.y)).x;
				float B = tex2D(CurlTex, i.uv - float2(0.0f, CurlTex_TexelSize.y)).x;

				float C = tex2D(CurlTex,i.uv).x;

				float2 force = float2(abs(T) - abs(B),abs(R) - abs(L));
				force *= 1. / length(force + 0.00001) * curl * C;
				float2 vel = tex2D(VelocityTex, i.uv).xy;
				return float4(vel + force * dt ,0.0f,1.0f);
			}
			ENDCG
		}

		//Pass4:Divergence
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D VelocityTex;
			float4 VelocityTex_TexelSize;
			float2 TexelSize;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float T = tex2D(VelocityTex, i.uv + float2(0.0f, VelocityTex_TexelSize.y)).y;
				float B = tex2D(VelocityTex, i.uv + float2(0.0f, -VelocityTex_TexelSize.y)).y;
				float R = tex2D(VelocityTex, i.uv + float2(VelocityTex_TexelSize.x, 0.0f)).x;
				float L = tex2D(VelocityTex, i.uv + float2(-VelocityTex_TexelSize.x, 0.0f)).x;
				float divergence = 0.5f * (R - L + T - B);
				return float4(divergence, 0.0f, 0.0f, 0.0f);
			}
			ENDCG
		}

		//Pass5:Pressure
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D PressureTex;
			sampler2D DivergenceTex;
			float4 PressureTex_TexelSize;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float L = tex2D(PressureTex,saturate(i.uv - float2(PressureTex_TexelSize.x,0.0f))).x;
				float R = tex2D(PressureTex,saturate(i.uv + float2(PressureTex_TexelSize.x, 0.0f))).x;
				float T = tex2D(PressureTex,saturate(i.uv + float2(0.0f, PressureTex_TexelSize.y))).x;
				float B = tex2D(PressureTex,saturate(i.uv - float2(0.0f, PressureTex_TexelSize.y))).x;

				float C = tex2D(PressureTex,i.uv).x;

				float divergence = tex2D(DivergenceTex,i.uv).x;
				float pressure = (L + R + B + T - divergence) * 0.25 * 0.9999;
				return  float4(pressure,0.,0.,1.);
			}
			ENDCG
		}

		//Pass6:Subtract
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D PressureTex;
			sampler2D VelocityTex;
			float4 PressureTex_TexelSize;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float L = tex2D(PressureTex,saturate(i.uv - float2(PressureTex_TexelSize.x,0.0f))).x;
				float R = tex2D(PressureTex,saturate(i.uv + float2(PressureTex_TexelSize.x, 0.0f))).x;
				float T = tex2D(PressureTex,saturate(i.uv + float2(0.0f, PressureTex_TexelSize.y))).x;
				float B = tex2D(PressureTex,saturate(i.uv - float2(0.0f, PressureTex_TexelSize.y))).x;

				float2 velocity = tex2D(VelocityTex, i.uv).xy;
				velocity.xy -= float2(R - L,T - B);
			
				return float4(velocity,0.,1.);
			}
			ENDCG
		}
		Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex2;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex2, i.uv);
                // just invert the colors
                col.rgb = 1 - col.rgb;
                return col;
            }
            ENDCG
        }
		
    }
}

