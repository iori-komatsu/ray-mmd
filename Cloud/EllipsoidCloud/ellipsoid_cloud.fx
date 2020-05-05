#include "../../shader/common.fxsub"
#include "../../shader/math.fxsub"
#include "../../shader/gbuffer.fxsub"
#include "../../shader/gbuffer_sampler.fxsub"

////////////////////////////////////////////////////////////////////////////////////////////

// Code from by inigo quilez - iq/2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// https://www.shadertoy.com/view/4ttSWf

//==========================================================================================
// hashes
//==========================================================================================

float hash1(float2 p) {
    p  = 50.0*frac( p*0.3183099 );
    return frac( p.x*p.y*(p.x+p.y) );
}

float hash1(float n) {
    return frac( n*17.0*frac( n*0.3183099 ) );
}

//==========================================================================================
// noises
//==========================================================================================

float noise( in float3 x )
{
    float3 p = floor(x);
    float3 w = frac(x);
    
    float3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    
    float n = p.x + 317.0*p.y + 157.0*p.z;
    
    float a = hash1(n+0.0);
    float b = hash1(n+1.0);
    float c = hash1(n+317.0);
    float d = hash1(n+318.0);
    float e = hash1(n+157.0);
	float f = hash1(n+158.0);
    float g = hash1(n+474.0);
    float h = hash1(n+475.0);

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z);
}

//==========================================================================================
// fbm constructions
//==========================================================================================

const float3x3 m3  = float3x3( 0.00,  0.80,  0.60,
                              -0.80,  0.36, -0.48,
                              -0.60, -0.48,  0.64 );
const float3x3 m3i = float3x3( 0.00, -0.80, -0.60,
                               0.80,  0.36, -0.48,
                               0.60, -0.48,  0.64 );
const float2x2 m2 = float2x2(  0.80,  0.60,
                              -0.60,  0.80 );
const float2x2 m2i = float2x2( 0.80, -0.60,
                               0.60,  0.80 );

//------------------------------------------------------------------------------------------

float fbm_4(in float3 x) {
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    for(int i=0; i<4; i++) {
        float n = noise(x);
        a += b*n;
        b *= s;
        x = f*mul(m3, x);
    }
	return a;
}

////////////////////////////////////////////////////////////////////////////////////////////

float3 mCloudPosition : CONTROLOBJECT<string name = "(self)"; string item = "Position";>;
float3 mCloudRadius   : CONTROLOBJECT<string name = "(self)"; string item = "Radius";>;
float mCloudCutoffP  : CONTROLOBJECT<string name = "(self)"; string item = "Cutoff+";>;
float mCloudCutoffM  : CONTROLOBJECT<string name = "(self)"; string item = "Cutoff-";>;
float mCloudDensityP : CONTROLOBJECT<string name = "(self)"; string item = "Density+";>;
float mCloudDensityM : CONTROLOBJECT<string name = "(self)"; string item = "Density-";>;
float mCloudBrightnessP : CONTROLOBJECT<string name = "(self)"; string item = "Brightness+";>;
float mCloudBrightnessM : CONTROLOBJECT<string name = "(self)"; string item = "Brightness-";>;

static float mCloudCutoff  = lerp(lerp(0.1, 1.0, mCloudCutoffP), 0.0, mCloudCutoffM);
static float mCloudDensity = lerp(lerp(0.2, 1.0, mCloudDensityP), 0.0, mCloudDensityM);
static float mCloudBrightness = lerp(lerp(0.4, 2.0, mCloudBrightnessP), 0.0, mCloudBrightnessM);

// 二次方程式 ax^2 + 2bx + c = 0 の解を求める。一次の係数が 2b であることに注意。
inline float2 SolveQuadraticEquation2B(float a, float b, float c, out float disc) {
	disc = b*b - a*c;
	float sd = sqrt(disc);
	return float2((-b-sd)/a, (-b+sd)/a);;
}

// レイと楕円体の交点を求める。
float3 RayEllipsoidIntersection(float3 cameraPos, float3 rayDir, float3 radius, out bool hit) {
	float disc;
	float3 r0 = cameraPos / radius;
	float3 rd = rayDir / radius;
	float2 s = SolveQuadraticEquation2B(
		dot(rd, rd), dot(r0, rd), dot(r0, r0) - 1.0, disc);
	if (disc < 0) {
		hit = false;
		return float3(0, 0, 0);
	}

	float t;
	if (s.x >= 0) {
		t = s.x;
	} else if (s.y >= 0) {
		t = s.y;
	} else {
		hit = false;
		return float3(0, 0, 0);
	}

	hit = true;
	return float3(cameraPos + t*rayDir);
}

// レイと平面と交点を求める
float3 RayPlaneIntersection(float3 cameraPos, float3 rayDir, float3 planePoint, float3 planeNormal) {
	float denom = dot(rayDir, planeNormal);
	float t = dot(planePoint - cameraPos, planeNormal) / denom;
	return cameraPos + t*rayDir;
}

float Ellipsoid(float3 p, float3 radius) {
	return dot(p / radius, p / radius) - 1.0;
}

float OpticalDepthAt(float3 p, float interval) {
	// ノイズを生成
	float3 hashP = 5 * p / min(mCloudRadius.x, min(mCloudRadius.y, mCloudRadius.z));
	float r = max(fbm_4(hashP) - mCloudCutoff, 0.0);

	// 中心なら0、外周部なら1
	float u = saturate(Ellipsoid(p, mCloudRadius) + 1.0);

	// ガウス分布っぽい濃度分布にする
	float baseDensity = max(mCloudDensity * exp(-7*u*u) - 0.01, 0.0);

	return r * baseDensity * interval;
}

