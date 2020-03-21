#include "../../ray.conf"
#include "../../ray_advanced.conf"
#include "../../shader/math.fxsub"
#include "../../shader/common.fxsub"
#include "../../shader/gbuffer.fxsub"
#include "../../shader/gbuffer_sampler.fxsub"

//�p�[�e�B�N���������i�ő�15000)
int ParticleNum = 5000;

float morph_Anm : CONTROLOBJECT < string name = "(self)"; string item = "�Đ�"; >;
float morph_Height : CONTROLOBJECT < string name = "(self)"; string item = "��"; >;
float morph_Width : CONTROLOBJECT < string name = "(self)"; string item = "����"; >;
float morph_Scale_p : CONTROLOBJECT < string name = "(self)"; string item = "�X�P�[��+"; >;
float morph_Scale_m : CONTROLOBJECT < string name = "(self)"; string item = "�X�P�[��-"; >;
float morph_Pat : CONTROLOBJECT < string name = "(self)"; string item = "�߰è��Si"; >;
float morph_Grv : CONTROLOBJECT < string name = "(self)"; string item = "�d��"; >;
float morph_Air : CONTROLOBJECT < string name = "(self)"; string item = "��C��R"; >;
float morph_H : CONTROLOBJECT < string name = "(self)"; string item = "�F��"; >;
float morph_S : CONTROLOBJECT < string name = "(self)"; string item = "�ʓx"; >;
float morph_B : CONTROLOBJECT < string name = "(self)"; string item = "���x"; >;
float morph_A : CONTROLOBJECT < string name = "(self)"; string item = "�����x"; >;
float morph_Spd : CONTROLOBJECT < string name = "(self)"; string item = "�������Z"; >;
float morph_r : CONTROLOBJECT < string name = "(self)"; string item = "�p�x��"; >;

static float morph_Scale = morph_Scale_p - morph_Scale_m*0.1;



static float AddHeight = 10*morph_Height;
static float AddWidth = 10*morph_Width;
static float AddScale = 10*morph_Scale;
static float AddPatScale = 2000*morph_Pat;

float DefAlpha = 1;

float4x4 world : World;
float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
float4x4 inv_view_matrix : WORLDVIEWINVERSE;
float4x4 world_matrix : CONTROLOBJECT < string name = "(self)";string item = "�Z���^�[";>;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   LightColor      : SPECULAR   < string Object = "Light"; >;


float time_0_X : Time;

#define ParticleMax 15000

texture Particle_Tex
<
   string ResourceName = "Tex.png";
>;
sampler Particle = sampler_state
{
   Texture = (Particle_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = NONE;
};

texture NormalBase_Tex
<
   string ResourceName = "NormalBase.png";
>;
sampler NormalBase = sampler_state
{
   Texture = (NormalBase_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = NONE;
};
//�����e�N�X�`��
texture2D rndtex <
    string ResourceName = "random256x256.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

//�����e�N�X�`���T�C�Y
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256

//�����擾
float4 getRandom(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,1));
}

//HSB�ϊ��p�F�e�N�X�`��
texture2D ColorPallet <
    string ResourceName = "ColorPallet.png";
>;
sampler PalletSamp = sampler_state {
    texture = <ColorPallet>;
	ADDRESSU = CLAMP;
	ADDRESSV = CLAMP;
};

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
   float color: TEXCOORD1;
   float2 NormalTex: TEXCOORD2;
   float sca: TEXCOORD3;
   float3 Eye: TEXCOORD4;
   float3 WPos: TEXCOORD5;
   float4 LastPos: TEXCOORD6;
};

