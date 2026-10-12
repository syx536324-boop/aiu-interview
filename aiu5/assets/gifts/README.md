# 魔法赐予图标

`rune-icons.png` 是用户选定的第二套风格微调版：低光晕、青色环纹符文、刻线和少量金色小符号。透明6列×3行，对应gifts/mapping.gd的18类顺序。

`interface/gift_icon_atlas.gd`以AtlasTexture引用原图，不改变原素材。普通实例仍使用item_icon原图形；赐予实例以provenance.magical判定，满水杯沿用杯子符文并叠加水面。
