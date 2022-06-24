using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Cysharp.Threading.Tasks;
using FancyConverter;
using Newtonsoft.Json.Linq;
using UnityEngine;
using VRM;
using WebSocketSharp;

namespace VRM2PMXImproved
{
    public class MainBehaviour : MonoBehaviour
    {
        private ConvertMapSchema _convertMapSchema;
        private GameObject _currentAvatar;

        private WebSocket _ws;
        
        void Start()
        {

            var args = Environment.GetCommandLineArgs();

            try
            {
                var port = args[1];
                _ws = new WebSocket("ws://localhost:" + port);
                _ws.OnMessage += OnMessage;
                _ws.OnOpen += OnOpen;
                _ws.Connect();
            }
            catch
            {
                Application.Quit();
            }

            
        }

        void OnMessage(object sender, MessageEventArgs arg)
        {
            var message = JToken.Parse(arg.Data).ToObject<MessageSchema>();

            if (message.name == "VRMLoad")
            {
                ResetScene();

                var data = message.payload;
                var end = data.IndexOf(",");
                data = data.Remove(0, end + 1);

                byte[] decodedBytes = System.Convert.FromBase64String(data);
                var success = false;
                try
                {
                    LoadAndShowAvatar(decodedBytes).Forget();
                    success = true;
                }
                catch (Exception e)
                {
                    Debug.Log(e);
                    //success = false;
                }

                Debug.Log("done");
                var accepted = new MessageSchema()
                {
                    name = "VRMStatus",
                    payload = success.ToString().ToLower()
                };
                _ws.Send(JToken.FromObject(accepted).ToString());
            }

            if (message.name == "BindingSelect")
            {
                var index = Int32.Parse(message.payload);
                UpdateSelectingKey(index);
            }

            if (message.name == "Bindings")
            {
                var token = JToken.Parse(message.payload);
                var list = token.ToObject<List<BlendShapeClipSchema>>();
                UpdateBindingsFromList(list).Forget();
            }

            if (message.name == "Convert")
            {
                var path = message.payload;
                RunConvertTask(path).Forget();
            }
            
            if (message.name == "ConvertMap")
            {
                var data = JToken.Parse(message.payload);
                _convertMapSchema = data.ToObject<ConvertMapSchema>();
            }
           

        }

        private List<BlendShapeOutgoingSchema> _info;
        private List<BlendShapeClipSchema> _currentBinding;

        private int _selectingkey = 0;

        private void UpdateSelectingKey(int index)
        {
            _selectingkey = index;
        }

        private async UniTask LoadAndShowAvatar(byte[] bytes)
        {
            await UniTask.SwitchToMainThread();

            var context = new VRMImporterContext();
            context.ParseGlb(bytes);
            Debug.Log("parse ok");

            var meta = context.ReadMeta(false); //引数をTrueに変えるとサムネイルも読み込みます

            //同期処理で読み込みます
            context.Load();
            Debug.Log("loaded");

            //読込が完了するとcontext.RootにモデルのGameObjectが入っています
            var root = context.Root;
            //モデルをワールド上に配置します
            root.transform.SetParent(transform.parent, false);
            //メッシュを表示します
            context.ShowMeshes();
            _currentAvatar = root;

            //BlendShapeのマスター的なもの
            _info = GatherBlendShapeMasterInfo();

            var mesMaster = new MessageSchema()
            {
                name = "BlendShapeMaster",
                payload = JToken.FromObject(_info).ToString()
            };
            _ws.Send(JToken.FromObject(mesMaster).ToString());

            //現在のデータ
            _currentBinding = GatherBlendShapeBindingsInfo();
            var mesBinding = new MessageSchema()
            {
                name = "BlendShapeBinding",
                payload = JToken.FromObject(_currentBinding).ToString()
            };
            _ws.Send(JToken.FromObject(mesBinding).ToString());

        }

