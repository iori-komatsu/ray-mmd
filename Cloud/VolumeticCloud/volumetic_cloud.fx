// 雲を描画するときのレイヤーの数です。
// 数を増やすほど雲がキレイでチラつきにくくなりますが、重くなります。
#define N_LAYERS 100

// 雲の明るさを計算するときにサンプリングする点の数です。
// 数を増やすほどキレイになる……はずでしたがほとんど変わらないので 1 でいいと思います。
#define N_LIGHT_SAMPLES 1

#include "volumetic_cloud.fxsub"