float LinearDepth(float3 p, float3 cameraPos, float3 cameraDir) {
	return dot(p - cameraPos, cameraDir);
}

float4 CastRay(
	float3 cameraPos,
	float3 rayDir,
	float3 cameraDir,
	float  maxDepth
) {
	bool willHit;
	RayEllipsoidIntersection(cameraPos, rayDir, mCloudRadius, willHit);
	if (!willHit)  {
		return float4(-1, -1, -1, -1);
	}

	static const int N_LAYERS = 64;
	static const int N_LIGHT_SAMPLES = 2;

	// 楕円上の点の中で最も深度が浅い点を求める
	float3 frontDir = normalize(-cameraDir * mCloudRadius * mCloudRadius);
	float3 frontPoint = mCloudRadius * frontDir;

	float width = length(frontPoint) * 2;
	float layerInterval = width / (N_LAYERS - 1);

	float opticalDepth = 0;
	float scatteredLight = 0;
	int nActiveLayers = 0;

	[fastopt]
	for (int i = 0; i < N_LAYERS; i++) {
		// レイがi番目のレイヤーとぶつかる点を求める
		float3 layerPoint = frontPoint + (i * layerInterval) * cameraDir;
		float3 ithPoint = RayPlaneIntersection(cameraPos, rayDir, layerPoint, cameraDir);

		float depth = LinearDepth(ithPoint, cameraPos, cameraDir);

		// 球の内側であれば光学的深さを加算する
		if (depth <= maxDepth) {
			opticalDepth += OpticalDepthAt(ithPoint, layerInterval);

			// In-Scattering を計算する
			float lightSampleInterval = dot(mCloudRadius, float3(1, 1, 1)) * 0.1 / (N_LIGHT_SAMPLES + 1);
			float lightDirOpticalDepth = 0;
			for (int j = 0; j < N_LIGHT_SAMPLES; j++) {
				float3 samplePoint = ithPoint + (j + 1) * lightSampleInterval * -SunDirection;
				if (Ellipsoid(samplePoint, mCloudRadius) < EPSILON) {
					lightDirOpticalDepth += OpticalDepthAt(samplePoint, lightSampleInterval);
				}
			}
			// ithPoint に入射する光の量が exp(-lightDirOpticalDepth) で、
			// ithPoint から cameraPos まで届く光がその exp(-opticalDepth) 倍になる
			scatteredLight += exp(-lightDirOpticalDepth-opticalDepth);

			nActiveLayers++;
		}
	}
	scatteredLight /= nActiveLayers;

	return float4(SunColor * mCloudBrightness * scatteredLight, 1.0 - exp(-opticalDepth));
}

// World空間におけるカメラとレイの位置や向きを求める。
// レイの向きは現在描画中のピクセルの方向を指していて、
// カメラの向きは現在描画中のピクセルとは関係なく画面の中央を指している。
void SetupCameraAndRay(float2 coord, out float3 oCameraPos, out float3 oCameraDir, out float3 oRayDir) {
	float2 p = (coord.xy - 0.5) * 2.0;
	oCameraPos = CameraPosition - mCloudPosition;
	oCameraDir = normalize(matView._13_23_33 / matProject._33);
	oRayDir = normalize(
		  matView._13_23_33 / matProject._33
		+ matView._11_21_31 * p.x / matProject._11
		- matView._12_22_32 * p.y / matProject._22
	);
}

float4 EllipsoidCloudVS(
	in float4 Position : POSITION,
	in float4 Texcoord : TEXCOORD,
	out float4 oTexcoord0 : TEXCOORD0) : POSITION
{
	oTexcoord0 = Texcoord;
	oTexcoord0.xy += ViewportOffset;
	oTexcoord0.zw = oTexcoord0.xy * ViewportSize;
	float2 p = Texcoord.xy * 2 - 1;
	p.y = -p.y;
	return float4(p, 0.0, 1.0);
}

float4 EllipsoidCloudPS(in float4 coord : TEXCOORD0) : COLOR
{
	float4 MRT0 = tex2Dlod(Gbuffer5Map, float4(coord.xy, 0, 0));
	float4 MRT1 = tex2Dlod(Gbuffer6Map, float4(coord.xy, 0, 0));
	float4 MRT2 = tex2Dlod(Gbuffer7Map, float4(coord.xy, 0, 0));
	float4 MRT3 = tex2Dlod(Gbuffer8Map, float4(coord.xy, 0, 0));

	MaterialParam material;
	DecodeGbuffer(MRT0, MRT1, MRT2, MRT3, material);

	float3 cameraPos, cameraDir, rayDir;
	SetupCameraAndRay(coord.xy, cameraPos, cameraDir, rayDir);

	float4 color = CastRay(cameraPos, rayDir, cameraDir, material.linearDepth);

	clip(color.a); // オブジェクトに衝突していない場合は描画しない

	return float4(color.rgb * color.a, color.a);
}

#define OBJECT_TEC(name, mmdpass) \
	technique name<string MMDPass = mmdpass;>{\
		pass DrawObject {\
			ZEnable = false; ZWriteEnable = false;\
			AlphaBlendEnable = TRUE; AlphaTestEnable = FALSE;\
			SrcBlend = ONE; DestBlend = INVSRCALPHA;\
			CullMode = NONE;\
			VertexShader = compile vs_3_0 EllipsoidCloudVS();\
			PixelShader  = compile ps_3_0 EllipsoidCloudPS();\
		}\
	}

OBJECT_TEC(MainTec0, "object")
OBJECT_TEC(MainTecBS0, "object_ss")

technique EdgeTec<string MMDPass = "edge";> {}
technique ShadowTech<string MMDPass = "shadow";> {}
technique ZplotTec<string MMDPass = "zplot";> {}
