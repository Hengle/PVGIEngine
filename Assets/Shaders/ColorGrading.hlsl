Texture2D    MainTex  : register(t0);
Texture2D	 UserLUT  : register(t1);

SamplerState gsamLinearWrap			 : register(s0);
SamplerState gsamAnisotropicWrap	 : register(s1);

// Constant data that varies per material.
cbuffer cbPass : register(b0)
{
	float4x4 gView;
	float4x4 gInvView;
	float4x4 gProj;
	float4x4 gInvProj;
	float4x4 gViewProj;
	float4x4 gInvViewProj;
	float3 gEyePosW;
	float userLUTContribution;
	float2 gRenderTargetSize;
	float2 gInvRenderTargetSize;
	float gNearZ;
	float gFarZ;
	float gTotalTime;
	float gDeltaTime;
	float4 gSunLightStrength;
	float4 gSunLightDirection;
	float4x4 gSkyBoxMatrix;
};

struct VertexIn
{
	float3 PosL    : POSITION;
	float3 NormalL : NORMAL;
	float2 TexC    : TEXCOORD;
	float3 TangentU : TANGENT;
};

struct VertexOut
{
	float4 PosH : SV_POSITION;
	float3 PosV : POSITION;
	float2 TexC : TEXCOORD0;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;

	vout.TexC = vin.TexC;

	// Quad covering screen in NDC space.
	vout.PosH = float4(2.0f*vout.TexC.x - 1.0f, 1.0f - 2.0f*vout.TexC.y, 0.0f, 1.0f);

	// Transform quad corners to view space near plane.
	float4 ph = mul(vout.PosH, gInvProj);
	vout.PosV = ph.xyz / ph.w;

	return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
	float width = 256.0f;
	float height = 16.0f;
	float dimension = 16.0f;
	
	float4 inputColor = MainTex.Sample(gsamLinearWrap, pin.TexC);

	float blueCell = inputColor.b * (dimension - 1.0f);

	float blueCellLower = floor(blueCell);
	float blueCellUpper = ceil(blueCell);

	float halfPixelInX = 0.5f / width;
	float halfPixelInY = 0.5f / height;

	float rComponentOffset = halfPixelInX + inputColor.r / dimension * ((dimension - 1.0f) / dimension);
	float gComponentOffset = halfPixelInY + inputColor.g * ((dimension - 1.0f) / dimension);

	float2 positionInLUTLower = float2(blueCellLower / dimension + rComponentOffset, gComponentOffset);
	float2 positionInLUTUpper = float2(blueCellUpper / dimension + rComponentOffset, gComponentOffset);

	float4 gradedColorLower = UserLUT.Sample(gsamLinearWrap, positionInLUTLower);
	float4 gradedColorUpper = UserLUT.Sample(gsamLinearWrap, positionInLUTUpper);

	float4 gradedColor = lerp(gradedColorLower, gradedColorUpper, frac(blueCell));

	float4 result = lerp(inputColor, gradedColor, userLUTContribution);

	return result;
}