// Constant data that varies per pass.
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
	float4x4 gShadowViewProj;
	float4x4 gShadowTransform;
	float4 worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A;
};

Texture3D VoxelGrid0 			: register(t0);
Texture3D VoxelGrid1 			: register(t1);
Texture3D VoxelGrid2 			: register(t2);
Texture3D VoxelGrid3 			: register(t3);
Texture3D VoxelGrid4 			: register(t4);

RWTexture3D<float4> shGridRed	: register(u0);
RWTexture3D<float4> shGridGreen	: register(u1);
RWTexture3D<float4> shGridBlue	: register(u2);

SamplerState gsamLinearWrap		: register(s0);

// For maximum 64 iterations
#define INITIAL_ITERATIONS 2
#define ITERATIONS_0 2
#define ITERATIONS_1 4
#define ITERATIONS_2 8
#define ITERATIONS_3 16
#define ITERATIONS_4 32

#define MAXIMUM_ITERATIONS 64

#define RAY_STEP 0.2f
#define RAY_OFFSET 0.2f

#define RANDOM_VECTOR float3(0.267261f, 0.534522f, 0.801784f)

/*Cosine lobe coeff*/
#define SH_cosLobe_C0 0.886226925f // sqrt(pi)/2
#define SH_cosLobe_C1 1.02332671f // sqrt(pi/3)
#define SH_cosLobe_C1_NEGATIVE -1.02332671f // -sqrt(pi/3);

#define PI 3.1415926f
#define PI_INVERSE 0.31830988618f

inline float4 dirToCosineLobe(float3 dir) {
	return float4(SH_cosLobe_C0, SH_cosLobe_C1_NEGATIVE * dir.y, SH_cosLobe_C1 * dir.z, SH_cosLobe_C1_NEGATIVE * dir.x);
}

// Returns the voxel position in the grids
inline float3 GetVoxelPosition(float3 worldPosition)
{
	float3 voxelPosition = worldPosition / worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A.r;
	voxelPosition += float3(1.0f, 1.0f, 1.0f);
	voxelPosition *= 0.5f;
	return voxelPosition;
}

// Returns the voxel information from grid 0
inline float4 GetVoxelInfo0(float3 voxelPosition)
{
	float4 info = VoxelGrid0.SampleLevel(gsamLinearWrap, voxelPosition, 0);
	return info;
}

// Returns the voxel information from grid 1
inline float4 GetVoxelInfo1(float3 voxelPosition)
{
	float4 info = VoxelGrid1.SampleLevel(gsamLinearWrap, voxelPosition, 0);
	return info;
}

// Returns the voxel information from grid 2
inline float4 GetVoxelInfo2(float3 voxelPosition)
{
	float4 info = VoxelGrid2.SampleLevel(gsamLinearWrap, voxelPosition, 0);
	return info;
}

// Returns the voxel information from grid 3
inline float4 GetVoxelInfo3(float3 voxelPosition)
{
	float4 info = VoxelGrid3.SampleLevel(gsamLinearWrap, voxelPosition, 0);
	return info;
}

// Returns the voxel information from grid 4
inline float4 GetVoxelInfo4(float3 voxelPosition)
{
	float4 info = VoxelGrid4.SampleLevel(gsamLinearWrap, voxelPosition, 0);
	return info;
}

inline float3 DiffuseConeTrace(float3 worldPosition, float3 coneDirection)
{
	float3 currentPosition = worldPosition + (coneDirection * worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A.g * INITIAL_ITERATIONS);

	float4 currentVoxelInfo = float4(0.0f, 0.0f, 0.0f, 0.0f);

	// Sample voxel grid 0
	uint iter;
	
	for (iter = 0; iter < ITERATIONS_0; ++iter)
	{
		currentPosition += (worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A.g * coneDirection);

		if (currentVoxelInfo.a < 0.05f)
		{
			currentVoxelInfo = GetVoxelInfo0(GetVoxelPosition(currentPosition));
		}
	}
	
	if (currentVoxelInfo.a > 0.05f)
		return currentVoxelInfo.rgb;

	// Sample voxel grid 1
	for (iter = 0; iter < ITERATIONS_1; ++iter)
	{
		currentPosition += (worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A.g * coneDirection);

		if (currentVoxelInfo.a < 0.05f)
		{
			currentVoxelInfo = GetVoxelInfo1(GetVoxelPosition(currentPosition));
		}
	}

	if (currentVoxelInfo.a > 0.05f)
		return currentVoxelInfo.rgb;
	
	// Sample voxel grid 2
	for (iter = 0; iter < ITERATIONS_2; ++iter)
	{
		currentPosition += (worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A.g * coneDirection);

		if (currentVoxelInfo.a < 0.05f)
		{
			currentVoxelInfo = GetVoxelInfo2(GetVoxelPosition(currentPosition));
		}
	}

	if (currentVoxelInfo.a > 0.05f)
		return currentVoxelInfo.rgb;
	
	// Sample voxel grid 3
	for (iter = 0; iter < ITERATIONS_3; ++iter)
	{
		currentPosition += (worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A.g * coneDirection);

		if (currentVoxelInfo.a < 0.05f)
		{
			currentVoxelInfo = GetVoxelInfo3(GetVoxelPosition(currentPosition));
		}
	}

	if (currentVoxelInfo.a > 0.05f)
		return currentVoxelInfo.rgb;
	
	// Sample voxel grid 4
	for (iter = 0; iter < ITERATIONS_4; ++iter)
	{
		currentPosition += (worldBoundary_R_ConeStep_G_HalfCellWidth_B_voxelResolution_A.g * coneDirection);

		if (currentVoxelInfo.a < 0.05f)
		{
			currentVoxelInfo = GetVoxelInfo4(GetVoxelPosition(currentPosition));
		}
	}

	return currentVoxelInfo.rgb;
}