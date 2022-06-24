#define USE_VERBOSE_LOG // Printfデバッグしたくなったときは　コメントアウトを外す

using System.Collections.Generic;
using System.Diagnostics;
using UnityEngine;
using VRM;
using Debug = UnityEngine.Debug;

namespace FancyConverter
{
    public class BlendShapeProxyBaker
    {
        /// <summary>
        /// BlendShapeProxyをベースに各メッシュにBakeする
        /// </summary>
        /// <param name="mesh"></param>
        /// <returns></returns>
        public static void BakeBlendShapeProxyToMesh(GameObject target, SkinnedMeshRenderer smr,
            BlendShapeAvatar copyBlendShapeAvatar)
        {
            Mesh mesh = smr.sharedMesh;
            if (mesh == null) return;
            if (mesh.blendShapeCount == 0) return;


            List<string> existingBlendShapeName = new List<string>();
            for (int i = 0; i < smr.sharedMesh.blendShapeCount; i++)
            {
                existingBlendShapeName.Add(smr.sharedMesh.GetBlendShapeName(i));
            }

            var copyMesh = mesh.Copy(copyBlendShape: true);

            foreach (var clip in copyBlendShapeAvatar.Clips)
            {
                //それぞれ Blink,Sorrow,HAPPYなどを取得してる
                var name = clip.BlendShapeName;
                var vCount = mesh.vertexCount;
                var vertices = new Vector3[vCount];
                var normals = new Vector3[vCount];
                var tangents = new Vector3[vCount];

                bool isUsed = false;
                //それぞれのBlinkの中に何個のBlendShape数があるか 例:Blinkは右目閉じと左目閉じの合成
                for (var i = 0; i < clip.Values.Length; ++i)
                {
                    var value = clip.Values[i];
                    if (target.transform.Find(value.RelativePath) != smr.transform) continue;
                    isUsed = true;

                    //ここでvalueには各blendshapeのweightが取得できる
                    VerboseLog(
                        $"Clip名*{clip} index:{clip.Values[i].Index} BlendShapeName:{smr.sharedMesh.GetBlendShapeName(clip.Values[i].Index)} Weight:{clip.Values[i].Weight}");
                    {
                        var tmpVertices = new Vector3[vCount];
                        var tmpNormals = new Vector3[vCount];
                        var tmpTangents = new Vector3[vCount];

                        mesh.GetBlendShapeFrameVertices(clip.Values[i].Index, 0, tmpVertices, tmpNormals,
                            tmpTangents);

                        for (int k = 0; k < vertices.Length; k++)
                        {
                            vertices[k] += tmpVertices[k] * (clip.Values[i].Weight * 0.01f);
                            normals[k] += tmpNormals[k] * (clip.Values[i].Weight * 0.01f);
                            tangents[k] += tmpTangents[k] * (clip.Values[i].Weight * 0.01f);
                        }
                    }
                }

                if (isUsed)
                {
                    if (existingBlendShapeName.Contains(name))
                    {
                        name += "_";
                    }

                    copyMesh.AddBlendShapeFrame(name, 100f, vertices, normals, tangents);
                }
            }

            // mesh を置き換える
            smr.sharedMesh = copyMesh;
        }

        [Conditional("USE_VERBOSE_LOG")]
        private static void VerboseLog(object message)
        {
            Debug.Log(message);
        }
    }
}