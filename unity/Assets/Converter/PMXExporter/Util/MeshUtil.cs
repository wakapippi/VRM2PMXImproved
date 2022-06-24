using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Linq;
using System;

namespace PMXExport
{

    public class MeshUtil
    {

        public static void RecalculateNormals(Mesh mesh, float angle)
        {
            var triangles = mesh.triangles;

            var vertices = mesh.vertices;
            var weights = mesh.boneWeights == null || mesh.boneWeights.Length == 0 ?
                mesh.vertices.Select(v => new BoneWeight()).ToArray() : mesh.boneWeights;

            var triNormals = new Vector3[triangles.Length / 3];
            var normals = new Vector3[vertices.Length];

            angle = angle * Mathf.Deg2Rad;

            var dictionary = new Dictionary<VertexKey, VertexEntry>(vertices.Length);

            for (var i = 0; i < triangles.Length; i += 3)
            {
                var i1 = triangles[i];
                var i2 = triangles[i + 1];
                var i3 = triangles[i + 2];

                var p1 = vertices[i2] - vertices[i1];
                var p2 = vertices[i3] - vertices[i1];
                var normal = Vector3.Cross(p1, p2).normalized;
                int triIndex = i / 3;
                triNormals[triIndex] = normal;

                VertexEntry entry;
                VertexKey key;

                if (!dictionary.TryGetValue(key = new VertexKey(vertices[i1], weights[i1]), out entry))
                {
                    entry = new VertexEntry();
                    dictionary.Add(key, entry);
                }
                entry.Add(i1, triIndex);

                if (!dictionary.TryGetValue(key = new VertexKey(vertices[i2], weights[i2]), out entry))
                {
                    entry = new VertexEntry();
                    dictionary.Add(key, entry);
                }
                entry.Add(i2, triIndex);

                if (!dictionary.TryGetValue(key = new VertexKey(vertices[i3], weights[i3]), out entry))
                {
                    entry = new VertexEntry();
                    dictionary.Add(key, entry);
                }
                entry.Add(i3, triIndex);
            }
            foreach (var value in dictionary.Values)
            {
                for (var i = 0; i < value.Count; ++i)
                {
                    var sum = new Vector3();
                    for (var j = 0; j < value.Count; ++j)
                    {
                        if (value.VertexIndex[i] == value.VertexIndex[j])
                        {
                            sum += triNormals[value.TriangleIndex[j]];
                        }
                        else
                        {
                            float dot = Vector3.Dot(
                                triNormals[value.TriangleIndex[i]],
                                triNormals[value.TriangleIndex[j]]);
                            dot = Mathf.Clamp(dot, -0.99999f, 0.99999f);
                            float acos = Mathf.Acos(dot);
                            if (acos <= angle)
                            {
                                sum += triNormals[value.TriangleIndex[j]];
                            }
                        }
                    }

                    normals[value.VertexIndex[i]] = sum.normalized;
                }
            }

            mesh.normals = normals;
        }

        private struct VertexKey
        {
            private readonly Vector3Key vectorKey;
            private readonly BoneWeightKey boneWeightKey;

            public VertexKey(Vector3 vertex, BoneWeight weight)
            {
                vectorKey = new Vector3Key(vertex);
                boneWeightKey = new BoneWeightKey(weight);
            }

            public override bool Equals(object obj)
            {
                if (!(obj is VertexKey))
                {
                    return false;
                }

                var key = (VertexKey)obj;
                return EqualityComparer<Vector3Key>.Default.Equals(vectorKey, key.vectorKey) &&
                       EqualityComparer<BoneWeightKey>.Default.Equals(boneWeightKey, key.boneWeightKey);
            }

            public override int GetHashCode()
            {
                var hashCode = 1521390019;
                //hashCode = hashCode * -1521134295 + base.GetHashCode();
                hashCode = hashCode * -1521134295 + EqualityComparer<Vector3Key>.Default.GetHashCode(vectorKey);
                hashCode = hashCode * -1521134295 + EqualityComparer<BoneWeightKey>.Default.GetHashCode(boneWeightKey);
                return hashCode;
            }
        }

