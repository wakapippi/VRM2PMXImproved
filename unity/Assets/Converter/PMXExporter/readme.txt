PMXExporter v0.5.6 by Furia

・概要
UniVRMでVRMファイルから生成したprefabをPMXファイルに出力することができます。

・動作要件
Unity 2017以降
UniVRM-0.45以降

・利用許諾
本スクリプト及び同梱物において特筆される指定が無い限り
MITlicenseを適用します。同梱のLICENSE.txtを参照ください。

UniVRM : MITlicense
author
 DWANGO Co., Ltd. for UniVRM
 ousttrue for UniGLTF, UniHumanoid
 Masataka SUMI for MToon
libraryを参照しています。

MMDataIO : MITlicense
author
 Zyando
libraryを改変・利用しています。

モーフリネームテーブル
author
 側近Q

敬称略

・本スクリプト自体のlicense設定の解説
v0.3以後、libraryへの修正はUnityEngineへの最適化のみとなり、v0.2.4以前の改修コードが排除されました。よってv0.3ではMITlicenseを適用します。
旧版を利用の場合は、旧版のライセンスに従ってください。


・出力されるPMXファイルのライセンス等
プログラムの著作権としての性質及び、リソースはVRMprefabを基に得られるものであるため、出力されるPMXファイルへ本プラグイン自体のライセンスの影響は一切発生しません。
よって出力されたPMXファイルは元となったVRMファイルの複製翻案となり、VRMファイルへ設定されたlicenseに基づきPMXファイルのライセンスが決定されます。

改変を伴う機能であるため、CC_??_NDなど改変禁止指定されたVRMファイルのPMX変換目的での利用は本プラグインのlicenseと適合しません。よって利用できません注意ください。


====================================================================================================
・利用方法

◆PMXExporter
UniVRMを用いてAssetにVRMをドロップしVRMprefabを作成します。

hierarchyに配置したVRMのprefabへPMXExporterをスクリプトコンポーネントとして付与してください。

右クリック（歯車メニュー）よりExportを選択。
保存先を決定すると出力されます。

※出力されるファイルの留意事項
CreateExTextureを利用する場合、MMDにMMEのインストールが必要です。
texフォルダ生成処理は、上書きを行いません。
そのため、PMXの上書き出力では既存のテクスチャがある場合、意図しない参照がなされてしまう可能性があります。
texフォルダが無い状態で出力するように留意ください。

---------------------------------------------------------------------------------------------------
◇設定
・Replace Bone Name(Default on)
一部基幹ヒューマノイドボーンをMMD標準ボーン名に置換します。

・Convert Armatuar Need Replace Bone Name(Default on)
Aスタンス化、左右足IK、両目ボーン、全ての親ボーン、センターボーン及び親子構造、捩じりボーン、向き反転
を行います。

・Replace Morph Name(Default on)
VRMBlendShapeProxyプリセットの一部（グループ化対応、マテリアルブレンド非対応）
及び、VRoid標準のモーフについて、MMD準拠名へ置換します。

・Use Reverse Joint(Default off)
物理演算において逆Jointを追加します。
基本の根本から先端へ伝わる動きに加え
先端の動きが根本へ戻ってくる振動が伝わりやすくなります。

・Emulate Spring Bone Leaf Colider(Default off)
Unity上でのVRMSpringBone（揺れモノ）の先端の当たり判定を正確にPMXに変換します。
通常（Off）は先端が離れすぎると重力に負けて垂れ下がりやすくなるため、先端の配置を再計算しています。

・Use Anti Gravity(非推奨 Default off)
全ての物理剛体を無重力状態（VRMSpringBoneでは重力反映しない設定ができる）にするためのボーンを追加します。
Secondaryボーンを数値入力で10上にずらすと効果を発揮する設計です。
非推奨です。

・Bone Dir Modify(Default on)
ボーンの見かけ上の向きを子に向けるようにします。ローカル軸ではありません。
PMXにおいて、見かけ上の向きとローカル軸は別概念です。

・Ca Scaling(Default 14)
出力サイズ倍率です。デフォルトでは14倍します。Vroid基準身長のモデルで14倍がMMD標準モデルとほぼ同等の身長になります。

・Auto Copy Texture(default on)
テクスチャファイルを自動で出力するpmxで読める様に、サブフォルダ配下に展開します。
生成されるテクスチャは下記処理を施した物になります。オリジナルのテクスチャを利用したい場合手動でコピーしてください。
ExportedTexture=BaseTexture*BaseColor+EmissionColor*EmissionTexture

・Create Ex Texture(default off)
MMEを用いて、MToonに近い発色を実現するシェーダ及びテクスチャをセットを生成します。
MMDに別途MMEのインストールが必要になります。
専用のテクスチャのために、UVのU成分が1/3化します。そのためループテクスチャは利用できません。
また、生成するシェーダではアウトラインの描画をサポートしません。

MToon以外のマテリアルが含まれる場合CreateExTextureを利用しないでください。

・Physics Alternative Setting(default off)
物理演算の設定を、とにかく暴れ難く大人しくする設定にします。

・Sort Materials (default on)
マテリアルの描画優先度を基に、PMX材質の順序をソートします。
これにより半透明部分の背景抜け等が軽減されます。