        private List<BlendShapeOutgoingSchema> GatherBlendShapeMasterInfo()
        {
            /*
             * (PMXエディタで一切触らないように完成させられるのが理想。例えば笑い、怒りなどをこっち側で設定してcsv経由で流したい）
             */
            var output = new List<BlendShapeOutgoingSchema>();
            var smRenderers = _currentAvatar.GetComponentsInChildren<SkinnedMeshRenderer>();
            foreach (var skinnedMeshRenderer in smRenderers)
            {
                if (skinnedMeshRenderer.sharedMesh.blendShapeCount == 0)
                {
                    //BlendShapeを持たない
                    continue;
                }

                var path = GetRelativePath(_currentAvatar.transform, skinnedMeshRenderer.gameObject.transform);
                var bList = new List<string>();

                for (var i = 0; i < skinnedMeshRenderer.sharedMesh.blendShapeCount; i++)
                {
                    var bName = skinnedMeshRenderer.sharedMesh.GetBlendShapeName(i);
                    bList.Add(bName);
                }

                var outgoing = new BlendShapeOutgoingSchema()
                {
                    relativePath = path,
                    names = bList
                };

                output.Add(outgoing);
            }

            return output;
        }

        private List<BlendShapeClipSchema> GatherBlendShapeBindingsInfo()
        {
            var proxy = _currentAvatar.GetComponent<VRMBlendShapeProxy>();

            var output = new List<BlendShapeClipSchema>();
            foreach (var blendShapeClip in proxy.BlendShapeAvatar.Clips)
            {

                BlendShapeClipSchema clip = new BlendShapeClipSchema();
                clip.blendShapeName = blendShapeClip.BlendShapeName;
                clip.bindings = new List<BlendShapeBindingSchema>();
                foreach (var blendShapeBinding in blendShapeClip.Values)
                {
                    var bind = new BlendShapeBindingSchema()
                    {
                        weight = blendShapeBinding.Weight,
                        index = blendShapeBinding.Index,
                        relativePath = blendShapeBinding.RelativePath
                    };
                    clip.bindings.Add(bind);
                }

                output.Add(clip);

            }

            return output;
        }

        private string GetRelativePath(Transform top, Transform target)
        {
            var current = target.parent;
            var output = target.gameObject.name;

            while (true)
            {
                if (current == top)
                {
                    break;
                }

                output = current.gameObject.name + "/" + output;

                current = current.parent;

            }

            return output;
        }

        private void Update()
        {
            if (_currentAvatar == null)
            {
                return;
            }

            var proxy = _currentAvatar.GetComponent<VRMBlendShapeProxy>();

            foreach (var blendShapeClip in proxy.BlendShapeAvatar.Clips)
            {
                proxy.ImmediatelySetValue(blendShapeClip.Key, 0f);
            }

            if (_selectingkey == -1)
            {
                return;
            }

            var found = proxy.BlendShapeAvatar.Clips.FirstOrDefault(x =>
                x.BlendShapeName == _currentBinding[_selectingkey].blendShapeName);
            if (found != null)
            {
                proxy.ImmediatelySetValue(found.Key, 1f);
            }
        }

        void OnOpen(object sender, EventArgs arg)
        {
            var unityInit = new MessageSchema()
            {
                name = "UnityInit"
            };

            _ws.Send(JToken.FromObject(unityInit).ToString());
        }

