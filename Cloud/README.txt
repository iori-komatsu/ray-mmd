VolumeticCloud (by IoriKomatsu)
===============================

雲です。サイズや密度や色を操作できます。


使い方
-----

VolumeticCloud.pmx をロードしてください。


パラメータの説明
--------------

* Position  
  雲の中心座標と回転を指定します。

* Size  
  雲のサイズを大きくしたり小さくしたりします。

* PatternScale  
  雲のパターン(濃淡)のスケールを変更します。
  X座標の値のみが意味を持ちます。

* Cutoff  
  雲が存在しない領域の割合を調整します。

* Density  
  雲の密度を調整します。

* Brightness  
  雲の明るさを調整します。
  より正確に言うとガンマ補正をかけます。

* H  
  雲の色相を変更します。
  S がゼロだと変化が見えないので先に H を弄るなら先に S を増やしたほうがいいです。

* S  
  雲の彩度を変更します。

* V  
  雲の明度を変更します。


軽量版
-----

VolumeticCloud の動作が重たい場合は軽量版を使ってください。
軽量版を使うには、VolumeticCloud.pmx をロードした後に以下の手順を行ってください。

1. エフェクト割当を開く
2. CloudMap の VolumeticCloud.pmx をダブルクリックして "volumetic_cloud_low_quality.fx" を選択する
