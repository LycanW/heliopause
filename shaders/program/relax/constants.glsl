#ifndef HELIOPAUSE_RELAX_CONSTANTS
#define HELIOPAUSE_RELAX_CONSTANTS

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

vec3 nrOrigin() { return gbufferModelViewInverse[3].xyz; }
vec3 nrPrevOrigin() { return -transpose(mat3(gbufferPreviousModelView)) * gbufferPreviousModelView[3].xyz; }
mat4 nrTranslation(vec3 p) { return mat4(vec4(1.0,0.0,0.0,0.0),vec4(0.0,1.0,0.0,0.0),vec4(0.0,0.0,1.0,0.0),vec4(p,1.0)); }
vec3 nrRight() { return gbufferModelViewInverse[0].xyz / gbufferProjection[0][0]; }
vec3 nrUp() { return gbufferModelViewInverse[1].xyz / gbufferProjection[1][1]; }
vec3 nrForward() { return -gbufferModelViewInverse[2].xyz; }
vec3 nrPrevRight() { return transpose(mat3(gbufferPreviousModelView))[0] / gbufferPreviousProjection[0][0]; }
vec3 nrPrevUp() { return transpose(mat3(gbufferPreviousModelView))[1] / gbufferPreviousProjection[1][1]; }
vec3 nrPrevForward() { return -transpose(mat3(gbufferPreviousModelView))[2]; }

// SPIRV-Cross represents the original HLSL matrices as row-major blocks and
// multiplies row vectors. Transpose the Iris column-vector matrices once here.
#define gWorldToClip transpose(gbufferModelViewProjection * nrTranslation(nrOrigin()))
#define gWorldToClipPrev transpose(gbufferPreviousModelViewProjection * nrTranslation(nrOrigin()+cameraVelocity))
#define gWorldToViewPrev transpose(mat4(vec4(1.0,0.0,0.0,0.0),vec4(0.0,1.0,0.0,0.0),vec4(0.0,0.0,-1.0,0.0),vec4(0.0,0.0,0.0,1.0)) * gbufferPreviousModelView * nrTranslation(nrOrigin()+cameraVelocity))
#define gWorldPrevToWorld mat4(1.0)
#define gRotatorPre vec4(cos(float(frameCounter)*2.39996323),sin(float(frameCounter)*2.39996323),-sin(float(frameCounter)*2.39996323),cos(float(frameCounter)*2.39996323))
#define gFrustumRight vec4(nrRight(),0.0)
#define gFrustumUp vec4(nrUp(),0.0)
#define gFrustumForward vec4(nrForward(),0.0)
#define gPrevFrustumRight vec4(nrPrevRight(),0.0)
#define gPrevFrustumUp vec4(nrPrevUp(),0.0)
#define gPrevFrustumForward vec4(nrPrevForward(),0.0)
#define gCameraDelta vec4(nrPrevOrigin()-nrOrigin()-cameraVelocity,0.0)
#define gMvScale vec4(0.0,0.0,0.0,1.0)
#define gMvBias vec4(0.0)
#define gJitter (vec2(-taaOffset.x,taaOffset.y)*0.5*internalScreenSize)
#define gResolutionScale vec2(1.0)
#define gResourceSizeInv internalTexelSize
#define gResourceSize internalScreenSize
#define gRectSizeInv internalTexelSize
#define gRectSizePrev internalScreenSize
#define gResourceSizeInvPrev internalTexelSize
#define gPrintfAt uvec2(9999u)
#define gInputRectOrigin ivec2(0)
#define gOutputRectOrigin ivec2(0)
#define gDispatchInputRectOrigin ivec2(0)
#define gDispatchOutputRectOrigin ivec2(0)
#define gRectSize ivec2(internalScreenSize)
#define gSpecMaxAccumulatedFrameNum float(RELAX_SPECULAR_HISTORY)
#define gSpecMaxFastAccumulatedFrameNum float(RELAX_FAST_HISTORY)
#define gDiffMaxAccumulatedFrameNum float(RELAX_DIFFUSE_HISTORY)
#define gDiffMaxFastAccumulatedFrameNum float(RELAX_FAST_HISTORY)
#define gDisocclusionThreshold (0.01+2.0*internalTexelSize.y)
#define gDisocclusionThresholdAlternate (0.05+2.0*internalTexelSize.y)
#define gCameraAttachedReflectionMaterialID 999.0
#define gStrandMaterialID 999.0
#define gStrandThickness 0.00008
#define gRoughnessFraction 0.15
#define gSpecVarianceBoost 0.0
#define gSplitScreen 0.0
#define gDiffBlurRadius float(RELAX_DIFFUSE_PREPASS)
#define gSpecBlurRadius float(RELAX_SPECULAR_PREPASS)
#define gDepthThreshold 0.003
#define gLobeAngleFraction 0.5
#define gSpecLobeAngleSlack 0.00261799388
#define gHistoryFixEdgeStoppingNormalPower 8.0
#define gRoughnessEdgeStoppingRelaxation 1.0
#define gNormalEdgeStoppingRelaxation 0.3
#define gFastHistoryClampingSigmaScale 2.0
#define gHistoryAccelerationAmount 0.0
#define gHistoryResetTemporalSigmaScale 0.5
#define gHistoryResetSpatialSigmaScale 4.5
#define gHistoryResetAmount 0.0
#define gDenoisingRange 500000.0
#define gSpecPhiLuminance 1.0
#define gDiffPhiLuminance 2.0
#define gDiffMaxLuminanceRelativeDifference 1e6
#define gSpecMaxLuminanceRelativeDifference 1e6
#define gLuminanceEdgeStoppingRelaxation 0.5
#define gConfidenceDrivenRelaxationMultiplier 0.0
#define gConfidenceDrivenLuminanceEdgeStoppingRelaxation 0.0
#define gConfidenceDrivenNormalEdgeStoppingRelaxation 0.0
#define gDebug 0.0
#define gOrthoMode 0.0
#define gUnproject (2.0*internalTexelSize.y/gbufferProjection[1][1])
#define gFrameRateScale clamp(1.0/(60.0*max(frameTime,0.0001)),0.25,4.0)
#define gFrameRateScaleSmoothed gFrameRateScale
#define gCheckerboardResolveAccumSpeed 0.5
#define gHistoryFixFrameNum 4.0
#define gHistoryFixBasePixelStride 14.0
#define gHistoryFixAlternatePixelStride 14.0
#define gHistoryFixAlternatePixelStrideMaterialID 999.0
#define gHistoryThreshold 3.0
#define gViewZScale 1.0
#define gMinHitDistanceWeight 0.2
#define gDiffMinMaterial 4.0
#define gSpecMinMaterial 0.0
#define gRoughnessEdgeStoppingEnabled 1u
#define gFrameIndex uint(frameCounter)
#define gDiffCheckerboard 2u
#define gSpecCheckerboard 2u
#define gHasHistoryConfidence 0u
#define gHasDisocclusionThresholdMix 0u
#define gResetHistory uint(frameCounter<2)
#define gStepSize uint(1<<NR_ATROUS_INDEX)
#define gIsLastPass int(NR_LAST_PASS)
#endif
