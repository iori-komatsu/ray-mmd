// HitTest: 当たり判定をレンダリングターゲットに書き込む (Scale)

#include "sub/HitTest.fxsub"

float4x4 WorldMatrix : WORLD;
float4x4 InvWorldMatrix : WORLDINVERSE;

//---------------------------
// Scale.fx

#define SCALE_CONTROLLER "ScaleControl.pmd"
bool   S_ScaleControllerExists : CONTROLOBJECT < string name = SCALE_CONTROLLER;>;
float3 S_Origin    : CONTROLOBJECT < string name = SCALE_CONTROLLER; string item = "ｽｹｰﾙ原点"; >;
float3 S_ScaleXYZ  : CONTROLOBJECT < string name = SCALE_CONTROLLER; string item = "ｽｹｰﾙ変更"; >;
float  S_Expansion : CONTROLOBJECT < string name = SCALE_CONTROLLER; string item = "拡大"; >;
float  S_Reduction : CONTROLOBJECT < string name = SCALE_CONTROLLER; string item = "縮小"; >;
static float3 S_Scale = float3( clamp( pow(10.0f, 0.1f*S_ScaleXYZ.x), 0.01f, 100.0f ),
                                clamp( pow(10.0f, 0.1f*S_ScaleXYZ.y), 0.01f, 100.0f ),
                                clamp( pow(10.0f, -0.1f*S_ScaleXYZ.z), 0.01f, 100.0f ) );
static float S_ScaleAll = (1.0f + 9.0f*S_Expansion)*(1.0f - 0.9f*S_Reduction);

//---------------------------
// sdPBR の Scale

#define SDPBR_SCALE_CONTROLLER "sdPBRScaleController.pmx"
bool   _ScaleControllerExists  : CONTROLOBJECT < string name = SDPBR_SCALE_CONTROLLER;>;
float3 _ScaleControllerOrigin  : CONTROLOBJECT < string name = SDPBR_SCALE_CONTROLLER; string item="スケール原点";>;
float  _ScaleControllerMagnify : CONTROLOBJECT < string name = SDPBR_SCALE_CONTROLLER; string item="大きくなーれ";>;
float  _ScaleControllerShrink  : CONTROLOBJECT < string name = SDPBR_SCALE_CONTROLLER; string item="小さくなーれ";>;

float3 _ScaleSelfOrigin  : CONTROLOBJECT < string name = "(self)"; string item="スケール原点";>;
float  _ScaleSelfMagnify : CONTROLOBJECT < string name = "(self)"; string item="大きくなーれ";>;
float  _ScaleSelfShrink  : CONTROLOBJECT < string name = "(self)"; string item="小さくなーれ";>;

static float3 _ScaleOrigin = _ScaleControllerExists ? _ScaleControllerOrigin : _ScaleSelfOrigin;
static float _ScaleRate = _ScaleControllerExists ? exp2((_ScaleControllerMagnify-_ScaleControllerShrink)*10) : exp2((_ScaleSelfMagnify-_ScaleSelfShrink)*10);

//--------------------------

static float3 ScaleOrigin = S_Origin + _ScaleOrigin;
static float3 ScaleRate = S_ScaleAll * S_Scale * _ScaleRate;

//--------------------------

float4 VSReposition(float4 Pos)
{
    float4 wpos = mul(Pos, WorldMatrix);

    wpos.xyz -= ScaleOrigin;
    wpos.xyz *= ScaleRate;
    wpos.xyz += ScaleOrigin;

    Pos = mul(wpos, InvWorldMatrix);

	return Pos;
}

void HitTestVS(
	float4 pos : POSITION,
	out float4 oPos : POSITION
) {
	pos = VSReposition(pos);
	float4 worldPos = mul(pos, WorldMatrix);
	oPos = WorldPosToHitTexturePos(worldPos);
}

float4 HitTestPS() : COLOR {
    return float4(0.5, 0, 0, 1);
}

#define DEFINE_TEC(name, mmdpass) \
	technique name < string MMDPass = mmdpass; > { \
		pass DrawObject { \
			CullMode = NONE; \
			AlphaBlendEnable = FALSE; \
			VertexShader = compile vs_3_0 HitTestVS(); \
			PixelShader = compile ps_3_0 HitTestPS(); \
		} \
	}

DEFINE_TEC(MainTec, "object")
DEFINE_TEC(MainTecSS, "object_ss")

technique EdgeTechnique < string MMDPass = "edge"; > {
    // 描画しない
}

technique ShadowTechnique < string MMDPass = "shadow"; > {
    // 描画しない
}
