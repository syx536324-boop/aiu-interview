"""Record visually accepted LVIS rare-equipment images, excluding logos, artworks and uncertain objects."""
from pathlib import Path
import json
ACCEPTED=[15318,45105,389183,447854,534906,151699,228224,284934,303360,4211,16574,143358,303260,60737,62311,69488,74428,92847,94199,125746,139571,170525,189212,191639,208283,253915,295780,295798,347144,348865,373251,385913,395964,397286,479855,483048,492692,506226,514635,564830,569046]
if __name__=='__main__':
    p=Path('D:/AIU5-YOLO训练资料/公开数据/lvis-curation.json')
    p.write_text(json.dumps({'accepted_image_ids':ACCEPTED,'review':'AI visual inspection of boxed contact sheets; exclude other rare-class photos until reviewed. Prototype selection, not human gold labels.','known_same_scene_groups':[[151699,284934]]},indent=2),encoding='utf-8')
