using UnityEngine;
using System.Collections.Generic;
using System.Linq;

#if UNITY_EDITOR
using UnityEditor;
#endif

// 挂载在模型物体上，点击按钮即可烘焙
public class SimpleSmoothNormalBaker : MonoBehaviour
{
    [Tooltip("烘焙后是否覆盖原网格文件？(建议先备份)")]
    public bool overwriteMesh = false;

    // 核心算法：不依赖 Jobs/Burst，纯 C# 实现
    public void Bake()
    {
        var meshFilter = GetComponent<MeshFilter>();
        var skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();

        Mesh mesh = null;
        if (meshFilter != null) mesh = meshFilter.sharedMesh;
        else if (skinnedMeshRenderer != null) mesh = skinnedMeshRenderer.sharedMesh;

        if (mesh == null)
        {
            Debug.LogError("找不到 Mesh！请确保物体上有 MeshFilter 或 SkinnedMeshRenderer。");
            return;
        }

        // 1. 获取网格数据
        Vector3[] vertices = mesh.vertices;
        Vector3[] normals = mesh.normals;

        // 字典：根据位置分组，累加法线
        // Key: 顶点位置, Value: 累加的法线向量
        Dictionary<Vector3, Vector3> smoothNormalDict = new Dictionary<Vector3, Vector3>();

        Debug.Log($"开始处理 {mesh.name} 的平滑法线...");

        // 2. 遍历所有顶点，将位置相同的顶点的法线加在一起
        // 原插件使用了“角度加权”，这里为了兼容性和速度使用“均值加权”，效果对卡通渲染通常足够好
        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 pos = vertices[i];
            if (!smoothNormalDict.ContainsKey(pos))
            {
                smoothNormalDict[pos] = Vector3.zero;
            }
            smoothNormalDict[pos] += normals[i];
        }

        // 3. 准备写入颜色通道的数据
        Color[] colors = new Color[vertices.Length];

        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 pos = vertices[i];

            // 获取累加后的法线并归一化 = 平滑法线 (Object Space)
            Vector3 smoothNormal = smoothNormalDict[pos].normalized;

            // 4. 将法线编码进顶点颜色 (0..1 范围)
            // 法线范围是 -1..1，我们需要映射到 0..1
            colors[i] = new Color(
                smoothNormal.x * 0.5f + 0.5f,
                smoothNormal.y * 0.5f + 0.5f,
                smoothNormal.z * 0.5f + 0.5f,
                1.0f
            );
        }

        // 5. 应用到 Mesh
        // 为了安全，建议实例化一个新的 Mesh，除非你确定要修改原文件
        Mesh targetMesh = mesh;
        if (!overwriteMesh)
        {
            targetMesh = Instantiate(mesh);
            targetMesh.name = mesh.name + "_Smoothed";
            if (meshFilter != null) meshFilter.sharedMesh = targetMesh;
            if (skinnedMeshRenderer != null) skinnedMeshRenderer.sharedMesh = targetMesh;
        }

        targetMesh.colors = colors;

        Debug.Log($"✅ 成功！平滑法线已烘焙到 {targetMesh.name} 的顶点颜色 (Vertex Color) 中。");
    }
}

#if UNITY_EDITOR
[CustomEditor(typeof(SimpleSmoothNormalBaker))]
public class SimpleSmoothNormalBakerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        SimpleSmoothNormalBaker script = (SimpleSmoothNormalBaker)target;

        GUILayout.Space(10);
        if (GUILayout.Button("执行烘焙 (Bake Smooth Normals)", GUILayout.Height(40)))
        {
            script.Bake();
        }

        GUILayout.Space(5);
        GUILayout.Label("说明：\n1. 此脚本会将平滑法线存入 Vertex Color。\n2. 请确保 Shader 中读取的是 Vertex Color 而非 Normal。\n3. 生成的数据是 Object Space (模型空间)。", EditorStyles.helpBox);
    }
}
#endif