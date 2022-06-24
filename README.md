# How To Use
ReleaseにあるZipをダウンロードして解凍後に、VRM2PMX.exeを実行してください。

- メインウィンドウでVRMファイルを選択すると、プレビュー画面にアバターが表示されます。
- 「変換する」をクリックしてフォルダを選択するとpmxが出力されます。
- 表情の設定をする場合は、下のEXTRA部分で行います。アバターを見ながら調整してください。設定後に変換する」をクリックして変換しましょう。
※この時に、設定した表情が反映されたVRMも同時に出力されます。次回続きから表情の作業をしたい場合はこのVRMを読み込んでください。

# Features
PMXExporter v0.5.6 by Furia https://twitter.com/flammpfeil/status/1032266829597573121  
を使ってPMXファイルを生成する際に、

- Editor限定だったので、容易に扱えるようにツール化しました。
- 一部のVRMファイルで互換性の問題が生じることがあったので書き換えを行った。

→　こちらはneon-izmさんの　https://github.com/neon-izm/VrmToPmxExporterSetup
での実装を利用しました。
- 表情モーフの設定を変換時に設定できるようにしました

# License
MIT。ライブラリ部分はそれぞれのライセンスに準じます。

# Include
- PMXExporter v0.5.6 by Furia　https://twitter.com/flammpfeil/status/1032266829597573121  
- UniVRM 0.5.6 https://github.com/vrm-c/UniVRM/releases/tag/v0.56.3
- MMDataIO(zyando) https://github.com/dojadon/MMDataIO
- VrmToPmxExporterSetup https://github.com/neon-izm/VrmToPmxExporterSetup
- UniTask https://github.com/Cysharp/UniTask

UI部のLibは割愛します。