float3 Grv = float3(0,1,0);
VS_OUTPUT BombVS(float4 Pos: POSITION,float2 Tex: TEXCOORD0){
	VS_OUTPUT Out = (VS_OUTPUT)0;
	int index = Pos.z;
	Pos.z = 0;
	float fi = index;
	fi = fi/ParticleMax;
	float3 r = getRandom(index);
	float3 r2 = getRandom(index+128);
	float t = morph_Anm;
	float tr = 1-morph_Anm;
	float3 pos = 0;

	//����
	float sca = saturate(r.z+morph_Spd)*100;


	r.xy *= 2.0 *3.1415;

	//�p�x
	float theta = r.x*(1-morph_r);
	//�x�N�g��
	float st = 1-pow(tr,1+morph_Air*10);
	float3 Vec = float3(0,sca*sin(theta)*st*(1+AddWidth),sca*cos(theta)*-st*(1+AddHeight));

	float4x4 matRot;
	//Y����] 
	matRot[0] = float4(cos(r.y),0,-sin(r.y),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(r.y),0,cos(r.y),0); 
	matRot[3] = float4(0,0,0,1); 

	Vec = mul(Vec,matRot);
	pos += Vec;

	float3 w = (1+AddScale)*0.05*(((100*pow(t,2)) + 10 * (10+r2.y*10) + 1 * AddPatScale) * float3(Pos.xy - float2(0,0),0)) * max(0,(1-t * 0));
	//�ʏ��]
	//��]�s��̍쐬
	float rad = (r2.z*2-1)*2*3.1415*pow(1-tr,2)*0.5+r2.y*2*3.1415;

	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	w = mul(w,matRot);

	matRot[0] = float4(cos(-rad),sin(-rad),0,0); 
	matRot[1] = float4(-sin(-rad),cos(-rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
		
	Out.NormalTex =  mul(Tex*2-1,matRot).xy;
	Out.NormalTex = Out.NormalTex*0.5+0.5;
	
	//�r���{�[�h��]
	w = mul(w,inv_view_matrix);
	pos *= 0.1*(1+AddScale);
	
	pos = mul(float4(pos, 1),world_matrix);
	
	pos-=pow(Grv*t*(morph_Grv*10),2)*(0.1+pow(r.z,4));

	pos += w;
	
	Out.Eye = pos - CameraPosition;
	
	Out.Pos = mul(float4(pos, 1), world_view_proj_matrix);
	Out.LastPos = Out.Pos;
	Out.WPos = mul(pos,world);
	
	Out.color = (1-pow(tr,8))*saturate(tr*r2.x);

	//16��ނ̃e�N�X�`������I��

	// �e�N�X�`�����W
	Out.Tex = Tex*0.25;
	
	if(index >= ParticleNum) Out.Pos.z = -2;
	
	index %= 16;
	
	int tw = index%4;
	int th = index/4;

	Out.Tex.x += tw*0.25;
	Out.Tex.y += th*0.25;

	Out.sca = 1-r.z;

	return Out;
}

float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View); 
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}

shared texture FogMap: OFFSCREENRENDERTARGET;
sampler FogMapSamp = sampler_state {
	texture = <FogMap>;
	MINFILTER = Linear; MAGFILTER = Linear; MIPFILTER = NONE;
	ADDRESSU = BORDER; ADDRESSV = BORDER; BorderColor = 0.0;
};

float4 BombPS(VS_OUTPUT IN) : COLOR {
	float2 coord = PosToCoord(IN.LastPos.xy / IN.LastPos.w) + ViewportOffset;

	float4 MRT5 = tex2Dlod(Gbuffer5Map, float4(coord, 0, 0));
	float4 MRT6 = tex2Dlod(Gbuffer6Map, float4(coord, 0, 0));
	float4 MRT7 = tex2Dlod(Gbuffer7Map, float4(coord, 0, 0));
	float4 MRT8 = tex2Dlod(Gbuffer8Map, float4(coord, 0, 0));

	MaterialParam material;
	DecodeGbuffer(MRT5, MRT6, MRT7, MRT8, material);

	float dep = IN.LastPos.w;
	clip(material.linearDepth - dep);

	float4 col = tex2D(Particle,IN.Tex);
	col.a *= IN.color * DefAlpha * (1-morph_A);
	col.rgb = col.rgb * 2.0 - 1.0;
	col.b = 0;
	float4 normal = tex2D(NormalBase,IN.NormalTex);
	normal.rgb  = normal.rgb * 2 - 1;
	normal.rgb += col.rgb;
	normal.a *= col.a;
	
	float3x3 tangentFrame = compute_tangent_frame(normalize(IN.Eye), normalize(IN.Eye), IN.NormalTex);
	normal.xyz = normalize(mul(normal.xyz, tangentFrame));
	float d = pow(saturate(dot(-LightDirection,-normal.xyz)*0.25+0.75),3);
	
	col = float4(d,d,d,normal.a);
	col.rgb *= LightColor;
	col.rgb *= 0.5;

	float r = 1;
	//r *= morph_B*10;

	float3 MulColor = tex2D(PalletSamp,float2(morph_H,morph_S)).rgb*r;
	col.rgb *= MulColor;
	col.rgb *= 10 * morph_B + 1.0;
	//col.rgb += AddColor*pow(IN.color,1)*IN.sca*2;

	float fogAlpha = -log(1.001 - col.a);
	float3 fogColor = fogAlpha * col.rgb;
	return float4(fogColor, fogAlpha);
}

#define OBJECT_TEC(name, mmdpass) \
	technique name< string MMDPass = mmdpass; \
	string Script = \
		"RenderColorTarget=;" \
		"Pass=DrawBomb;" \
	;> { \
		pass DrawBomb { \
			ZEnable = false; \
			ZWriteEnable = false; \
			AlphaBlendEnable = true; \
			AlphaTestEnable = false; \
			SrcBlend = ONE; \
			DestBlend = INVSRCALPHA; \
			CullMode = NONE; \
			VertexShader = compile vs_3_0 BombVS(); \
			PixelShader = compile ps_3_0 BombPS(); \
		} \
	} 

OBJECT_TEC(NewBomb, "object")
OBJECT_TEC(NewBombBS, "object_ss")