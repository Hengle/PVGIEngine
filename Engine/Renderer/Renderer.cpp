#include "Renderer.h"

ShadowMapRenderPass Renderer::shadowMapRenderPass;
GBufferRenderPass Renderer::gBufferRenderPass;
DeferredShadingRenderPass Renderer::deferredShadingRenderPass;
SkyBoxRenderPass Renderer::skyBoxRenderPass;
ToneMappingRenderPass Renderer::toneMappingRenderPass;
ColorGradingRenderPass Renderer::colorGradingRenderPass;

void Renderer::Initialize(ComPtr<ID3D12Device> inputDevice, int inputWidth, int inputHeight,
	DXGI_FORMAT inputFormatBackBuffer, DXGI_FORMAT inputFormatDepthBuffer)
{
	shadowMapRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, nullptr, nullptr, L"ShadowMap.hlsl");
	gBufferRenderPass.Initialize(inputDevice, inputWidth, inputHeight, 
		inputFormatBackBuffer, inputFormatDepthBuffer, nullptr, nullptr, L"GBufferWrite.hlsl");
	deferredShadingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, shadowMapRenderPass.mOutputBuffers, gBufferRenderPass.mOutputBuffers, L"DeferredShading.hlsl");
	skyBoxRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, deferredShadingRenderPass.mOutputBuffers, gBufferRenderPass.mOutputBuffers, L"SkyBox.hlsl");
	toneMappingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, skyBoxRenderPass.mOutputBuffers, nullptr, L"ToneMapping.hlsl");
	colorGradingRenderPass.Initialize(inputDevice, inputWidth, inputHeight,
		inputFormatBackBuffer, inputFormatDepthBuffer, toneMappingRenderPass.mOutputBuffers, nullptr, L"ColorGrading.hlsl");
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
