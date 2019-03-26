#include "Renderer.h"

ShadowMapRenderPass Renderer::shadowMapRenderPass;
GBufferRenderPass Renderer::gBufferRenderPass;
DeferredShadingRenderPass Renderer::deferredShadingRenderPass;
VoxelInjectionRenderPass Renderer::voxelInjectionRenderPass;
SHIndirectRenderPass Renderer::shIndirectRenderPass;
IndirectDiffuseLightingRenderPass Renderer::indirectDiffuseLightingRenderPass;
IndirectSpecularLightingRenderPass Renderer::indirectSpecularLightingRenderPass;
SkyBoxRenderPass Renderer::skyBoxRenderPass;
FXAARenderPass Renderer::fxaaRenderPass;
ToneMappingRenderPass Renderer::toneMappingRenderPass;
ColorGradingRenderPass Renderer::colorGradingRenderPass;

void Renderer::Initialize(ComPtr<ID3D12Device> inputDevice, int inputWidth, int inputHeight,
	DXGI_FORMAT inputFormatBackBuffer, DXGI_FORMAT inputFormatDepthBuffer)
{
	shadowMapRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, nullptr, nullptr, nullptr, nullptr, L"ShadowMap.hlsl", L"");
	
	gBufferRenderPass.Initialize(inputDevice, inputWidth, inputHeight, 
		inputFormatBackBuffer, inputFormatDepthBuffer, nullptr, nullptr, nullptr, nullptr, L"GBufferWrite.hlsl", L"");
	
	deferredShadingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, shadowMapRenderPass.mOutputBuffers, 
		gBufferRenderPass.mOutputBuffers, nullptr, gBufferRenderPass.mDepthStencilBuffer, L"DeferredShading.hlsl", L"");
	
	voxelInjectionRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, deferredShadingRenderPass.mOutputBuffers, 
		gBufferRenderPass.mOutputBuffers, nullptr, gBufferRenderPass.mDepthStencilBuffer, L"", L"VoxelInjection.hlsl", true);
	
	shIndirectRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, nullptr, nullptr, 
		voxelInjectionRenderPass.mOutputBuffers, gBufferRenderPass.mDepthStencilBuffer, L"", L"SHIndirectConeTracing.hlsl", true);

	indirectDiffuseLightingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, deferredShadingRenderPass.mOutputBuffers, 
		gBufferRenderPass.mOutputBuffers, shIndirectRenderPass.mOutputBuffers, gBufferRenderPass.mDepthStencilBuffer, 
		L"DiffuseIndirectLighting.hlsl", L"");

	indirectSpecularLightingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, indirectDiffuseLightingRenderPass.mOutputBuffers,
		gBufferRenderPass.mOutputBuffers, voxelInjectionRenderPass.mOutputBuffers, gBufferRenderPass.mDepthStencilBuffer,
		L"SpecularIndirectLighting.hlsl", L"");

	skyBoxRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, indirectSpecularLightingRenderPass.mOutputBuffers,
		nullptr, nullptr, gBufferRenderPass.mDepthStencilBuffer, L"", L"SkyBox.hlsl", true);

	toneMappingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, skyBoxRenderPass.mOutputBuffers,
		nullptr, nullptr, gBufferRenderPass.mDepthStencilBuffer, L"", L"ToneMapping.hlsl", true);

	fxaaRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, toneMappingRenderPass.mOutputBuffers,
		nullptr, nullptr, gBufferRenderPass.mDepthStencilBuffer, L"", L"FXAA.hlsl", true);
	
	colorGradingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, fxaaRenderPass.mOutputBuffers, 
		nullptr, nullptr, gBufferRenderPass.mDepthStencilBuffer, L"", L"ColorGrading.hlsl", true);
}

void Renderer::Execute(ID3D12GraphicsCommandList * commandList, D3D12_CPU_DESCRIPTOR_HANDLE * depthStencilViewPtr,
	FrameResource* mCurrFrameResource)
{
	// Render the gBuffers
	gBufferRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Compute the lighting using deferred shading
	deferredShadingRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Inject lighting data into the voxel grids
	voxelInjectionRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Cone trace indirect lighting and inject it into the spherical harmonic grids
	shIndirectRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Sample SH grid to compute indirect diffuse lighting
	indirectDiffuseLightingRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Ray trace through voxel grids to compute indirect specular lighting
	indirectSpecularLightingRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Render skybox on the background pixels using a quad
	skyBoxRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Perform anti-aliasing using FXAA
	fxaaRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Bring the texture down to LDR range from HDR using Uncharted 2 style tonemapping
	toneMappingRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);

	// Use 2D LUTs for color grading
	colorGradingRenderPass.Execute(commandList, depthStencilViewPtr, mCurrFrameResource);
}

void Renderer::CopyToBackBuffer(ID3D12GraphicsCommandList* commandList, ID3D12Resource * backBuffer)
{
	commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(colorGradingRenderPass.mOutputBuffers[0].Get(),
		D3D12_RESOURCE_STATE_GENERIC_READ, D3D12_RESOURCE_STATE_COPY_SOURCE));

	commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(backBuffer,
		D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_COPY_DEST));

	commandList->CopyResource(backBuffer, Renderer::colorGradingRenderPass.mOutputBuffers[0].Get());

	commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(backBuffer,
		D3D12_RESOURCE_STATE_COPY_DEST, D3D12_RESOURCE_STATE_PRESENT));

	commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(colorGradingRenderPass.mOutputBuffers[0].Get(),
		D3D12_RESOURCE_STATE_COPY_SOURCE, D3D12_RESOURCE_STATE_GENERIC_READ));
}
