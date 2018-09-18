// Need to input a vector which has r - worldVolumeBoundary, g - maximumIterations, b - lengthOfCone, a - unused

Texture3D	 VoxelGrid1				 : register(t5);
Texture3D	 VoxelGrid2				 : register(t6);
Texture3D	 VoxelGrid3				 : register(t7);
Texture3D	 VoxelGrid4				 : register(t8);
Texture3D	 VoxelGrid5				 : register(t9);

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
	float4x4 gShadowViewProj;
	float4x4 gShadowTransform;
	float4 gWB_MI_LC_U;
};

// Returns the voxel position in the grids
inline float3 GetVoxelPosition(float3 worldPosition)
{
	float3 voxelPosition = worldPosition / gWB_MI_LC_U.r;
	voxelPosition += float3(1.0f, 1.0f, 1.0f);
	voxelPosition /= 2.0f;
	return voxelPosition;
}

// Returns the voxel information from grid 1
inline float4 GetVoxelInfo1(float3 voxelPosition)
{
	float4 info = VoxelGrid1.Sample(gsamLinearWrap, voxelPosition);
	return info;
}

// Returns the voxel information from grid 2
inline float4 GetVoxelInfo2(float3 voxelPosition)
{
	float4 info = VoxelGrid2.Sample(gsamLinearWrap, voxelPosition);
	return info;
}

// Returns the voxel information from grid 3
inline float4 GetVoxelInfo3(float3 voxelPosition)
{
	float4 info = VoxelGrid3.Sample(gsamLinearWrap, voxelPosition);
	return info;
}

// Returns the voxel information from grid 4
inline float4 GetVoxelInfo4(float3 voxelPosition)
{
	float4 info = VoxelGrid4.Sample(gsamLinearWrap, voxelPosition);
	return info;
}

// Returns the voxel information from grid 5
inline float4 GetVoxelInfo5(float3 voxelPosition)
{
	float4 info = VoxelGrid5.Sample(gsamLinearWrap, voxelPosition);
	return info;
}

inline float3 ConeTrace(float3 worldPosition, float3 coneDirection, float3 worldNormal)
{
	float3 computedColor = float3(0.0f, 0.0f, 0.0f);

	float coneStep = gWB_MI_LC_U.b / gWB_MI_LC_U.g;

	float iteration0 = gWB_MI_LC_U.g / 32.0f;
	float iteration1 = gWB_MI_LC_U.g / 32.0f;
	float iteration2 = gWB_MI_LC_U.g / 16.0f;
	float iteration3 = gWB_MI_LC_U.g / 8.0f;
	float iteration4 = gWB_MI_LC_U.g / 4.0f;
	float iteration5 = gWB_MI_LC_U.g / 2.0f;

	float3 coneOrigin = worldPosition + (coneDirection * coneStep * iteration0);

	float3 currentPosition = coneOrigin;
	float4 currentVoxelInfo = float4(0.0f, 0.0f, 0.0f, 0.0f);

	float hitFound = 0.0f;
	float3 hitPosition = float3(0.0f, 0.0f, 0.0f);

	// Sample voxel grid 1
	for (float i1 = 0.0f; i1 < iteration1; i1 += 1.0f)
	{
		currentPosition += (coneStep * coneDirection);

		if (hitFound < 0.9f)
		{
			currentVoxelInfo = GetVoxelInfo1(GetVoxelPosition(currentPosition));
			if (currentVoxelInfo.a > 0.0f)
			{
				hitFound = 1.0f;
			}
		}
	}

	// Sample voxel grid 2
	for (float i2 = 0.0f; i2 < iteration2; i2 += 1.0f)
	{
		currentPosition += (coneStep * coneDirection);

		if (hitFound < 0.9f)
		{
			currentVoxelInfo = GetVoxelInfo2(GetVoxelPosition(currentPosition));
			if (currentVoxelInfo.a > 0.0f)
			{
				hitFound = 1.0f;
			}
		}
	}

	// Sample voxel grid 3
	for (float i3 = 0.0f; i3 < iteration3; i3 += 1.0f)
	{
		currentPosition += (coneStep * coneDirection);

		if (hitFound < 0.9f)
		{
			currentVoxelInfo = GetVoxelInfo3(GetVoxelPosition(currentPosition));
			if (currentVoxelInfo.a > 0.0f)
			{
				hitFound = 1.0f;
			}
		}
	}

	// Sample voxel grid 4
	for (float i4 = 0.0f; i4 < iteration4; i4 += 1.0f)
	{
		currentPosition += (coneStep * coneDirection);

		if (hitFound < 0.9f)
		{
			currentVoxelInfo = GetVoxelInfo4(GetVoxelPosition(currentPosition));
			if (currentVoxelInfo.a > 0.0f)
			{
				hitFound = 1.0f;
			}
		}
	}

	// Sample voxel grid 5
	for (float i5 = 0.0f; i5 < iteration5; i5 += 1.0f)
	{
		currentPosition += (coneStep * coneDirection);

		if (hitFound < 0.9f)
		{
			currentVoxelInfo = GetVoxelInfo5(GetVoxelPosition(currentPosition));
			if (currentVoxelInfo.a > 0.0f)
			{
				hitFound = 1.0f;
			}
		}
	}

	computedColor = currentVoxelInfo.rgb;
	
	return computedColor;
}

inline float3 CalculateIndirectLighting(float3 worldPosition, float3 worldNormal)
{
	float3 accumulatedColor = float3(0.0f, 0.0f, 0.0f);

	float3 randomVector = normalize(float3(1.0f, 2.0f, 3.0f));

	float3 direction1 = normalize(cross(worldNormal, randomVector));
	float3 direction2 = -direction1;
	float3 direction3 = normalize(cross(worldNormal, direction1));	// Not used in cone tracing
	float3 direction4 = -direction3; 								// Not used in cone tracing
	float3 direction5 = lerp(direction1, direction3, 0.6667f);
	float3 direction6 = -direction5;
	float3 direction7 = lerp(direction2, direction3, 0.6667f);
	float3 direction8 = -direction7;

	float3 coneDirection1 = worldNormal;
	float3 coneDirection2 = lerp(direction1, worldNormal, 0.3333f);
	float3 coneDirection3 = lerp(direction2, worldNormal, 0.3333f);
	float3 coneDirection4 = lerp(direction5, worldNormal, 0.3333f);
	float3 coneDirection5 = lerp(direction6, worldNormal, 0.3333f);
	float3 coneDirection6 = lerp(direction7, worldNormal, 0.3333f);
	float3 coneDirection7 = lerp(direction8, worldNormal, 0.3333f);

	accumulatedColor += ConeTrace(worldPosition, coneDirection1, worldNormal);
	accumulatedColor += ConeTrace(worldPosition, coneDirection2, worldNormal);
	accumulatedColor += ConeTrace(worldPosition, coneDirection3, worldNormal);
	accumulatedColor += ConeTrace(worldPosition, coneDirection4, worldNormal);
	accumulatedColor += ConeTrace(worldPosition, coneDirection5, worldNormal);
	accumulatedColor += ConeTrace(worldPosition, coneDirection6, worldNormal);
	accumulatedColor += ConeTrace(worldPosition, coneDirection7, worldNormal);

	return accumulatedColor;
}