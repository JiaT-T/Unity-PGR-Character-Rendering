using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CelHairShadow : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingOpaques;
        public LayerMask hairLayer;
        public LayerMask faceLayer;

        [Range(1000, 5000)]
        public int queueMin = 2000;

        [Range(1000, 5000)]
        public int queueMax = 3000;

        public Material material;
    }

    public Setting setting = new Setting();

    class CustomRenderPass : ScriptableRenderPass
    {
        public int soildColorID = 0;
        public ShaderTagId shaderTag = new ShaderTagId("BangsShadow");
        public Setting setting;

        FilteringSettings filtering;
        FilteringSettings filtering2;

        public CustomRenderPass(Setting setting)
        {
            this.setting = setting;

            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(setting.queueMax, setting.queueMin);
            queue.upperBound = Mathf.Max(setting.queueMax, setting.queueMin);
            filtering = new FilteringSettings(queue, setting.hairLayer);
            filtering2 = new FilteringSettings(queue, setting.faceLayer);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            int temp = Shader.PropertyToID("_HairSolidColor");
            RenderTextureDescriptor desc = cameraTextureDescriptor;
            desc.colorFormat = RenderTextureFormat.R8;
            desc.depthBufferBits = 24;
            cmd.GetTemporaryRT(temp, desc);
            soildColorID = temp;
            ConfigureTarget(temp);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (setting.material == null) return;

            CommandBuffer cmd = CommandBufferPool.Get("CelHairShadow");
            cmd.SetGlobalTexture(soildColorID, soildColorID);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;

            var drawFace = CreateDrawingSettings(shaderTag, ref renderingData, sortFlags);
            drawFace.overrideMaterial = setting.material;
            drawFace.overrideMaterialPassIndex = 1;
            context.DrawRenderers(renderingData.cullResults, ref drawFace, ref filtering2);

            var drawHair = CreateDrawingSettings(shaderTag, ref renderingData, sortFlags);
            drawHair.overrideMaterial = setting.material;
            drawHair.overrideMaterialPassIndex = 0;
            context.DrawRenderers(renderingData.cullResults, ref drawHair, ref filtering);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(setting);
        m_ScriptablePass.renderPassEvent = setting.passEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}
