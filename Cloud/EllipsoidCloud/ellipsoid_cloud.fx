#include "../../shader/common.fxsub"
#include "../../shader/math.fxsub"
#include "../../shader/gbuffer.fxsub"
#include "../../shader/gbuffer_sampler.fxsub"
#include "../noise.fxsub"

float4x4 mCloudWorld    : CONTROLOBJECT<string name = "(self)"; string item = "Position";>;
float3 mCloudSize       : CONTROLOBJECT<string name = "(self)"; string item = "Size";>;
float3 mPatternScale    : CONTROLOBJECT<string name = "(self)"; string item = "PatternScale";>;
float mCloudCutoffP     : CONTROLOBJECT<string name = "(self)"; string item = "Cutoff+";>;
float mCloudCutoffM     : CONTROLOBJECT<string name = "(self)"; string item = "Cutoff-";>;
float mCloudDensityP    : CONTROLOBJECT<string name = "(self)"; string item = "Density+";>;
float mCloudDensityM    : CONTROLOBJECT<string name = "(self)"; string item = "Density-";>;
float mCloudBrightnessP : CONTROLOBJECT<string name = "(self)"; string item = "Brightness+";>;
float mCloudBrightnessM : CONTROLOBJECT<string name = "(self)"; string item = "Brightness-";>;
float mCloudHue         : CONTROLOBJECT<string name = "(self)"; string item = "H+";>;
float mCloudSaturation  : CONTROLOBJECT<string name = "(self)"; string item = "S+";>;
float mCloudValueM      : CONTROLOBJECT<string name = "(self)"; string item = "V-";>;

static float mCloudCutoff  = lerp(lerp(0.5, 1.0, mCloudCutoffP), 0.0, mCloudCutoffM);
static float mCloudDensity = lerp(lerp(0.2, 1.0, mCloudDensityP), 0.0, mCloudDensityM);
static float mCloudBrightness = lerp(lerp(0.4, 2.0, mCloudBrightnessP), 0.0, mCloudBrightnessM);
static float mCloudValue = 1.0 - mCloudValueM;

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
inline float3 RayPlaneIntersection(float3 cameraPos, float3 rayDir, float3 planePoint, float3 planeNormal) {
	float denom = dot(rayDir, planeNormal);
	float t = dot(planePoint - cameraPos, planeNormal) / denom;
	return cameraPos + t*rayDir;
}

inline float Ellipsoid(float3 p, float3 radius) {
	return dot(p / radius, p / radius) - 1.0;
}

float OpticalDepthAt(float3 p, float interval) {
	// ノイズを生成
	float3 hashP = 5 * p / mPatternScale.x;
	float hashValue = fbm_4(hashP) * 0.5 + 0.5;
	float r = saturate((hashValue - mCloudCutoff) / (1.0 - mCloudCutoff));

	// 中心なら0、外周部なら1
	float u = saturate(Ellipsoid(p, mCloudSize) + 1.0);

	// ガウス分布っぽい濃度分布にする
	float baseDensity = max(mCloudDensity * exp(-7*u*u) - 0.01, 0.0);

	return r * baseDensity * interval;
}

inline float LinearDepth(float3 p, float3 cameraPos, float3 cameraDir) {
	return dot(p - cameraPos, cameraDir);
}

// cameraPos から rayDir の方向にレイを飛ばし、雲の拡散光と光学的深さを求める。
// 戻り値の rgb 成分は拡散光を表し、a成分は光学的深さを表す。
// レイが雲に衝突しない場合は (-1, -1, -1, -1) を返す。
float4 CastRay(
	float3 cameraPos,
	float3 rayDir,
	float3 cameraDir,
	float3 sunDir,
	float  maxDepth
) {
	bool willHit;
	RayEllipsoidIntersection(cameraPos, rayDir, mCloudSize, willHit);
	if (!willHit)  {
		return float4(-1, -1, -1, -1);
	}

	static const int N_LAYERS = 64;
	static const int N_LIGHT_SAMPLES = 2;

	// 楕円上の点の中で最も深度が浅い点を求める
	float3 frontDir = normalize(-cameraDir * mCloudSize * mCloudSize);
	float3 frontPoint = mCloudSize * frontDir;

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
			float lightSampleInterval = dot(mCloudSize, float3(1, 1, 1)) * 0.1 / (N_LIGHT_SAMPLES + 1);
			float lightDirOpticalDepth = 0;
			for (int j = 0; j < N_LIGHT_SAMPLES; j++) {
				float3 samplePoint = ithPoint + (j + 1) * lightSampleInterval * -sunDir;
				if (Ellipsoid(samplePoint, mCloudSize) < EPSILON) {
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

	return float4(scatteredLight, scatteredLight, scatteredLight, opticalDepth);
}

// World空間におけるカメラとレイの位置や向きを求める。
// レイの向きは現在描画中のピクセルの方向を指していて、
// カメラの向きは現在描画中のピクセルとは関係なく画面の中央を指している。
void SetupCameraAndRay(
	float2 coord,
	out float3 oCameraPos,
	out float3 oCameraDir,
	out float3 oRayDir,
	out float3 oSunDir
) {
	float2 p = (coord.xy - 0.5) * 2.0;
	float3x3 rotM = float3x3(mCloudWorld._11_12_13, mCloudWorld._21_22_23, mCloudWorld._31_32_33);

	oCameraPos = CameraPosition - mCloudWorld._41_42_43;
	oCameraPos = mul(rotM, oCameraPos);

	oCameraDir = normalize(matView._13_23_33 / matProject._33);
	oCameraDir = mul(rotM, oCameraDir);

	oRayDir = normalize(
		  matView._13_23_33 / matProject._33
		+ matView._11_21_31 * p.x / matProject._11
		- matView._12_22_32 * p.y / matProject._22
	);
	oRayDir = mul(rotM, oRayDir);

	oSunDir = mul(rotM, SunDirection);
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

	float3 cameraPos, cameraDir, rayDir, sunDir;
	SetupCameraAndRay(coord.xy, cameraPos, cameraDir, rayDir, sunDir);

	float4 baseColor = CastRay(cameraPos, rayDir, cameraDir, sunDir, material.linearDepth);

	clip(baseColor.a); // オブジェクトに衝突していない場合は描画しない

	float3 color = baseColor
		* mCloudBrightness
		* hsv2rgb(float3(mCloudHue, mCloudSaturation, mCloudValue))
		* SunColor;

	return float4(color * (1.0 - exp(-baseColor.a)), baseColor.a);
}

#define OBJECT_TEC(name, mmdpass) \
	technique name<string MMDPass = mmdpass;>{\
		pass DrawObject {\
			ZEnable = false; ZWriteEnable = false;\
			AlphaBlendEnable = TRUE; AlphaTestEnable = FALSE;\
			SrcBlend = ONE; DestBlend = ONE;\
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