        private struct BoneWeightKey
        {
            private readonly int bone0;
            private readonly int bone1;
            private readonly int bone2;
            private readonly int bone3;

            private readonly long weight0;
            private readonly long weight1;
            private readonly long weight2;
            private readonly long weight3;


            private const int Tolerance = 100000;

            public BoneWeightKey(BoneWeight weight)
            {
                bone0 = weight.boneIndex0;
                bone1 = weight.boneIndex1;
                bone2 = weight.boneIndex2;
                bone3 = weight.boneIndex3;

                weight0 = (long)(Mathf.Round(weight.weight0 * Tolerance));
                weight1 = (long)(Mathf.Round(weight.weight1 * Tolerance));
                weight2 = (long)(Mathf.Round(weight.weight2 * Tolerance));
                weight3 = (long)(Mathf.Round(weight.weight3 * Tolerance));

            }

            public override bool Equals(object obj)
            {
                if (!(obj is BoneWeightKey))
                {
                    return false;
                }

                var key = (BoneWeightKey)obj;
                return bone0 == key.bone0 &&
                       bone1 == key.bone1 &&
                       bone2 == key.bone2 &&
                       bone3 == key.bone3 &&
                       weight0 == key.weight0 &&
                       weight1 == key.weight1 &&
                       weight2 == key.weight2 &&
                       weight3 == key.weight3;
            }

            public override int GetHashCode()
            {
                var hashCode = -1543466380;
                //hashCode = hashCode * -1521134295 + base.GetHashCode();
                hashCode = hashCode * -1521134295 + bone0.GetHashCode();
                hashCode = hashCode * -1521134295 + bone1.GetHashCode();
                hashCode = hashCode * -1521134295 + bone2.GetHashCode();
                hashCode = hashCode * -1521134295 + bone3.GetHashCode();
                hashCode = hashCode * -1521134295 + weight0.GetHashCode();
                hashCode = hashCode * -1521134295 + weight1.GetHashCode();
                hashCode = hashCode * -1521134295 + weight2.GetHashCode();
                hashCode = hashCode * -1521134295 + weight3.GetHashCode();
                return hashCode;
            }
        }

        private struct Vector3Key
        {
            private readonly long x;
            private readonly long y;
            private readonly long z;

            private const int Tolerance = 100000;

            public Vector3Key(Vector3 position)
            {
                x = (long)(Mathf.Round(position.x * Tolerance));
                y = (long)(Mathf.Round(position.y * Tolerance));
                z = (long)(Mathf.Round(position.z * Tolerance));

            }

            public override bool Equals(object obj)
            {
                if (!(obj is Vector3Key))
                {
                    return false;
                }

                var key = (Vector3Key)obj;
                return x == key.x &&
                       y == key.y &&
                       z == key.z;
            }

            public override int GetHashCode()
            {
                var hashCode = 373119288;
                //hashCode = hashCode * -1521134295 + base.GetHashCode();
                hashCode = hashCode * -1521134295 + x.GetHashCode();
                hashCode = hashCode * -1521134295 + y.GetHashCode();
                hashCode = hashCode * -1521134295 + z.GetHashCode();
                return hashCode;
            }
        }

        private sealed class VertexEntry
        {
            public int[] TriangleIndex = new int[4];
            public int[] VertexIndex = new int[4];

            private int reserved = 4;

            public int Count { get; private set; }

            public void Add(int vertIndex, int triIndex)
            {
                if (reserved == Count)
                {
                    reserved *= 2;
                    Array.Resize(ref TriangleIndex, reserved);
                    Array.Resize(ref VertexIndex, reserved);
                }
                TriangleIndex[Count] = triIndex;
                VertexIndex[Count] = vertIndex;
                ++Count;
            }
        }
    }

}