・Merge Material (default on)
SortMaterialsのオプションです。
同一materialを利用している材質をmergeし、構造をシンプルに描画負荷を軽減します。
改造等のためにメッシュ分割されている方が便利な場合はOffにするのが便利な場合もあります。

---------------------------------------------------------------------------------------------------
◇機能
IKないこともないです。物理ないこともないです。モーフはリネームないかもしれません。

MeshRendererは、親のゲームオブジェクトをボーンとして認識しWeightを100％付与します。
パーツ事に個別のボーンに分たので、親指定を追従させたいボーンにすれば比較的簡単にアクセサリとして書いたパーツを分離できるかも。

テクスチャはメインテクスチャのみ考慮します。
スフィアは指定はしますが、MMDの標準シェーダのバグ回避のため無効化状態反映しています。
xx.Texturesフォルダごとpmxと同階層に"tex"とリネームして配置するとテクスチャが読めます。



====================================================================================================
・更新履歴
v0.1
初版

v0.2
ボーン構造その他Aスタンス化等のMMD標準構造化を実装

v0.2.1
修正:v0.2追加機能においてモーフへの変形が適用されていなかった

v0.2.2
修正:MeshRenderer由来の頂点にボーン位置が反映されていなかった
修正:モーフ翻訳に一部誤植

v0.2.3
修正:モーフ翻訳に一部誤植

v0.2.4
修正:各種データのインデックスサイズ最適化
当修正によりPMXEditorでの再保存が不要でMMDに読み込めるようになります

v0.3
VRMSpringBoneの物理演算への変換を実装
パラメータは一律であり、SpringBoneの設定は各種コライダのサイズのみ反映される

v0.3.2
物理演算パラメータ色々調整
重複させてた剛体とか削除

v0.3.3
ボーンの見かけ上の向きを子に向けるように（ローカル軸ではない※MMDにおいてローカル軸と見かけ上の向きは別概念）
順標準ボーン追加（椀部の捩、親指０）
標準出力スケールを1.4倍化、Vroidデフォルト身長においてMMD標準モデルと同等の身長で出力されるように

v0.3.4
モーフリネームテーブルを外部ファイル化(UTF-8)
BlendShapeProxyで指定されているモーフは別テーブル
また、BlendShapeProxyでグループ化されているモーフが有れば、グループモーフとして変換するように
Vroid男性モデルのモーフリネームテーブルを同梱
材質モーフは現非対応
材質名のヘッダから描画タイプを排除、変わりにRenderQueue値(描画順序)を付与
小さい順に上から並べ替えると良い
なお描画タイプは材質コメント欄へ
MMD標準の材質ではCutOut互換描画はできない

v0.4
DescriptionにMetaデータを転記するように
テクスチャ群の自動展開設定を追加
MMEを利用したMToonに近い発色設定の出力をサポート（Main,Emission,Normalのテクスチャを反映）
物理演算設定で、比較的揺れの収束が速くなる設定を追加
IKのパラメータ設定を変更、沈み込みや足の捻挫を若干の軽減

v0.5
材質の描画優先度を考慮したソートを実装
同一材質の統合を実装
一切材質にテクスチャが利用されていない場合にPMXEで不正なファイルとなるのを回避

V0.5.1
一部BlendShape構成でのクラッシュに対処
MToon以外のマテリアルでの材質変換不具合に対処
（MToon以外の場合CreateExTextureを利用しないでください）

v0.5.2
一部ヒューマノイドリグのマッピング構成でPMX時の変形が著しく破綻する場合に対処
Hipsを、Spineを複製した下半身ボーンの子として再構成するように
センターの位置を首の半分の高さの位置に、元のボーン構成に依存しない追加ボーンとして生成するように
生成する剛体のサイズの下限(0.1)を設定し著しく小さいサイズで生成されないように

v0.5.3
テクスチャ自動コピー時に生成するテクスチャ仕様を変更。これにより非エフェクト時の発色が若干MToonに近く、但し影色は無視します。
Exテクスチャを利用しない場合は、発色をテクスチャ依存に変更し一律設定の材質に変更。
法線をノーマライズするように変更、スフィアマップが概正常化。

v0.5.4
BlendShapeProxyでの複合BlendShapeが複数回登録される不具合を解消。
Vroidの標準モーフ名の変更に伴いリネームマップを更新。
リネームマップcsvのParse処理にコメント行考慮を追加。(#で始まる行は無視される)

v0.5.5 (mtlike.fx v1.1)
ExTextureを利用時のuvの横軸uのループテクスチャに対応
出力済みのpmxは古いfxファイルを新しいmtlike.fxに差し替えるだけで対処できます

v0.5.6
伴い捩じり追加をオプション化、デフォルトOff（捩じり自動追加時破綻予防の無効化用のためのものなので後述のウェイト統合機能実装につき非推奨へ
Vroidのみ二の腕、下腕部の揺れものボーンウェイト排除オプション追加デフォルトOn（捩じり自動追加プラグインでの自動ウェイト計算対応しやすいように
デフォルトの出力サイズ倍率を12.46に設定（MMDでのいわゆるミクスケールに、まじかる☆ですくとっぷで見たときの値が概ね一致するようにスケール変換します。
リネームマップの更新