        private async UniTask UpdateBindingsFromList(List<BlendShapeClipSchema> list)
        {
            await UniTask.SwitchToMainThread();

            var isClipChanged = false;

            var proxy = _currentAvatar.GetComponent<VRMBlendShapeProxy>();
            var clips = proxy.BlendShapeAvatar.Clips;

            foreach (var blendShapeClipSchema in list)
            {
                var name = blendShapeClipSchema.blendShapeName;
                var found = clips.FirstOrDefault(x => x.BlendShapeName == name);

                if (found != null)
                {
                    var newList = new List<BlendShapeBinding>();
                    foreach (var blendShapeBindingSchema in blendShapeClipSchema.bindings)
                    {
                        var binding = new BlendShapeBinding()
                        {
                            Index = blendShapeBindingSchema.index,
                            RelativePath = blendShapeBindingSchema.relativePath,
                            Weight = blendShapeBindingSchema.weight
                        };
                        newList.Add(binding);
                    }

                    found.Values = newList.ToArray();


                }
                else
                {

                    var newClip = ScriptableObject.CreateInstance<BlendShapeClip>();
                    newClip.BlendShapeName = name;
                    var bindingList = new List<BlendShapeBinding>();

                    foreach (var blendShapeBindingSchema in blendShapeClipSchema.bindings)
                    {
                        var binding = new BlendShapeBinding()
                        {
                            Index = blendShapeBindingSchema.index,
                            RelativePath = blendShapeBindingSchema.relativePath,
                            Weight = blendShapeBindingSchema.weight
                        };
                        bindingList.Add(binding);
                    }

                    newClip.Values = bindingList.ToArray();
                    clips.Add(newClip);
                    isClipChanged = true;
                }
            }

            //削除対応
            for (var i = 0; i < clips.Count; i++)
            {
                var isExist = list.FirstOrDefault(x => x.blendShapeName == clips[i].BlendShapeName) != null;
                if (isExist) continue;

                isClipChanged = true;
                clips.RemoveAt(i);
                i--;

            }

            /*
            if (isClipChanged)
            {
                proxy.ForceUpdateClipMap();
            }
            */
            proxy.ForceUpdateClipMap();

            _currentBinding = GatherBlendShapeBindingsInfo();

        }

        private async UniTask RunConvertTask(string path)
        {
            //表情を調整したVRMを保存する
            await SaveVrm(path);

            //pmx変換
            await ConvertToPmx(path);
        }

        private async UniTask SaveVrm(string path)
        {
            await UniTask.SwitchToMainThread();

            var vrm = VRMExporter.Export(_currentAvatar);
            var bytes = vrm.ToGlbBytes();

            var filename = path + Path.DirectorySeparatorChar + "mod.vrm";
            using (FileStream fs = new FileStream(filename, FileMode.OpenOrCreate))
            using (BinaryWriter bw = new BinaryWriter(fs))
            {
                bw.Write(bytes);
            }
        }

        private async UniTask ConvertToPmx(string path)
        {
            await UniTask.SwitchToMainThread();
            
            var meta = _currentAvatar.GetComponent<VRMMeta>();

            if (string.IsNullOrEmpty(meta.Meta.ContactInformation))
            {
                meta.Meta.ContactInformation = "internal use only";
            }


            var blendShapeProxy = _currentAvatar.GetComponentInChildren<VRMBlendShapeProxy>();


            var skinnedMeshRenderers = _currentAvatar.GetComponentsInChildren<SkinnedMeshRenderer>();
            foreach (var mesh in skinnedMeshRenderers)
            {
                BlendShapeProxyBaker.BakeBlendShapeProxyToMesh(_currentAvatar, mesh, blendShapeProxy.BlendShapeAvatar);
            }
            
            PMXExporter exporter = _currentAvatar.AddComponent<PMXExporter>();
            exporter.ConvertMap = _convertMapSchema;
            exporter.Init(path);
            
            var converted = new MessageSchema()
            {
                name = "Converted",
                payload = ""
            };
            _ws.Send(JToken.FromObject(converted).ToString());
            
            Application.Quit();
            
        }

        private void ResetScene()
        {
            if (_currentAvatar != null)
            {
                Destroy(_currentAvatar);
                _currentAvatar = null;
            }
        }


        class BlendShapeClipSchema
        {
            public string blendShapeName;
            public List<BlendShapeBindingSchema> bindings;
        }

        class BlendShapeBindingSchema
        {
            public float weight;
            public int index;
            public string relativePath;

        }

        class MessageSchema
        {
            public string name;
            public string payload;
        }


        class BlendShapeOutgoingSchema
        {
            public string relativePath;
            public List<string> names;

        }
    }
}