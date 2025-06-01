using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumetricPassRenderFeature : ScriptableRendererFeature
{
    [Header("Base")] public bool useRenderFeature = false;
    public RenderPassEvent renderEvent = RenderPassEvent.AfterRendering;
    public CameraType cameraType = CameraType.Game;
    public Material material;
    private Material grayMaterial;

    [Space(30)] public float intensity = 1.0f;

    GrayPass VolumetricPass;

    public override void Create()
    {
        VolumetricPass = new GrayPass(material, renderEvent);
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (!useRenderFeature)
            return;
        VolumetricPass.ConfigureInput(ScriptableRenderPassInput.Color);
        VolumetricPass.SetTarget(renderer.cameraColorTargetHandle, intensity, cameraType);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!useRenderFeature)
            return;
        renderer.EnqueuePass(VolumetricPass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(grayMaterial);
    }

    class GrayPass : ScriptableRenderPass
    {
        Material material;
        float _Intensity = 1.0f;
        RTHandle cameraColorTarget;
        RTHandle TempRT1;
        RTHandle TempRT2;
        CameraType cameraType;

        public GrayPass(Material mat, RenderPassEvent renderEvent)
        {
            material = mat;
            renderPassEvent = renderEvent;
        }

        public void SetTarget(RTHandle colorHandle, float intensity, CameraType _cameraType)
        {
            cameraColorTarget = colorHandle;
            _Intensity = intensity;
            cameraType = _cameraType;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.depthBufferBits = 0;
            descriptor.colorFormat = RenderTextureFormat.ARGBFloat;

            TempRT1 = RTHandles.Alloc(
                descriptor,
                filterMode: FilterMode.Point,
                wrapMode: TextureWrapMode.Clamp,
                name: "_TempRT"
            );
            TempRT2 = RTHandles.Alloc(
                descriptor,
                filterMode: FilterMode.Point,
                wrapMode: TextureWrapMode.Clamp,
                name: "_TempRT"
            );

            ConfigureTarget(TempRT1);
            ConfigureTarget(TempRT2);
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null)
                return;

            if (renderingData.cameraData.cameraType != cameraType)
                return;


            CommandBuffer cmd = CommandBufferPool.Get("VolumetricPass");

            Light mainLight = LightManager.instance.GetMainLight();
            material.SetVector("_LightPos", mainLight.transform.position);

            //https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal%4016.0/manual/renderer-features/create-custom-renderer-feature.html#scriptable-renderer-feature
            Blit(cmd,cameraColorTarget, TempRT1, material, 0);
            
            Blit(cmd,TempRT1, TempRT2, material, 1);
            
            Blit(cmd,TempRT2, cameraColorTarget, material, 2);


            context.ExecuteCommandBuffer(cmd);
            context.Submit();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (TempRT1 != null)
            {
                RTHandles.Release(TempRT1);
                TempRT1 = null;
                RTHandles.Release(TempRT2);
                TempRT2 = null;
            }
        }
    }
}